#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# ci-templates one-line installer (POSIX / macOS / Linux / WSL / Git Bash)
#
# Usage (from the root of your project):
#   curl -fsSL https://raw.githubusercontent.com/2029193370/ci-templates/main/scripts/install.sh | bash
#
# Or, to pin to a specific tag (recommended for reproducibility):
#   curl -fsSL https://raw.githubusercontent.com/2029193370/ci-templates/v2.0.0/scripts/install.sh | bash
#
# Environment overrides:
#   CI_TEMPLATES_REF   branch or tag to pull starter from (default: main)
#   CI_TEMPLATES_FORCE set to 1 to overwrite existing ci.yml without prompting
# ----------------------------------------------------------------------------

set -euo pipefail

REPO="2029193370/ci-templates"
REF="${CI_TEMPLATES_REF:-main}"
FORCE="${CI_TEMPLATES_FORCE:-0}"
TARGET=".github/workflows/ci.yml"
URL="https://raw.githubusercontent.com/${REPO}/${REF}/starter/.github/workflows/ci.yml"

cyan()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[1;31m%s\033[0m\n' "$*" 1>&2; }
info()  { printf '\033[1;34m[ci-templates]\033[0m %s\n' "$*"; }

trap 'red "[ci-templates] Aborted."; exit 1' INT TERM

cat <<'BANNER'
  ┌──────────────────────────────────────────┐
  │   ci-templates · one-line installer      │
  └──────────────────────────────────────────┘
BANNER

if [ ! -d .git ]; then
  red "Not inside a git repository."
  red "Run this from the root of the project you want to enable CI on."
  exit 1
fi

if [ -e "$TARGET" ] && [ "$FORCE" != "1" ]; then
  if [ ! -t 0 ]; then
    red "$TARGET already exists and stdin is a pipe (no TTY to prompt)."
    red "Re-run with: CI_TEMPLATES_FORCE=1 ... | bash   to overwrite."
    exit 1
  fi
  printf '[ci-templates] %s already exists. Overwrite? [y/N] ' "$TARGET"
  read -r ans </dev/tty
  case "$ans" in
    y|Y|yes|YES) ;;
    *) info "Aborted without changes."; exit 0 ;;
  esac
fi

mkdir -p "$(dirname "$TARGET")"

info "Downloading starter from $URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$TARGET"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TARGET" "$URL"
else
  red "Need either curl or wget on PATH."
  exit 1
fi

if [ ! -s "$TARGET" ]; then
  red "Downloaded file is empty — network issue or bad ref '$REF'."
  rm -f "$TARGET"
  exit 1
fi

green "Installed: $TARGET"
cyan "Next steps:"
echo "  1. Review the file   :  less $TARGET"
echo "  2. Commit the change :  git add $TARGET && git commit -m 'ci: adopt ci-templates'"
echo "  3. Push              :  git push"
echo
cyan "Docs    : https://github.com/${REPO}#readme"
cyan "Landing : https://2029193370.github.io/ci-templates/"
