# Edit the current PR's description in nvim.
# Usage:
#   ghpre              # edit PR inferred from current branch
#   ghpre 14530        # edit PR #14530
#   ghpre https://github.com/org/repo/pull/14530
function ghpre() {
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

  # --- Determine PR target ---
  local target="${1:-}"
  local pr_number=""

  local repo=""
  repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")"
  local gh_repo_args=()
  if [[ -n "$repo" ]]; then
    gh_repo_args=(--repo "$repo")
  fi

  if [[ -n "$target" ]]; then
    if [[ "$target" =~ ^[0-9]+$ ]]; then
      pr_number="$target"
    else
      pr_number="$(gh pr view "$target" "${gh_repo_args[@]}" --json number -q .number 2>/dev/null || true)"
    fi
  else
    local branch
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
      echo "❌ Not on a branch and no PR specified."
      return 1
    fi
    pr_number="$(gh pr view "$branch" "${gh_repo_args[@]}" --json number -q .number 2>/dev/null || true)"
  fi

  if [[ -z "$pr_number" ]]; then
    echo "❌ Could not find an open PR."
    return 1
  fi

  # --- Fetch current body ---
  local body
  body="$(gh pr view "$pr_number" "${gh_repo_args[@]}" --json body -q .body 2>/dev/null)"

  # --- Write to temp file and edit ---
  local tmpfile
  tmpfile="$(mktemp /tmp/ghpre-XXXXXX.md)"
  echo "$body" > "$tmpfile"

  nvim "$tmpfile"

  # --- Check if user made changes ---
  local new_body
  new_body="$(cat "$tmpfile")"
  rm -f "$tmpfile"

  if [[ "$new_body" == "$body" ]]; then
    echo "💤 No changes made."
    return 0
  fi

  # --- Update PR ---
  echo "📝 Updating PR #$pr_number description..."
  if gh pr edit "$pr_number" "${gh_repo_args[@]}" --body "$new_body"; then
    echo "✅ PR description updated."
  else
    echo "❌ Failed to update PR description."
    return 1
  fi
}
