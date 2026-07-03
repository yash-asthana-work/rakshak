# Contributing

Thanks for helping harden the AI security tooling. This repo ships two Claude Code skills
and a containment wrapper. Keep changes small, tested, and honest about limitations.

## Repo layout
See the "Repository layout" section of the [README](README.md). In short:
`skills/` holds the two skills; `wrapper/` holds the enforcement layer; `tests/` proves the
scanner and guard hook behave; `devcontainer/` is the OS-level sandbox.

## Adding a scanner rule
Edit `skills/untrusted-code-triage/scripts/scan_untrusted.py`:
- Add a `(category, severity, compiled_regex, note)` tuple to `RULES`.
- Add a matching fixture line under `tests/fixtures/evil-repo/` so the rule is covered.
- Run `pytest tests/` — the scanner test asserts every planted attack is still caught.

Rules are heuristic by design. Prefer precise patterns; a noisy rule that cries wolf gets
ignored, which is worse than no rule. Every rule must be justifiable as "this is why a human
should look," not "this is definitely malicious."

## Adding / editing a reference file
Reference files under each skill's `references/` are the actual expertise. Keep them dense
and cross-linked. If you add one, add a row to that skill's `SKILL.md` phase table so it is
discovered. Do not put security-critical instructions only in `SKILL.md` — the model reads
references per phase.

## Changing the guard hook
`wrapper/hooks/triage_guard.py` is a security control. Two non-negotiables:
1. It must **fail closed** — any unexpected input denies (strict) or asks (hardened).
2. Add a test in `tests/test_triage.py` for any new decision path.

## Before opening a PR
```bash
pytest tests/                                   # all green
python skills/untrusted-code-triage/scripts/scan_untrusted.py tests/fixtures/evil-repo
```
State clearly in the PR what threat the change addresses and what it does NOT cover.

## Honesty policy
This project's credibility rests on not overclaiming. Any doc or output that could read as
"this proves the code is safe" must be corrected to "no red flags found; static review is not
proof of safety." PRs that weaken that honesty will be asked to revise.
