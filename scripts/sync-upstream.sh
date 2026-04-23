#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Maintainer script: refresh skills/ offline mirror from upstream repos.
#
# Runs once before each release:
#   ./scripts/sync-upstream.sh              # updates every mirrored skill
#   ./scripts/sync-upstream.sh superpowers  # updates only the named skill
#
# Only skills with "redistributable": true in registry.json are mirrored.
# Source-available upstreams (anthropics/*) are skipped on purpose.
# -----------------------------------------------------------------------------

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REG="$ROOT/registry.json"
MIRROR_DIR="$ROOT/skills"

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

FILTER="${1:-}"

py() { python3 "$@"; }

# Emit one line per redistributable skill: name|upstream|branch|path1 path2...
py - "$REG" "$FILTER" <<'PY'
import json, sys
reg = json.load(open(sys.argv[1], encoding="utf-8"))
flt = sys.argv[2]
for s in reg["skills"]:
    if not s.get("redistributable", True): continue
    if flt and s["name"] != flt: continue
    print("|".join([
        s["name"],
        s["upstream"],
        s.get("branch", "main"),
        " ".join(s["paths"]),
        "1" if s.get("flatten", False) else "0",
    ]))
PY
} > /tmp/skills-sync.list

if [ ! -s /tmp/skills-sync.list ]; then
  echo "nothing to sync (check registry.json and filter '$FILTER')"
  exit 0
fi

while IFS='|' read -r name upstream branch paths flatten; do
  echo
  echo "=== $name  <-  $upstream ($branch)"
  work="$(mktemp -d)"
  git clone --depth 1 --filter=blob:none --sparse --branch "$branch" "$upstream" "$work" >/dev/null 2>&1
  # shellcheck disable=SC2086
  ( cd "$work" && git sparse-checkout set $paths >/dev/null 2>&1 )

  dst="$MIRROR_DIR/$name"
  rm -rf "$dst"
  mkdir -p "$dst"

  # Copy content according to paths + flatten flag
  set -- $paths
  first_path="$1"

  if [ "$flatten" = "1" ]; then
    # Flatten: take every immediate subdir of the single path into $dst/
    src_root="$work/$first_path"
    [ "$first_path" = "." ] && src_root="$work"
    for sub in "$src_root"/*/; do
      [ -d "$sub" ] || continue
      cp -R "$sub" "$dst/"
    done
  elif [ "$first_path" = "." ]; then
    # Copy entire repo (minus .git/)
    ( cd "$work" && tar --exclude-vcs -cf - . ) | ( cd "$dst" && tar -xf - )
  elif [ "$#" -eq 1 ]; then
    # Single path: copy its contents flat into $dst
    cp -R "$work/$first_path/." "$dst/"
  else
    # Multiple paths: copy each as a subdir named by basename
    for p in "$@"; do
      base="$(basename "$p")"
      cp -R "$work/$p" "$dst/$base"
    done
  fi

  # Strip caches and OS junk that upstreams sometimes commit by accident.
  find "$dst" -type d \( -name "__pycache__" -o -name ".pytest_cache" -o -name ".mypy_cache" -o -name ".ruff_cache" \) -prune -exec rm -rf {} + 2>/dev/null || true
  find "$dst" -type f \( -name "*.pyc" -o -name ".DS_Store" -o -name "Thumbs.db" \) -delete 2>/dev/null || true

  # Write mirror metadata so we can check provenance at any time
  head_sha="$(git -C "$work" rev-parse HEAD)"
  cat > "$dst/.mirror.json" <<META
{
  "name": "$name",
  "upstream": "$upstream",
  "branch": "$branch",
  "head_sha": "$head_sha",
  "synced_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
META
  rm -rf "$work"
  echo "  -> $dst   (sha $head_sha)"
done < /tmp/skills-sync.list

echo
echo "done. Review changes, then commit:"
echo "  git add skills/ && git commit -m 'chore: sync upstream skill mirror'"
