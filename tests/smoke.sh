#!/usr/bin/env bash
# Minimal end-to-end smoke test for install.sh.
# Runs entirely inside a temp $HOME so it is safe on developer machines.
#
#   bash tests/smoke.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAKE_HOME="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME"' EXIT

export HOME="$FAKE_HOME"
export SKILLS_INSTALLER_LOCAL_ROOT="$ROOT"
export SKILLS_INSTALLER_REPO="${SKILLS_INSTALLER_REPO:-2029193370/skills}"
export SKILLS_INSTALLER_REF="${SKILLS_INSTALLER_REF:-main}"

mkdir -p "$FAKE_HOME/.cursor"

echo "[1/5] --list (offline MIT subset)"
bash "$ROOT/scripts/install.sh" --list --offline --agent=cursor --scope=global \
  --skills=find-skills,ui-ux-pro-max

echo "[2/5] --dry-run (offline)"
bash "$ROOT/scripts/install.sh" --dry-run --offline --yes --agent=cursor \
  --skills=find-skills,ui-ux-pro-max

echo "[3/5] install (offline) find-skills + ui-ux-pro-max"
bash "$ROOT/scripts/install.sh" --offline --yes --agent=cursor \
  --skills=find-skills,ui-ux-pro-max

test -f "$FAKE_HOME/.cursor/skills/find-skills/SKILL.md" \
  || { echo "FAIL: find-skills/SKILL.md missing"; exit 1; }
test -f "$FAKE_HOME/.cursor/skills/ui-ux-pro-max/SKILL.md" \
  || { echo "FAIL: ui-ux-pro-max/SKILL.md missing"; exit 1; }
test -f "$FAKE_HOME/.cursor/skills/.skills-installer.json" \
  || { echo "FAIL: manifest missing"; exit 1; }

echo "[4/5] install offline superpowers (flatten semantics)"
bash "$ROOT/scripts/install.sh" --offline --yes --agent=cursor --skills=superpowers

test -d "$FAKE_HOME/.cursor/skills/superpowers" \
  || { echo "FAIL: superpowers dir missing"; exit 1; }
test -f "$FAKE_HOME/.cursor/skills/superpowers/testing/test-driven-development/SKILL.md" \
  || { echo "FAIL: superpowers TDD skill missing"; exit 1; }

echo "[5/5] uninstall everything we wrote"
bash "$ROOT/scripts/install.sh" --uninstall --yes --agent=cursor \
  --skills=find-skills,ui-ux-pro-max,superpowers

test ! -d "$FAKE_HOME/.cursor/skills/find-skills" \
  || { echo "FAIL: find-skills should have been removed"; exit 1; }
test ! -d "$FAKE_HOME/.cursor/skills/superpowers" \
  || { echo "FAIL: superpowers should have been removed"; exit 1; }

echo
echo "All smoke tests passed."
