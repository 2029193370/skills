#!/usr/bin/env bash
# Uninstall skills installed by skills-installer. Thin wrapper over install.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/2029193370/skills/main/scripts/uninstall.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/2029193370/skills/main/scripts/uninstall.sh | bash -s -- --agent=cursor --skills=superpowers

set -euo pipefail
REPO="${SKILLS_INSTALLER_REPO:-2029193370/skills}"
REF="${SKILLS_INSTALLER_REF:-main}"
exec bash <(curl -fsSL "https://raw.githubusercontent.com/${REPO}/${REF}/scripts/install.sh") --uninstall "$@"
