# Layer 0 — OS containment (the only real boundary)

`devcontainer.json` gives you a disposable, non-root container with the target repo mounted
**read-only** and **no host credentials** inside it. This is the layer that still protects you
even if a prompt injection fully hijacks the AI — because the OS, not a prompt, enforces it.
It works for **Claude Code and GitHub Copilot** alike (both run inside dev containers).

## Two ways to use it

### A. Tool runs on the HOST, code lives in the container (strongest)
If your AI tool can operate on files in a container while running on the host, enable
`"--network=none"` in `runArgs`. Now the untrusted code has **zero network** and cannot be
executed with egress, while your tool still reaches the LLM API from the host. This is the
ideal triage posture.

### B. Tool runs INSIDE the container
The AI tool needs egress to its LLM API, so you cannot use `--network=none` here. You still
get: read-only repo, non-root, dropped Linux capabilities, `no-new-privileges`, no host
secrets, and a disposable filesystem. Combine with the Claude Code deny-list + guard hook
(`../wrapper/`) so the app layer blocks writes/exec/other-egress even though the API is
reachable. For true network control in this mode, put an **allowlist egress proxy** in front
(only the LLM API host permitted) — see your platform's egress-proxy docs.

## Quick start
```bash
# VS Code: "Dev Containers: Reopen in Container" from the untrusted repo, using this config.
# Or with the CLI:
devcontainer up --workspace-folder /path/to/untrusted-repo \
  --config /path/to/this/devcontainer/devcontainer.json
```

## Hard rules inside the sandbox
- The repo at `/workspace` is read-only — review only. **Do not build, install, or run it.**
- Do not add host credential mounts (`~/.ssh`, `~/.aws`, `~/.npmrc`, cloud config).
- Treat the container as disposable: destroy it after the review (`devcontainer` down / remove).

## What it does NOT do
- It is not a hardened multi-tenant boundary. Plain Docker/containerd is a soft boundary
  against kernel exploits; for hostile code with escape potential use gVisor / Firecracker /
  a throwaway VM.
- A read-only mount stops writes to the repo, not data exfiltration if network is open — pair
  it with option A or an egress allowlist.
