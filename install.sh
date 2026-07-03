#!/usr/bin/env bash
# install.sh — install the two skills into your Claude Code skills directory (macOS/Linux).
# The enforcement wrapper (wrapper/) is deployed separately — see README "Rolling it out".
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$SKILLS_DIR"

for s in agentic-security-audit untrusted-code-triage; do
  rm -rf "${SKILLS_DIR:?}/$s"
  cp -R "$HERE/skills/$s" "$SKILLS_DIR/$s"
  echo "[install] skill: $s -> $SKILLS_DIR/$s"
done

echo
echo "[install] done. Next steps:"
echo "  1. Triage untrusted code:  $HERE/wrapper/launch-triage.sh <repo-or-url> --scan"
echo "  2. For true isolation, run inside $HERE/devcontainer/ (see its README)."
echo "  3. Org-wide enforcement: put wrapper/settings.quarantine.json's deny-list + hook"
echo "     into Claude Code managed-settings. See README 'Rolling it out'."
