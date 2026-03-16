# Merge the current branch's PR (or a given PR) non-interactively.
# Usage:
#   ghprm                # infer PR from current branch
#   ghprm 14530          # merge PR #14530
#   ghprm https://github.com/org/repo/pull/14530
#   GHMERGE_METHOD=merge ghprm    # override method (squash|merge|rebase)
function ghprm() {
  # --- Config ---
  local method="${GHMERGE_METHOD:-squash}"     # squash | merge | rebase
  local delete_branch_flag="--delete-branch"

  # --- Sanity checks ---
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not a git repo."
    return 1
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) not found."
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "❌ You are not logged in to gh (run: gh auth login)."
    return 1
  fi

  # --- Detect repo (for printing & optional --repo) ---
  local repo=""
  repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")"
  local gh_repo_args=()
  if [[ -n "$repo" ]]; then
    gh_repo_args=(--repo "$repo")
  fi

  # --- Determine remote (prefer 'origin', fallback first remote) ---
  local remote
  remote="$(git remote 2>/dev/null | grep -m1 '^origin$' || true)"
  if [[ -z "$remote" ]]; then
    remote="$(git remote 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "$remote" ]]; then
    echo "❌ No git remotes found."
    return 1
  fi

  # --- Figure out PR target (arg, or infer from current branch) ---
  local target="${1:-}"
  local pr_number=""
  local branch=""
  local base_ref=""

  if [[ -n "$target" ]]; then
    # Accept number, URL, or branch name
    if [[ "$target" =~ ^[0-9]+$ ]]; then
      pr_number="$target"
    else
      # Let gh resolve it, then extract number
      if [[ -n "$repo" ]]; then
        pr_number="$(gh pr view "$target" "${gh_repo_args[@]}" --json number -q .number 2>/dev/null || true)"
      else
        pr_number="$(gh pr view "$target" --json number -q .number 2>/dev/null || true)"
      fi
    fi
  else
    # Infer from current branch
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
      echo "❌ Not on a branch and no PR specified."
      return 1
    fi
    if [[ -n "$repo" ]]; then
      pr_number="$(gh pr view "$branch" "${gh_repo_args[@]}" --json number -q .number 2>/dev/null || true)"
    else
      pr_number="$(gh pr view "$branch" --json number -q .number 2>/dev/null || true)"
    fi
  fi

  if [[ -z "$pr_number" ]]; then
    echo "❌ Could not find an open PR to merge."
    echo "   Tip: run inside a PR branch or pass a PR number/URL."
    return 1
  fi

  # --- Fetch PR details for pretty banner ---
  local json
  if [[ -n "$repo" ]]; then
    json="$(gh pr view "$pr_number" "${gh_repo_args[@]}" --json number,title,headRefName,baseRefName,author,mergeStateStatus,url 2>/dev/null)"
  else
    json="$(gh pr view "$pr_number" --json number,title,headRefName,baseRefName,author,mergeStateStatus,url 2>/null)"
  fi

  if [[ -z "$json" ]]; then
    echo "❌ Failed to fetch PR details for #$pr_number."
    return 1
  fi

  local title head_ref url state
  title="$(echo "$json" | jq -r .title)"
  head_ref="$(echo "$json" | jq -r .headRefName)"
  base_ref="$(echo "$json" | jq -r .baseRefName)"
  url="$(echo "$json" | jq -r .url)"
  state="$(echo "$json" | jq -r .mergeStateStatus)"

  local repo_label="${repo:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo ".")")}"

  echo "🔀 Preparing to merge PR $repo_label#$pr_number"
  echo "──────────────────────────────"
  echo "📝 Title:   $title"
  echo "🌿 Head:    $head_ref"
  echo "🧬 Base:    $base_ref"
  echo "🔗 URL:     $url"
  echo "✅ State:   $state"
  echo "⚙️ Method:  $method"
  echo "🧹 Delete:  local & remote branch"
  echo "──────────────────────────────"
  echo ""

  # --- Perform non-interactive merge ---
  local method_flag="--squash"
  case "$method" in
    squash) method_flag="--squash" ;;
    merge)  method_flag="--merge" ;;
    rebase) method_flag="--rebase" ;;
    *) echo "❌ Invalid GHMERGE_METHOD: $method (use squash|merge|rebase)"; return 1 ;;
  esac

  # Ensure we’re not on a dirty working tree that could block checkout after delete
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️  You have uncommitted changes. The local branch delete may fail."
  fi

  echo "🧩 Merging..."
  if gh pr merge "$pr_number" "${gh_repo_args[@]}" "$method_flag" "$delete_branch_flag" >/dev/null; then
    echo "✅ Merged PR $repo_label#$pr_number via ${method}."
  else
    echo "❌ Merge failed."
    return 1
  fi

  # --- After-merge housekeeping ---
  echo "🧹 Branch '$head_ref' deleted (local & remote)."

  # Detect worktree by cwd and map to parked branch
  local cwd="$(pwd)"
  local dir_name="${cwd##*/}"
  local parked_branch=""
  if [[ "$dir_name" == telness3 ]]; then
    parked_branch="parked3"
  elif [[ "$dir_name" == telness2 ]]; then
    parked_branch="parked2"
  elif [[ "$dir_name" == telness ]]; then
    parked_branch="parked"
  fi

  if [[ -n "$parked_branch" ]]; then
    echo "🔄 Worktree detected — updating master and rebasing $parked_branch..."
    git checkout master && git pull && git checkout "$parked_branch" && git rebase master
  else
    local on_branch
    on_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ "$on_branch" == "$head_ref" ]]; then
      if git show-ref --verify --quiet "refs/heads/$base_ref"; then
        git checkout "$base_ref" >/dev/null 2>&1 || true
      else
        git fetch "$remote" "$base_ref" >/dev/null 2>&1 || true
        git checkout -t "$remote/$base_ref" >/dev/null 2>&1 || true
      fi
    fi
    git pull
  fi

  echo "✨ Done."
}

