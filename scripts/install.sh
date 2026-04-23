#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# skills-installer · one-line installer (POSIX / macOS / Linux / WSL / Git Bash)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/2029193370/skills/main/scripts/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/2029193370/skills/main/scripts/install.sh | bash -s -- --agent=cursor --skills=superpowers
#
# Environment overrides:
#   SKILLS_INSTALLER_REPO   owner/name of the registry repo (default: 2029193370/skills)
#   SKILLS_INSTALLER_REF    branch or tag (default: main)
#
# Exit codes:
#   0  success  · 1 fatal error  · 2 usage error  · 3 no agent detected
# -----------------------------------------------------------------------------

set -euo pipefail

REPO="${SKILLS_INSTALLER_REPO:-2029193370/skills}"
REF="${SKILLS_INSTALLER_REF:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${REF}"

AGENT="all"
SCOPE="global"
SKILLS_SEL="all"
OFFLINE=0
FORCE=0
DRY_RUN=0
NON_INTERACTIVE=0
ACTION="install"

TMP_ROOT=""
cleanup() { [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ] && rm -rf "$TMP_ROOT" || true; }
trap 'rc=$?; cleanup; exit $rc' EXIT INT TERM

# ---------- pretty printing --------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[1;36m'; C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_MAG=$'\033[1;35m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_BLUE=""; C_CYAN=""; C_GREEN=""
  C_YELLOW=""; C_RED=""; C_MAG=""
fi
info()  { printf '%s[skills]%s %s\n'         "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s[skills]%s %s\n'         "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s[skills]%s %s\n'         "$C_YELLOW" "$C_RESET" "$*" 1>&2; }
err()   { printf '%s[skills]%s %s\n'         "$C_RED"    "$C_RESET" "$*" 1>&2; }
step()  { printf '\n%s==>%s %s%s%s\n'        "$C_MAG"    "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }

banner() {
  cat <<BANNER
${C_CYAN}
  ┌────────────────────────────────────────────────────┐
  │   skills-installer · one-command skills manager    │
  └────────────────────────────────────────────────────┘${C_RESET}
BANNER
}

usage() {
  cat <<USAGE
Usage: install.sh [OPTIONS]

Actions (pick one, default: install):
  --install                  Install selected skills (default).
  --uninstall                Remove previously installed skills (reads manifest).
  --list                     Print what would be installed and exit.

Selection:
  --agent=<all|cursor|claude|codex|windsurf>   Target agent family (default: all).
  --scope=<global|project>                     Install scope (default: global).
  --skills=<all|name1,name2,...>               Restrict to listed skill names.

Modes:
  --offline                  Use the bundled MIT-licensed mirror, no network.
  --force                    Overwrite existing skill directories without asking.
  --dry-run                  Print what would be done, don't touch disk.
  --yes                      Assume yes for every prompt (non-interactive safe).

Other:
  -h, --help                 Show this help.

Examples:
  curl -fsSL $BASE_URL/scripts/install.sh | bash
  curl -fsSL $BASE_URL/scripts/install.sh | bash -s -- --agent=cursor
  curl -fsSL $BASE_URL/scripts/install.sh | bash -s -- --offline --skills=superpowers,find-skills
USAGE
}

# ---------- argument parsing -------------------------------------------------
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --install)     ACTION="install" ;;
      --uninstall)   ACTION="uninstall" ;;
      --list)        ACTION="list" ;;
      --offline)     OFFLINE=1 ;;
      --force)       FORCE=1 ;;
      --dry-run)     DRY_RUN=1 ;;
      --yes|-y)      NON_INTERACTIVE=1 ;;
      --agent=*)     AGENT="${arg#--agent=}" ;;
      --scope=*)     SCOPE="${arg#--scope=}" ;;
      --skills=*)    SKILLS_SEL="${arg#--skills=}" ;;
      -h|--help)     usage; exit 0 ;;
      *) err "unknown argument: $arg"; usage; exit 2 ;;
    esac
  done

  case "$AGENT" in all|cursor|claude|codex|windsurf) ;; *) err "bad --agent: $AGENT"; exit 2 ;; esac
  case "$SCOPE" in global|project) ;;                *) err "bad --scope: $SCOPE"; exit 2 ;; esac
}

# ---------- dependency checks ------------------------------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "missing dependency: $1"; return 1; }; }

check_deps() {
  local miss=0
  for c in git curl; do need_cmd "$c" || miss=1; done
  command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || {
    err "need python3 (or python) on PATH for JSON parsing"; miss=1; }
  [ "$miss" -eq 0 ] || exit 1
}

py() {
  if command -v python3 >/dev/null 2>&1; then python3 "$@"; else python "$@"; fi
}

