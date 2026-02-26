function ghprcomments() {
  emulate -L zsh
  set -euo pipefail

  local jq_filter=""
  local do_copy=0
  local do_json=0
  local json_path=""
  local outdir=""

  # --- args ---
  while (( $# > 0 )); do
    case "$1" in
      --jq)
        jq_filter="${2:-}"
        [[ -z "$jq_filter" ]] && { print -u2 "Missing value for --jq"; return 2 }
        shift 2
        ;;
      --copy|-c)
        do_copy=1
        shift
        ;;
      --json)
        do_json=1
        if [[ "${2:-}" != "" && "${2:-}" != --* && "${2:-}" != -* ]]; then
          json_path="$2"
          shift 2
        else
          shift
        fi
        ;;
      --outdir)
        outdir="${2:-}"
        [[ -z "$outdir" ]] && { print -u2 "Missing value for --outdir"; return 2 }
        shift 2
        ;;
      *)
        print -u2 "Unknown argument: $1"
        return 2
        ;;
    esac
  done

  # --- helpers ---
  _clipboard_copy() {
    if command -v pbcopy >/dev/null 2>&1; then
      pbcopy
    elif command -v wl-copy >/dev/null 2>&1; then
      wl-copy
    elif command -v xclip >/dev/null 2>&1; then
      xclip -selection clipboard
    elif command -v clip.exe >/dev/null 2>&1; then
      clip.exe
    else
      print -u2 "No clipboard tool found."
      return 1
    fi
  }

  _resolve_json_path() {
    local pr="$1"
    local p="${json_path:-ghprcm-PR${pr}-comments.json}"

    if [[ -n "$outdir" ]]; then
      mkdir -p "$outdir"
      [[ "$p" != /* ]] && p="${outdir%/}/$p"
    fi
    print -r -- "$p"
  }

  # --- PR context ---
  local pr_number
  pr_number="$(gh pr view --json number -q '.number' 2>/dev/null || true)"
  [[ -z "$pr_number" ]] && { print -u2 "No active PR found."; return 1 }

  local owner repo
  owner="$(gh repo view --json owner -q '.owner.login')"
  repo="$(gh repo view --json name -q '.name')"

  local query='
query($owner:String!, $repo:String!, $pr:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      number
      title
      url
      comments(first: 100) {
        totalCount
        nodes {
          id
          author { login }
          body
          createdAt
          updatedAt
        }
      }
      reviews(first: 100) {
        totalCount
        nodes {
          id
          author { login }
          state
          body
          submittedAt
          comments(first: 100) {
            totalCount
            nodes {
              id
              author { login }
              body
              createdAt
              path
              line
              originalLine
              diffHunk
            }
          }
        }
      }
    }
  }
}
'

  # --- Fetch raw JSON ---
  local raw_json
  raw_json="$(
    GH_PAGER=cat gh api graphql \
      -f query="$query" \
      -F owner="$owner" \
      -F repo="$repo" \
      -F pr="$pr_number"
  )"

  # --- Exclude github-actions comments/reviews ---
  local filtered_json
  filtered_json="$(print -r -- "$raw_json" | jq --arg bot "github-actions" '
    .data.repository.pullRequest.comments.nodes |= [.[] | select(.author.login != $bot)]
    | .data.repository.pullRequest.comments.totalCount = (.data.repository.pullRequest.comments.nodes | length)
    | .data.repository.pullRequest.reviews.nodes |= [.[] | select(.author.login != $bot)]
    | .data.repository.pullRequest.reviews.totalCount = (.data.repository.pullRequest.reviews.nodes | length)
  ')"

  # --- Always pretty-print ---
  local pretty_json
  pretty_json="$(print -r -- "$filtered_json" | jq .)"

  # --- Optional jq filter (still pretty) ---
  local output
  if [[ -n "$jq_filter" ]]; then
    output="$(print -r -- "$pretty_json" | jq "$jq_filter")"
  else
    output="$pretty_json"
  fi

  # --- Always print (cat-like) ---
  print -r -- "$output"

  # --- Export JSON ---
  if (( do_json )); then
    local path
    path="$(_resolve_json_path "$pr_number")"
    print -r -- "$output" >| "$path"
    print -u2 "Wrote: $path"
  fi

  # --- Copy to clipboard ---
  if (( do_copy )); then
    print -r -- "$output" | _clipboard_copy
    print -u2 "Copied to clipboard."
  fi
}
