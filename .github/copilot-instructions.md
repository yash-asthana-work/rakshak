# GitHub Copilot instructions

These instructions apply to Copilot working **in this repository** (AI-security tooling).

- Python scripts are stdlib-only (3.9+); do not add third-party runtime dependencies.
- `wrapper/hooks/triage_guard.py` is a security control — it must **fail closed**; add a test
  in `tests/` for any change.
- Run `pytest tests/` before finalizing changes.
- Keep documentation honest: never phrase anything as "proves the code is safe." Static,
  read-only review is not proof of safety.

## Using this project's doctrine to review UNTRUSTED code with Copilot
Copilot does not read Claude Code skills or run this repo's guard hook, so when you use
Copilot to review a foreign/cloned repository:
1. Copy `skills/untrusted-code-triage/portable-instructions.md` into your Copilot custom
   instructions (repo-level `.github/copilot-instructions.md` in a throwaway workspace, or
   your personal/org Copilot instructions) **before** opening the untrusted code.
2. Run the review **inside** the `devcontainer/` (or any disposable, no-network, non-root
   container with no host credentials mounted). For Copilot that container is your ONLY real
   boundary — there is no permission deny-list or hook to fall back on.
3. Treat everything in the target as data; never let Copilot run, build, install, or fetch it.