# ---------- agent detection --------------------------------------------------
agent_dir() {
  # $1=agent $2=scope   echoes the skills dir path (may or may not exist)
  local agent="$1" scope="$2"
  case "$agent,$scope" in
    cursor,global)   echo "$HOME/.cursor/skills" ;;
    cursor,project)  echo "$PWD/.cursor/skills" ;;
    claude,global)   echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills" ;;
    claude,project)  echo "$PWD/.claude/skills" ;;
    codex,global)    echo "$HOME/.codex/skills" ;;
    codex,project)   echo "$PWD/.codex/skills" ;;
    windsurf,global) echo "$HOME/.codeium/windsurf/skills" ;;
    windsurf,project) echo "$PWD/.windsurf/skills" ;;
    *) return 1 ;;
  esac
}

agent_home() {
  # returns the agent's config root (used only to decide "is this agent installed?")
  case "$1" in
    cursor)   echo "$HOME/.cursor" ;;
    claude)   echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
    codex)    echo "$HOME/.codex" ;;
    windsurf) echo "$HOME/.codeium/windsurf" ;;
  esac
}

detect_agents() {
  local found=()
  for a in cursor claude codex windsurf; do
    if [ -d "$(agent_home "$a")" ]; then found+=("$a"); fi
  done
  printf '%s\n' "${found[@]}"
}

# ---------- registry ---------------------------------------------------------
fetch_registry() {
  TMP_ROOT="$(mktemp -d)"
  REGISTRY_FILE="$TMP_ROOT/registry.json"
  if [ -n "${SKILLS_INSTALLER_LOCAL_ROOT:-}" ] && [ -f "$SKILLS_INSTALLER_LOCAL_ROOT/registry.json" ]; then
    info "using local repo root: $SKILLS_INSTALLER_LOCAL_ROOT"
    MIRROR_ROOT="$SKILLS_INSTALLER_LOCAL_ROOT"
    cp "$MIRROR_ROOT/registry.json" "$REGISTRY_FILE"
    return
  fi
  if [ "$OFFLINE" -eq 1 ]; then
    info "offline mode: downloading repo snapshot $REF"
    curl -fsSL "https://codeload.github.com/${REPO}/tar.gz/${REF}" \
      | tar -xz -C "$TMP_ROOT"
    # codeload extracts to <name>-<ref>/
    MIRROR_ROOT="$(find "$TMP_ROOT" -maxdepth 1 -mindepth 1 -type d | head -n1)"
    cp "$MIRROR_ROOT/registry.json" "$REGISTRY_FILE"
  else
    info "fetching registry from $BASE_URL/registry.json"
    curl -fsSL "$BASE_URL/registry.json" -o "$REGISTRY_FILE"
  fi
}

registry_q() {
  # $1 = python expression body; sees variable 'data' (parsed JSON) and prints to stdout
  py - "$REGISTRY_FILE" <<PY
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
$1
PY
}

list_skill_names() { registry_q 'print("\n".join(s["name"] for s in data["skills"]))'; }

# dumps the full skill record as shell-safe key=value lines
skill_fields() {
  local name="$1"
  py - "$REGISTRY_FILE" "$name" <<'PY'
import json, sys, shlex
data = json.load(open(sys.argv[1], encoding="utf-8"))
for s in data["skills"]:
    if s["name"] == sys.argv[2]:
        def q(v): return shlex.quote(str(v))
        print(f'SK_NAME={q(s["name"])}')
        print(f'SK_TITLE={q(s.get("title", s["name"]))}')
        print(f'SK_UPSTREAM={q(s["upstream"])}')
        print(f'SK_BRANCH={q(s.get("branch","main"))}')
        print(f'SK_LICENSE={q(s.get("license","unknown"))}')
        print(f'SK_REDIST={q(int(bool(s.get("redistributable", True))))}')
        print(f'SK_INSTALLAS={q(s.get("installAs",""))}')
        print(f'SK_FLATTEN={q(int(bool(s.get("flatten", False))))}')
        paths = " ".join(shlex.quote(p) for p in s["paths"])
        print(f'SK_PATHS=({paths})')
        sys.exit(0)
sys.exit(1)
PY
}

selected_names() {
  if [ "$SKILLS_SEL" = "all" ]; then
    list_skill_names
  else
    local IFS=','
    for n in $SKILLS_SEL; do printf '%s\n' "$n"; done
  fi
}

selected_agents() {
  local detected
  detected=$(detect_agents)
  if [ "$AGENT" = "all" ]; then
    printf '%s\n' "$detected"
  else
    if printf '%s\n' "$detected" | grep -Fxq "$AGENT"; then
      printf '%s\n' "$AGENT"
    else
      warn "requested agent '$AGENT' not detected; installing anyway (directory will be created)"
      printf '%s\n' "$AGENT"
    fi
  fi
}

