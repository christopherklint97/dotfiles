# Create a GitHub Pull Request for the current branch using gh CLI.
# Optionally runs a Claude post-update task after PR creation.
# Usage: ghprc [OPTIONS] [TITLE]
#
# Options:
#   -c, --with-claude   Run Claude post-update task after PR creation
#       --no-claude     Do not run Claude (default)
#   -r, --copilot-review  Request a review from GitHub Copilot after PR creation
#       --no-copilot-review  Do not request Copilot review (default)
#   -v, --view          Open the PR in the browser after creation
#       --              Stop parsing flags; everything after is the title
#   -h, --help          Show this help
function ghprc() {
  local run_claude=false
  local view_pr=false
  local copilot_review=false
  local title=""
  local stop_parsing=false

  # Allow env overrides
  if [[ "${GHPRC_WITH_CLAUDE:-0}" == "1" ]]; then
    run_claude=true
  fi
  if [[ "${GHPRC_COPILOT_REVIEW:-0}" == "1" ]]; then
    copilot_review=true
  fi

  # --- Parse args (flags can appear anywhere) ---
  for arg in "$@"; do
    if [[ "$stop_parsing" == true ]]; then
      # everything after -- is positional (title)
      if [[ -z "$title" ]]; then title="$arg"; else title="$title $arg"; fi
      continue
    fi

    case "$arg" in
      --) stop_parsing=true ;;
      -c|--with-claude) run_claude=true ;;
      --no-claude)      run_claude=false ;;
      -r|--copilot-review)    copilot_review=true ;;
      --no-copilot-review)    copilot_review=false ;;
      -v|--view)        view_pr=true ;;
      -h|--help)
        cat <<'EOF'
Usage: ghprc [OPTIONS] [TITLE]

Options:
  -c, --with-claude        Run Claude post-update task after PR creation
      --no-claude          Do not run Claude (default)
  -r, --copilot-review     Request a review from GitHub Copilot after PR creation
      --no-copilot-review  Do not request Copilot review (default)
  -v, --view               Open the PR in the browser after creation
      --                   Stop parsing flags; everything after is the title
  -h, --help               Show this help

Notes:
- TITLE is optional; if omitted, the latest commit message is used.
- You can set GHPRC_WITH_CLAUDE=1 to enable Claude by default.
- You can set GHPRC_COPILOT_REVIEW=1 to enable Copilot review by default.

Examples:
  ghprc "TELCO-1234: Add feature"
  ghprc -c "TELCO-1234: Add feature"
  ghprc -r "TELCO-1234: Add feature"
  ghprc "TELCO-1234: Title with -- dashes"   # no special meaning
  ghprc -- "TELCO-1234: Title with -- keep as title"
