#!/usr/bin/env bash
#
# mac-cleanup.sh - macOS disk cleanup helper.
#
# Two modes:
#   analyze  (default)  Read-only. Reports disk usage, large files, caches,
#                       and Docker usage. Never deletes anything.
#   clean               Interactive. Cleans only SAFE items after explicit
#                       confirmation. Never touches the KEEP list.
#
# Usage: mac-cleanup.sh [analyze|clean]

set -euo pipefail

# ---------------------------------------------------------------------------
# KEEP list. These paths are NEVER deleted in clean mode.
# ---------------------------------------------------------------------------
KEEP_PATHS=(
  "$HOME/Library/Developer/Xcode/DerivedData"
  "$HOME/.npm/_cacache"
  "$HOME/.cache/uv"
  "$HOME/Library/Caches/ms-playwright"
  "$HOME/Library/Developer/CoreSimulator/Devices"
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  "$HOME/.cache/huggingface"
  "$HOME/.cache/modelscope"
  "$HOME/Library/Caches/JetBrains"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Print a friendly skip message when a tool is missing.
have() { command -v "$1" >/dev/null 2>&1; }

# Human-readable byte size.
human() {
  local bytes="$1"
  if have gnumfmt; then
    gnumfmt --to=iec "$bytes" 2>/dev/null || echo "${bytes} bytes"
  else
    # macOS fallback: use awk to format.
    awk -v b="$bytes" 'BEGIN {
      if (b < 1024) { printf "%d B", b; exit }
      b/=1024; if (b < 1024) { printf "%.1f KB", b; exit }
      b/=1024; if (b < 1024) { printf "%.1f MB", b; exit }
      b/=1024; printf "%.1f GB", b
    }'
  fi
}

# Size of a directory in bytes, or empty if it does not exist.
dir_size() {
  local d="$1"
  [ -d "$d" ] || return 0
  du -sk "$d" 2>/dev/null | awk '{print $1 * 1024}'
}

# ---------------------------------------------------------------------------
# Classification legend
# ---------------------------------------------------------------------------
legend() {
  cat <<'EOF'

Classification legend:
  🟢 safe          Safe to delete. Rebuilds automatically or is pure cache.
  🟡 trade-off     Deleting frees space but costs a rebuild or re-download.
  🔴 do not delete Never delete. Contains data or state you cannot recover.

Each finding below includes an "Impact If Deleted" note.
EOF
}

# ---------------------------------------------------------------------------
# ANALYZE MODE
# ---------------------------------------------------------------------------
analyze() {
  echo "=== Disk usage (main volume) ==="
  df -h / || true

  echo
  echo "=== Large files (top 20 over 500 MB under \$HOME) ==="
  # Bounded scan: only regular files, size threshold, head limit.
  # find exits non-zero on unreadable folders (common under ~/Library), so
  # don't let that abort the report.
  find "$HOME" -type f -size +500M -print0 2>/dev/null \
    | xargs -0 du -h 2>/dev/null \
    | sort -rh \
    | head -n 20 \
    || true

  echo
  echo "=== Caches and their sizes ==="

  local caches_size trash_size brew_cache npm_cache pip_cache
  caches_size=$(dir_size "$HOME/Library/Caches")
  trash_size=$(dir_size "$HOME/.Trash")
  brew_cache=$(dir_size "$(brew --cache 2>/dev/null || echo "$HOME/Library/Caches/Homebrew")")
  npm_cache=$(dir_size "$HOME/.npm")
  pip_cache=$(dir_size "$HOME/Library/Caches/pip")

  echo "  ~/Library/Caches:        $(human "${caches_size:-0}")  🟡 trade-off"
  echo "    Impact If Deleted: apps rebuild caches on next launch; some login state may reset."
  echo "  Trash (~/.Trash):        $(human "${trash_size:-0}")  🟢 safe"
  echo "    Impact If Deleted: permanently removes files you already chose to delete."
  echo "  Homebrew cache:          $(human "${brew_cache:-0}")  🟢 safe"
  echo "    Impact If Deleted: brew re-downloads bottles/formulae on next install."
  echo "  npm cache (~/.npm):      $(human "${npm_cache:-0}")  🟡 trade-off"
  echo "    Impact If Deleted: npm re-downloads packages; _cacache is on the KEEP list."
  echo "  pip cache:                $(human "${pip_cache:-0}")  🟡 trade-off"
  echo "    Impact If Deleted: pip re-downloads wheels on next install."

  echo
  echo "=== Docker disk usage ==="
  if have docker; then
    docker system df 2>/dev/null || echo "  (docker daemon not running or permission denied)"
  else
    echo "  (docker not installed, skipping)"
  fi

  echo
  echo "=== Tool cache sizes ==="
  if have brew; then
    echo "  Homebrew: $(human "$(dir_size "$(brew --cache 2>/dev/null || echo "$HOME/Library/Caches/Homebrew")")")"
  else
    echo "  Homebrew: not installed"
  fi
  if have npm; then
    echo "  npm:      $(human "$(dir_size "$HOME/.npm")")"
  else
    echo "  npm:      not installed"
  fi
  if have pip3; then
    echo "  pip:      $(human "$(dir_size "$HOME/Library/Caches/pip")")"
  else
    echo "  pip:      not installed"
  fi

  legend
}