# ---------- skill fetch from upstream ----------------------------------------
fetch_upstream_tree() {
  # $1=upstream $2=branch $3..=paths;  echoes the tmp work dir containing requested paths
  local upstream="$1" branch="$2"; shift 2
  local wd="$TMP_ROOT/src-$RANDOM"
  git clone --depth 1 --filter=blob:none --sparse --branch "$branch" "$upstream" "$wd" >/dev/null 2>&1
  ( cd "$wd" && git sparse-checkout set "$@" >/dev/null 2>&1 )
  echo "$wd"
}

resolve_source_dir() {
  # For online mode: git sparse clone upstream into tmp, return tmp path.
  # For offline mode: return the mirror dir under MIRROR_ROOT/skills/<name>.
  # Prints path (one line) on success, fails on error.
  local name="$1"
  # shellcheck disable=SC2155
  eval "$(skill_fields "$name")" || { err "skill '$name' not in registry"; return 1; }
  if [ "$OFFLINE" -eq 1 ]; then
    if [ "$SK_REDIST" != "1" ]; then
      warn "skill '$name' is not redistributable under --offline (license: $SK_LICENSE); skipping"
      return 2
    fi
    local mirrored="$MIRROR_ROOT/skills/$name"
    if [ ! -d "$mirrored" ]; then
      err "offline mirror missing for '$name' at $mirrored"; return 1
    fi
    echo "$mirrored"
  else
    fetch_upstream_tree "$SK_UPSTREAM" "$SK_BRANCH" "${SK_PATHS[@]}"
  fi
}

