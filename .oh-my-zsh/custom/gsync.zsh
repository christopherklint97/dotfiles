# Sync the current branch with the default branch.
# Detects the default branch, updates it from origin, then rebases the
# current branch on top of it.
#
# Usage:
#   gsync
function gsync() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ Not a git repo."
    return 1
  fi

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ -z "$current_branch" || "$current_branch" == "HEAD" ]]; then
    echo "❌ Not on a branch (detached HEAD?)."
    return 1
  fi

  # --- Detect default branch ---
  local default_branch=""
  default_branch="$(git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's@^origin/@@')"
  if [[ -z "$default_branch" ]]; then
    # Try to refresh origin/HEAD from the remote
    git remote set-head origin --auto >/dev/null 2>&1 || true
    default_branch="$(git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null | sed 's@^origin/@@')"
  fi
  if [[ -z "$default_branch" ]]; then
    # Fallback: try common names
    if git show-ref --verify --quiet refs/remotes/origin/main; then
      default_branch="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then
      default_branch="master"
    fi
  fi
  if [[ -z "$default_branch" ]]; then
    echo "❌ Could not determine the default branch."
    return 1
  fi

  echo "🔍 Default branch: $default_branch"
  echo "🌿 Current branch: $current_branch"

  # --- Refuse to run with a dirty tree (would break checkout/rebase) ---
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "❌ Working tree is dirty. Commit or stash changes first."
    return 1
  fi

  # --- Update default branch ---
  echo "📥 Fetching all remotes..."
  if ! git fetch --all --prune; then
    echo "❌ git fetch failed."
    return 1
  fi

  if [[ "$current_branch" != "$default_branch" ]]; then
    echo "🔀 Checking out $default_branch..."
    if ! git checkout "$default_branch"; then
      echo "❌ Failed to checkout $default_branch."
      return 1
    fi
  fi

  echo "⬇️  Pulling $default_branch..."
  if ! git pull --ff-only; then
    echo "❌ git pull failed on $default_branch."
    # Try to return the user to where they started
    if [[ "$current_branch" != "$default_branch" ]]; then
      git checkout "$current_branch" >/dev/null 2>&1 || true
    fi
    return 1
  fi

  if [[ "$current_branch" == "$default_branch" ]]; then
    echo "✨ Already on $default_branch — done."
    return 0
  fi

  echo "🔁 Returning to $current_branch..."
  if ! git checkout "$current_branch"; then
    echo "❌ Failed to checkout $current_branch."
    return 1
  fi

  echo "🧬 Rebasing $current_branch onto $default_branch..."
  if ! git rebase "$default_branch"; then
    echo "❌ Rebase hit conflicts. Resolve them, then run 'git rebase --continue'."
    return 1
  fi

  echo "✨ Done."
}