EOF
        return 0
        ;;
      *)
        # First non-flag becomes/extends title
        if [[ -z "$title" ]]; then title="$arg"; else title="$title $arg"; fi
        ;;
    esac
  done

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

  # --- Title (arg or latest commit) ---
  if [[ -z "$title" ]]; then
    title="$(git log -1 --pretty=%s 2>/dev/null)"
    if [[ -z "$title" ]]; then
      echo "❌ Could not infer a title (no commits?)."
      return 1
    fi
    echo "ℹ️  No title provided — using latest commit message:"
    echo "   \"$title\""
    echo ""
  fi

  # --- Current branch ---
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
    echo "❌ Not a git repo."
    return 1
  }

  # --- Choose remote (prefer 'origin', fallback first remote) ---
  local remote
  remote="$(git remote 2>/dev/null | grep -m1 '^origin$' || true)"
  if [[ -z "$remote" ]]; then
    remote="$(git remote 2>/dev/null | head -n1 || true)"
  fi
  if [[ -z "$remote" ]]; then
    echo "❌ No git remotes found."
    return 1
  fi

  # --- Ensure branch has an upstream to avoid gh prompt ---
  if ! git rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
    echo "⬆️  Pushing branch and setting upstream: $remote $branch"
    git push -u "$remote" "$branch" || {
      echo "❌ Failed to push branch."
      return 1
    }
  fi

  # --- Detect repo and default base branch (fallback to git remote HEAD, then main) ---
  local repo=""
  repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")"

  local base=""
  base="$(gh repo view ${repo:+$repo} --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")"

  if [[ -z "$base" ]]; then
    base="$(git remote show "$remote" 2>/dev/null | sed -n 's/.*HEAD branch: //p')"
  fi
  [[ -z "$base" ]] && base="main"
  [[ -n "$GHPR_BASE" ]] && base="$GHPR_BASE"

  # --- Find a PR template locally (gh needs a file path) ---
  local body_file=""
  local candidates=(".github/PULL_REQUEST_TEMPLATE.md")
  for f in "${candidates[@]}"; do
    [[ -f "$f" ]] && { body_file="$f"; break; }
  done
  if [[ -z "$body_file" && -d ".github/PULL_REQUEST_TEMPLATE" ]]; then
    body_file="$(ls -1 .github/PULL_REQUEST_TEMPLATE/*.md 2>/dev/null | head -n 1)"
  fi

  # --- Repo label for printing ---
  local remote_url
  remote_url="$(git config --get "remote.$remote.url" 2>/dev/null || echo "$remote")"
  local repo_label="${repo:-$remote_url}"

  # --- gh --repo flag (optional) ---
  local gh_repo_args=()
  if [[ -n "$repo" ]]; then
    gh_repo_args=(--repo "$repo")
  fi

  echo "🚀 Creating GitHub PR..."
  echo "──────────────────────────────"
  echo "📦 Repo:     $repo_label"
  echo "🌿 Branch:   $branch"
  echo "🧬 Base:     $base"
  echo "📝 Title:    $title"
  if [[ -n "$body_file" ]]; then
    echo "📄 Template: $body_file"
  else
    echo "📄 Template: (none found locally — PR body will be empty)"
  fi
  echo "──────────────────────────────"
  echo ""

  # --- Create PR ---
  if [[ -n "$body_file" ]]; then
    gh pr create \
      "${gh_repo_args[@]}" \
      --head "$branch" \
      --base "$base" \
      --title "$title" \
      --body-file "$body_file" \
      --assignee @me
  else
    gh pr create \
      "${gh_repo_args[@]}" \
      --head "$branch" \
      --base "$base" \
      --title "$title" \
      --body "" \
      --assignee @me
  fi

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo ""
    echo "✅ PR created successfully."
    if [[ "$run_claude" == true ]]; then
      echo "⚙️  Running Claude post-update task: /update-active-github-pr-description"
      echo "──────────────────────────────"
      claude -p '/update-active-github-pr-description'
      echo "✅ Done!"
    else
      echo "💤 Skipping Claude post-update (enable with -c or --with-claude)."
    fi
    if [[ "$copilot_review" == true ]]; then
      echo "🤖 Requesting review from GitHub Copilot..."
      local pr_number
      pr_number="$(gh pr view "$branch" "${gh_repo_args[@]}" --json number -q .number 2>/dev/null)"
      if [[ -n "$pr_number" && -n "$repo" ]]; then
        gh api --method POST "/repos/$repo/pulls/$pr_number/requested_reviewers" \
          -f 'reviewers[]=copilot-pull-request-reviewer[bot]' >/dev/null 2>&1 \
          && echo "✅ Copilot review requested." \
          || echo "⚠️  Failed to request Copilot review (is Copilot code review enabled for this repo?)."
      else
        echo "⚠️  Could not determine PR number or repo — skipping Copilot review request."
      fi
    fi
    if [[ "$view_pr" == true ]]; then
      echo "🌐 Opening PR in browser..."
      gh pr view "${gh_repo_args[@]}" "$branch" --web
    fi
  else
    echo ""
    echo "❌ PR creation failed (exit code: $exit_code)."
  fi
}