# ---------- copy one skill into a target skills dir --------------------------
install_one() {
  # $1=agent $2=skill_name
  local agent="$1" name="$2"
  eval "$(skill_fields "$name")"

  local dir; dir="$(agent_dir "$agent" "$SCOPE")" || { err "unknown agent/scope: $agent/$SCOPE"; return 1; }
  local src; src="$(resolve_source_dir "$name")" || {
    local rc=$?; [ "$rc" -eq 2 ] && return 0 || return 1
  }

  local targets=()
  if [ -n "$SK_INSTALLAS" ]; then
    # group all paths under <dir>/<installAs>/
    for p in "${SK_PATHS[@]}"; do
      local base; base=$(basename "$p")
      targets+=("$dir/$SK_INSTALLAS/$base:$src/$p")
    done
  elif [ "$SK_FLATTEN" = "1" ]; then
    # promote each immediate subdir of the single path
    local root="$src/${SK_PATHS[0]}"
    if [ "$OFFLINE" = "1" ]; then root="$src"; fi
    for sub in "$root"/*/; do
      [ -d "$sub" ] || continue
      local base; base=$(basename "$sub")
      targets+=("$dir/$name/$base:$sub")
    done
  else
    for p in "${SK_PATHS[@]}"; do
      local effective_src="$src/$p"
      if [ "$OFFLINE" = "1" ] && [ "$p" = "." ]; then effective_src="$src"; fi
      # if offline and p != "." the mirrored dir is already flat at src
      if [ "$OFFLINE" = "1" ] && [ "$p" != "." ]; then effective_src="$src"; fi
      targets+=("$dir/$name:$effective_src")
    done
  fi

  for pair in "${targets[@]}"; do
    local dst="${pair%%:*}"
    local from="${pair#*:}"
    if [ "$DRY_RUN" = "1" ]; then
      info "would install $name -> $dst (from $from)"
      continue
    fi
    if [ -d "$dst" ] && [ "$FORCE" -ne 1 ]; then
      if [ "$NON_INTERACTIVE" -eq 1 ] || [ ! -t 0 ]; then
        warn "$dst exists; keeping (pass --force to overwrite)"; continue
      fi
      printf '%s[skills]%s %s exists. Overwrite? [y/N] ' "$C_YELLOW" "$C_RESET" "$dst"
      read -r ans </dev/tty || ans="n"
      case "$ans" in y|Y|yes|YES) ;; *) info "skipped $dst"; continue ;; esac
    fi
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    cp -R "$from" "$dst"
    ok "installed $name -> $dst"
    record_manifest "$dir" "$name" "$dst"
  done
}

record_manifest() {
  # $1=agent_dir $2=skill_name $3=installed_path
  local dir="$1" name="$2" path="$3"
  local file="$dir/.skills-installer.json"
  mkdir -p "$dir"
  py - "$file" "$name" "$path" "$REF" <<'PY'
import json, os, sys, time
path, name, installed, ref = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = {"version": 1, "installer": "skills-installer", "ref": ref, "entries": []}
if os.path.exists(path):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except Exception:
        pass
entries = [e for e in data.get("entries", []) if not (e["name"] == name and e["path"] == installed)]
entries.append({"name": name, "path": installed, "ts": int(time.time()), "ref": ref})
data["entries"] = entries
data["ref"] = ref
open(path, "w", encoding="utf-8").write(json.dumps(data, indent=2))
PY
}

# ---------- actions ----------------------------------------------------------
do_list() {
  step "Planned installation"
  printf '%s\n' "$C_DIM  registry: $BASE_URL/registry.json$C_RESET"
  local agents skills
  agents="$(selected_agents)"
  skills="$(selected_names)"
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    local d; d="$(agent_dir "$a" "$SCOPE")"
    printf '  %s%s%s  (%s scope)\n' "$C_BOLD" "$a" "$C_RESET" "$SCOPE"
    printf '    -> %s\n' "$d"
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      printf '       - %s\n' "$s"
    done <<< "$skills"
  done <<< "$agents"
}

do_install() {
  local agents skills
  agents="$(selected_agents)"
  if [ -z "$agents" ]; then
    err "no target agent (neither detected nor specified)"; exit 3
  fi
  skills="$(selected_names)"

  step "Installing skills"
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    step "Agent: $a ($SCOPE)"
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      install_one "$a" "$s" || warn "failed to install $s for $a"
    done <<< "$skills"
  done <<< "$agents"

  if [ "$DRY_RUN" -eq 1 ]; then
    info "(dry-run: no files were written)"
  fi
  ok "done"
}

do_uninstall() {
  local agents skills
  agents="$(selected_agents)"
  skills="$(selected_names)"
  step "Uninstalling skills"
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    local dir; dir="$(agent_dir "$a" "$SCOPE")"
    local manifest="$dir/.skills-installer.json"
    if [ ! -f "$manifest" ]; then
      warn "no manifest at $manifest; skipping $a"; continue
    fi
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      # find matching entries and remove their 'path'
      py - "$manifest" "$s" "$DRY_RUN" <<'PY'
import json, os, shutil, sys
mf, name, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
data = json.load(open(mf, encoding="utf-8"))
keep, removed = [], []
for e in data.get("entries", []):
    if e["name"] == name:
        removed.append(e["path"])
    else:
        keep.append(e)
for p in removed:
    if os.path.exists(p):
        if dry:
            print(f"would remove {p}")
        else:
            shutil.rmtree(p, ignore_errors=True)
            print(f"removed {p}")
data["entries"] = keep
if not dry:
    open(mf, "w", encoding="utf-8").write(json.dumps(data, indent=2))
PY
    done <<< "$skills"

    # Prune empty dirs (deepest first) left under the agent skills dir.
    if [ "$DRY_RUN" = "0" ] && [ -d "$dir" ]; then
      find "$dir" -mindepth 1 -depth -type d -empty -exec rmdir {} + 2>/dev/null || true
    fi
  done <<< "$agents"
  ok "done"
}

# ---------- interactive TUI (only when no selection flags passed) ------------
maybe_prompt_selection() {
  [ -t 0 ] && [ -t 1 ] || return 0
  [ "$AGENT" = "all" ] && [ "$SCOPE" = "global" ] && [ "$SKILLS_SEL" = "all" ] || return 0

  banner
  local detected; detected="$(detect_agents)"
  if [ -z "$detected" ]; then
    warn "no agent detected in \$HOME"
    detected="cursor claude codex windsurf"
  fi
  printf '%sDetected agents:%s %s\n\n' "$C_BOLD" "$C_RESET" "$(echo "$detected" | tr '\n' ' ')"
  printf 'Install to which agent? [%sall%s/cursor/claude/codex/windsurf] ' "$C_BOLD" "$C_RESET"
  read -r a </dev/tty || a="all"
  [ -n "$a" ] && AGENT="$a"
  printf 'Scope? [%sglobal%s/project] ' "$C_BOLD" "$C_RESET"
  read -r sc </dev/tty || sc="global"
  [ -n "$sc" ] && SCOPE="$sc"
  printf 'Skills? [%sall%s or comma-separated list] ' "$C_BOLD" "$C_RESET"
  read -r sk </dev/tty || sk="all"
  [ -n "$sk" ] && SKILLS_SEL="$sk"
}

main() {
  parse_args "$@"
  check_deps
  maybe_prompt_selection
  fetch_registry

  case "$ACTION" in
    list)      do_list ;;
    install)   do_install ;;
    uninstall) do_uninstall ;;
    *)         err "unknown action: $ACTION"; exit 2 ;;
  esac
}

main "$@"
