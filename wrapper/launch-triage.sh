#!/usr/bin/env bash
# launch-triage.sh — macOS/Linux counterpart of launch-triage.ps1.
# Stages an untrusted repo into a disposable read-only workspace and launches Claude Code
# in quarantine mode (enforcement layers 1-2). Layer 0 (OS/network sandbox) is the real
# boundary — for anything you truly distrust, run this INSIDE devcontainer/ or a container
# with `--network none`, no host credentials mounted, and the repo on a read-only mount.
#
# Usage:
#   ./launch-triage.sh <path-or-git-url> [--mode strict|hardened] [--scan]
set -euo pipefail

SOURCE="${1:-}"; shift || true
MODE="strict"; SCAN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-strict}"; shift 2 ;;
    --scan) SCAN=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -z "$SOURCE" ]] && { echo "usage: $0 <path-or-git-url> [--mode strict|hardened] [--scan]" >&2; exit 2; }
[[ "$MODE" != "strict" && "$MODE" != "hardened" ]] && { echo "mode must be strict|hardened" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
GUARD="$HERE/hooks/triage_guard.py"
TEMPLATE="$HERE/settings.quarantine.json"
SCANNER="$REPO/skills/untrusted-code-triage/scripts/scan_untrusted.py"

STAMP="$(date +%Y%m%d-%H%M%S)"
WORKSPACE="${TMPDIR:-/tmp}/triage/$STAMP"
TARGET="$WORKSPACE/target"
mkdir -p "$TARGET"
echo "[triage] workspace: $WORKSPACE"

# Stage the source (neither path copies nor shallow clone executes the code).
if [[ "$SOURCE" =~ ^(https?|git|ssh):// || "$SOURCE" == *.git ]]; then
  echo "[triage] shallow-cloning (no repo hooks run on clone): $SOURCE"
  git clone --depth 1 --no-tags "$SOURCE" "$TARGET"
  rm -rf "$TARGET/.git/hooks"
else
  [[ -d "$SOURCE" ]] || { echo "source not found: $SOURCE" >&2; exit 2; }
  echo "[triage] copying local source (read-only, no execution)..."
  cp -R "$SOURCE"/. "$TARGET"/
fi

# Read-only (defense-in-depth; the deny-list is the real app control).
chmod -R a-w "$TARGET" 2>/dev/null || true

# Materialize per-run settings.json with the guard's absolute path.
AUDIT_LOG="$WORKSPACE/audit.log"
RUN_SETTINGS="$WORKSPACE/settings.json"
sed "s#REPLACE_WITH_ABSOLUTE_PATH/triage_guard.py#$GUARD#g" "$TEMPLATE" > "$RUN_SETTINGS"

if [[ "$MODE" == "hardened" ]]; then
  python3 - "$RUN_SETTINGS" <<'PY'
import json, sys
p = sys.argv[1]
cfg = json.load(open(p))
cfg["permissions"]["deny"] = ["Write", "Edit", "MultiEdit", "NotebookEdit"]
cfg["permissions"]["defaultMode"] = "default"
json.dump(cfg, open(p, "w"), indent=2)
PY
fi

export TRIAGE_MODE="$MODE" TRIAGE_TARGET="$TARGET" TRIAGE_AUDIT_LOG="$AUDIT_LOG"
echo "[triage] mode=$MODE  target=$TARGET"
echo "[triage] audit log: $AUDIT_LOG"

if [[ "$SCAN" == "1" ]]; then
  echo "[triage] running static scanner..."
  python3 "$SCANNER" "$TARGET" || true
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "[triage] 'claude' CLI not on PATH. Staging done; launch manually:"
  echo "    cd \"$WORKSPACE\" && claude --settings \"$RUN_SETTINGS\""
  exit 0
fi

cd "$WORKSPACE"
echo "[triage] launching Claude Code (quarantine). Ask it: run untrusted-code-triage on ./target"
claude --settings "$RUN_SETTINGS" || true
echo "[triage] session ended. Audit trail: $AUDIT_LOG"
echo "[triage] discard everything with: rm -rf \"$WORKSPACE\""
