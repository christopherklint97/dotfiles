#!/usr/bin/env bash
# Interactive large-file cleaner.
# Scans a directory for big files, lets you multi-select via fzf,
# moves selections to ~/.Trash (recoverable, not rm).
#
# Usage:
#   big-files.sh [PATH] [MIN_SIZE] [TOP_N]
#     PATH      default: $HOME
#     MIN_SIZE  find -size syntax, default: +100M
#     TOP_N     keep top N largest, default: 200
#
# Examples:
#   big-files.sh                    # ~ , >100MB, top 200
#   big-files.sh ~/Downloads +50M   # Downloads, >50MB
#   big-files.sh / +1G 100          # whole disk >1GB (needs sudo for some paths)

set -uo pipefail

ROOT="${1:-$HOME}"
MIN_SIZE="${2:-+100M}"
TOP_N="${3:-200}"

command -v fzf >/dev/null || { echo "fzf required (brew install fzf)" >&2; exit 1; }

ROOT="${ROOT/#\~/$HOME}"
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 1; }

TRASH="$HOME/.Trash"
mkdir -p "$TRASH"

# Prune well-known noisy paths: VCS, snapshots, system caches we don't own,
# Time Machine local snapshots, app bundles (deleting one file inside breaks app).
PRUNE=(
  -path '*/.git' -o
  -path '*/node_modules/.cache' -o
  -path '*/Library/Application Support/MobileSync' -o
  -path '*/Library/Mobile Documents' -o
  -path '*/.Trash' -o
  -path '*.app' -o
  -path '/System/*' -o
  -path '/private/var/*' -o
  -path '/Volumes/*'
)

echo "Scanning $ROOT for files $MIN_SIZE (top $TOP_N) — this can take a minute..." >&2

TMP="$(mktemp -t bigfiles.XXXXXX)"
trap 'rm -f "$TMP"' EXIT

# Find big files, print "<bytes> <path>"; sort desc by bytes; keep top N.
find "$ROOT" \( "${PRUNE[@]}" \) -prune -o \
  -type f -size "$MIN_SIZE" -print0 2>/dev/null \
  | xargs -0 stat -f '%z %N' 2>/dev/null \
  | sort -rn \
  | head -n "$TOP_N" > "$TMP"

if [ ! -s "$TMP" ]; then
  echo "No files larger than $MIN_SIZE under $ROOT." >&2
  exit 0
fi

# Pretty display: human size + path. Keep raw path as the selectable value.
DISPLAY="$(awk '{
  bytes=$1; $1=""; sub(/^ /,"");
  if (bytes >= 1073741824) printf "%7.2f GB\t%s\n", bytes/1073741824, $0;
  else                     printf "%7.1f MB\t%s\n", bytes/1048576,    $0;
}' "$TMP")"

echo "Pick files to remove (Tab = multi-select, Enter = confirm, Esc = abort)" >&2
SELECTED="$(printf '%s\n' "$DISPLAY" | fzf --multi --reverse --header='TAB to multi-select, ENTER to delete, ESC to abort' --preview='echo {}' --preview-window=down:1)" || {
  echo "Aborted." >&2
  exit 0
}

[ -z "$SELECTED" ] && { echo "Nothing selected." >&2; exit 0; }

# Extract paths back from the display lines (everything after the tab)
mapfile -t PATHS < <(printf '%s\n' "$SELECTED" | awk -F'\t' '{print $2}')

echo ""
echo "Will move ${#PATHS[@]} file(s) to Trash:"
for p in "${PATHS[@]}"; do echo "  $p"; done
echo ""
read -r -p "Proceed? [y/N] " ans
case "$ans" in
  y|Y|yes|YES) ;;
  *) echo "Aborted."; exit 0 ;;
esac

moved=0
for p in "${PATHS[@]}"; do
  base="$(basename "$p")"
  dest="$TRASH/$base"
  # Disambiguate if collision
  if [ -e "$dest" ]; then
    dest="$TRASH/${base%.*}.$(date +%s).${base##*.}"
  fi
  if mv "$p" "$dest" 2>/dev/null; then
    echo "→ trashed: $p"
    moved=$((moved+1))
  else
    echo "✗ failed:  $p" >&2
  fi
done

echo ""
echo "Moved $moved/${#PATHS[@]} file(s) to $TRASH (empty Trash to reclaim space)."