# ---------------------------------------------------------------------------
# CLEAN MODE
# ---------------------------------------------------------------------------
clean() {
  echo "=== Clean mode ==="
  echo "This will clean only SAFE items. The KEEP list is never touched."
  echo

  # Trash
  if [ -d "$HOME/.Trash" ]; then
    local trash_size
    trash_size=$(dir_size "$HOME/.Trash")
    echo "1. Empty Trash ($(human "${trash_size:-0}"))"
    read -r -p "   Empty the Trash? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      # Ask Finder to empty the Trash. No rm -rf fallback: the skill never
      # deletes by glob, so if Finder can't do it the user empties it by hand.
      if osascript -e 'tell application "Finder" to empty trash' 2>/dev/null; then
        echo "   Done."
      else
        echo "   Could not empty the Trash automatically. Empty it from Finder instead."
      fi
    else
      echo "   Skipped."
    fi
  else
    echo "1. Trash: not present, skipping."
  fi

  # Homebrew old versions
  if have brew; then
    echo "2. Homebrew old versions (brew cleanup)"
    echo "   brew cleanup would remove:"
    brew cleanup -n 2>/dev/null | sed 's/^/     /' || echo "     (could not list)"
    read -r -p "   Run 'brew cleanup'? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      brew cleanup || echo "   (brew cleanup failed)"
      echo "   Done."
    else
      echo "   Skipped."
    fi
  else
    echo "2. Homebrew: not installed, skipping."
  fi

  # npm _npx cache (NOT _cacache, which is on the KEEP list)
  if have npm; then
    local npx_cache="$HOME/.npm/_npx"
    if [ -d "$npx_cache" ]; then
      echo "3. npm _npx cache ($(human "$(dir_size "$npx_cache")"))"
      read -r -p "   Remove npm _npx cache? [y/N] " ans
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        rm -rf "$npx_cache"
        echo "   Done."
      else
        echo "   Skipped."
      fi
    else
      echo "3. npm _npx cache: not present, skipping."
    fi
  else
    echo "3. npm: not installed, skipping."
  fi

  echo
  echo "Clean complete. Docker volumes/images and all KEEP-list paths were left untouched."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: mac-cleanup.sh [analyze|clean]

  analyze  (default)  Read-only report of disk usage, large files, caches,
                      and Docker usage. Never deletes anything.
  clean               Interactive cleanup of SAFE items only (Trash,
                      Homebrew old versions, npm _npx cache). Prompts before
                      every deletion. Never touches the KEEP list.
EOF
}

mode="${1:-analyze}"
case "$mode" in
  analyze) analyze ;;
  clean)   clean ;;
  -h|--help|help) usage ;;
  *) echo "Unknown mode '$mode'. Defaulting to analyze." >&2; analyze ;;
esac
