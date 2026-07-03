# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

An AI-security toolkit: two Claude Code skills plus a containment wrapper. It lets an AI
inspect **untrusted, foreign code** without acting on injected instructions inside it, and
lets you audit AI agents you own. Read `README.md` for the full picture and `AGENTS.md` for
the cross-tool operating conventions.

## Commands

```bash
pip install pytest && python -m pytest tests/ -q      # full suite (10 tests)
python -m pytest tests/test_triage.py::test_guard_fails_closed_on_garbage_input -q   # single test
python skills/untrusted-code-triage/scripts/scan_untrusted.py <dir>          # run scanner
python skills/untrusted-code-triage/scripts/scan_untrusted.py <dir> --json   # scanner, machine-readable
python -m compileall -q skills wrapper tests          # byte-compile check (CI does this)
```
There is no build step — Python is stdlib-only (3.9+), no third-party runtime deps. CI is
`.github/workflows/ci.yml` (tests on Linux/macOS/Windows + a scanner self-test).

## Architecture — the defense-in-depth model

The whole design rests on one premise: **an LLM cannot distinguish operator instructions from
text it reads in a file, so a prompt can never be a security boundary.** Protection therefore
comes in four layers, and you must keep straight which are real boundaries:

- **Layer 0 (`devcontainer/`)** — OS containment (read-only mount, no network, no host creds). The only layer that survives a full injection compromise.
- **Layer 1 (`wrapper/settings.quarantine.json`)** — Claude Code `permissions.deny` list.
- **Layer 2 (`wrapper/hooks/triage_guard.py`)** — a `PreToolUse` hook enforcing read-only + audit logging.
- **Layer 3 (`skills/`)** — the prompt-level doctrine. Defense-in-depth ONLY, never a boundary.

When editing, never let a change blur these lines or imply the skill/prompt is a boundary.

## How the pieces connect

- `wrapper/launch-triage.{ps1,sh}` stages an untrusted repo into a disposable read-only
  workspace, fills the guard's absolute path into a per-run `settings.json`, sets the
  `TRIAGE_MODE` / `TRIAGE_TARGET` / `TRIAGE_AUDIT_LOG` env vars the guard reads, and launches
  `claude --settings`. The launcher locates the scanner at
  `skills/untrusted-code-triage/scripts/scan_untrusted.py` — if you move files, fix that path.
- The guard hook reads a tool call as JSON on stdin and returns a `permissionDecision`
  (allow/deny/ask). `strict` mode = read-only only; `hardened` = post-clearance, still blocks
  writes-into-target and download-and-exec.
- Skills are self-contained (`SKILL.md` + `references/` + `scripts/`) so they can be copied to
  `~/.claude/skills/` by `install.{ps1,sh}`. `SKILL.md` references files with paths relative to
  the skill dir (`references/…`, `scripts/…`) — keep them relative, not `../`.

## Invariants you must preserve

- **The guard hook fails closed.** Any unparseable/unexpected input must deny (strict) or ask
  (hardened) — never fall through to allow. Every decision path needs a test in
  `tests/test_triage.py`.
- **Scanner executes nothing.** It only opens files as data. Never add code that imports,
  runs, or evaluates scanned content. Adding a rule = add a `RULES` tuple AND a fixture line
  under `tests/fixtures/evil-repo/` so the regression test still asserts it is caught.
- **Honesty policy.** No doc or output may read as "proves the code is safe." Static,
  read-only review is not proof of safety — say so.

## Two skills, opposite directions

- `skills/untrusted-code-triage/` — defends the reviewer from foreign code (read-only, treat
  target as data). Its `portable-instructions.md` is the copy-paste version for GitHub Copilot
  and other tools that don't support Claude Code skills or the guard hook.
- `skills/agentic-security-audit/` — audits an agent you own (7 phases, OWASP LLM/Agentic +
  MITRE ATLAS mapping, `scripts/score.py` for objective severity, `scripts/injection_corpus.py`
  for benign canary probes). Its active red-team phase requires an authorization gate.
