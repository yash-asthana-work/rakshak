# Phase 4 — Sandbox & Isolation

The containment layer: when the agent (or attacker-via-agent) does something it shouldn't, what stops the damage from spreading? This is where homegrown "sandboxes" are usually weakest, because they're built by app teams, not security teams. Maps to OWASP LLM05/LLM06 downstream impact and infra security generally.

## Mental model
A sandbox's job is to make a *correctly-functioning but compromised* agent harmless by limiting reach. Two questions decide everything:
- **Can it get out?** (escape: from the execution context to the host/network)
- **What can it reach if it doesn't even need to get out?** (the sandbox is "secure" but has prod creds and prod network — escape is irrelevant).
The second is the more common real-world failure. Audit both, prioritize the second.

## Execution isolation checks
- What runs the code/tools: bare process, container, gVisor/Firecracker microVM, serverless? (Plain Docker is a soft boundary, not a security one for hostile code.)
- Does the container run as root? privileged? with the Docker socket mounted? (Docker socket mounted = trivial host takeover.)
- Are host paths bind-mounted in? Are they writable? (Mounted source/secret volumes defeat isolation.)
- Resource limits (CPU/mem/PIDs/disk) to prevent DoS and runaway loops?
- Is the execution environment ephemeral (reset per run) or persistent (allows planted persistence)?

## Network isolation checks (usually the highest-value section)
- **Default egress**: deny-all with an allowlist, or open? (Open egress = the agent can reach anything, incl. cloud metadata endpoints, internal services, attacker servers.)
- Can it reach **cloud metadata** (169.254.169.254 / IMDS)? That's instant credential theft on cloud hosts — check explicitly.
- Can it reach **internal services / private IP ranges** (SSRF into the corp network)?
- Is DNS for internal names resolvable from inside the sandbox?
- Is there an egress proxy that logs and filters? (Like the allowlisted-domains model used by hardened agent runtimes — note its presence/absence.)

## Filesystem isolation checks
- Working dir scoped and separate from system/user files?
- Read-only mounts for anything the agent shouldn't modify?
- Can it read other users'/tenants' files, secrets dirs, SSH keys, cloud cred files (~/.aws, etc.)?

## Privilege & escape surface
- Capabilities dropped? seccomp/AppArmor/SELinux profile applied?
- Kernel/runtime patched? (escape exploits target old runtimes)
- For shell/exec tools: is the command space constrained (allowlist) or arbitrary?

## Human-in-the-loop & kill switch
- Is there a confirmation gate for actions that cross the sandbox boundary (network send, file write outside scope, infra change)?
- Is there a way to halt a running agent / revoke its credentials immediately?
- Is agent activity observable in real time (audit log of every tool call + result)? Without this, incident response is blind.

## Supply-chain isolation
- MCP servers and third-party tools: are they trusted? pinned? could a malicious/updated one inject or exfiltrate? (A connected MCP server is effectively code running with the agent's trust — treat each as a dependency.)
- Are tool/package versions pinned and integrity-checked?

## Top-5 fast checks (triage mode)
1. Open/unrestricted network egress from the execution env? → High/Critical.
2. Reachable cloud metadata endpoint? → Critical (cred theft).
3. Docker socket or host paths mounted, or running privileged/root? → Critical.
4. No audit log of tool calls? → systemic High (blind to incidents).
5. No kill switch / credential revocation path? → High.

## Severity guidance
- Reachable IMDS / metadata cred theft, or host takeover (docker socket, privileged) = **Critical**.
- Open egress enabling exfil/SSRF = High/Critical (combine with Phase 3).
- No audit logging = High (amplifies every other finding by removing detection).
- Persistent env allowing planted persistence = Medium–High.
- Untrusted/unpinned MCP/supply chain = High.

Note: the strongest real-world posture combines deny-all egress + ephemeral FS + non-root + no host mounts + full audit log + HITL on boundary-crossing actions. Score gaps against that target.
