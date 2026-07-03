# Phase 6 — Scoring & Report

Turns findings into objective, comparable severities and a deliverable leadership can act on. The scoring rubric is what stops a junior model (or a tired senior) from rating things by gut.

## Scoring rubric (compute, don't guess)
Score each finding on four axes, 1–5, then combine. `scripts/score.py` does this automatically from a findings JSON; use it for consistency.

| Axis | 1 | 3 | 5 |
|---|---|---|---|
| **Impact** | cosmetic / benign output change | data read or limited write | secret/PII exfil, irreversible action, host/cred compromise |
| **Reachability** | needs insider + complex setup | authenticated user | anonymous external via untrusted content |
| **Exploit ease** | theoretical / multi-step uncertain | known technique, some effort | single injection, copy-paste |
| **Detection/recovery** | logged + reversible + alerted | partially logged or reversible | silent + irreversible (no audit log) |

**Composite severity:**
- Any axis = 5 on Impact AND Reachability ≥ 4 → **Critical**, regardless of average.
- Average ≥ 4 → **Critical**.
- Average 3–3.9 → **High**.
- Average 2–2.9 → **Medium**.
- Average < 2 → **Low**.
- The lethal-trifecta structural finding (Phase 0) is **Critical by definition** if A+B+C present and unmitigated.

Always show the four sub-scores so the rating is auditable.

## Framework mapping (attach to every finding)
- **OWASP LLM Top 10**: LLM01 Prompt Injection · LLM02 Sensitive Info Disclosure · LLM03 Supply Chain · LLM04 Data/Model Poisoning · LLM05 Improper Output Handling · LLM06 Excessive Agency · LLM07 System Prompt Leakage · LLM08 Vector/Embedding Weaknesses · LLM09 Misinformation · LLM10 Unbounded Consumption.
- **OWASP Agentic threats** (use where relevant): Memory Poisoning · Tool Misuse · Privilege Compromise · Resource Overload · Cascading Hallucination · Intent Breaking · Identity Spoofing · Rogue Agents (multi-agent) · Human-in-the-loop Manipulation.
- **MITRE ATLAS**: map the tactic/technique where the finding matches a known ML attack pattern (recon, initial access via injection, exfiltration, etc.).
Mapping makes the report credible to security reviewers and lets the org track coverage against a standard.

## Remediation pattern library (cite the relevant fix per finding)
- Injection → trust separation / data-instruction segregation; injection-detection on inbound; structured tool schemas; **HITL gate on privileged actions downstream of untrusted input**; architectural patterns (dual-LLM, plan-then-execute with no untrusted-content in the privileged path).
- Excessive agency → remove unused tools; scope credentials to minimum; per-user authorization inside tools; rate limits.
- Data/egress → deny-all egress + allowlist; disable client rendering of model-produced images/links; output scanning/redaction; minimize data pulled into context; retention/residency controls; per-tenant isolation.
- Sandbox → microVM/gVisor; non-root, no host mounts, no docker socket; block metadata IP & private ranges; ephemeral FS; full audit log; kill switch + credential revocation.
- Supply chain → pin & verify tools/MCP servers; treat each connector as code; review before connecting.
Order remediations: **quick wins** (config flips: egress allowlist, drop a tool, scope a key, add a gate) before **structural** (re-architecting the trust flow).

## Required report structure (exact)
```
# Security Assessment: <system name>
**Date · Auditor · Scope mode (triage/full) · Authorization basis**

## Executive summary
≤200 words, non-technical. Overall risk posture (Critical/High/Medium/Low).
The top 3 risks in business terms. A clear go / no-go / go-with-conditions verdict.

## Risk register
| ID | Finding | Severity | Sub-scores (I/R/E/D) | OWASP/ATLAS | Status (confirmed/likely/needs-verify) |

## Findings
For each: Finding · Evidence (quoted) · Attack chain · Mapping · Severity (with sub-scores) · Remediation.

## Lethal-trifecta analysis
State A/B/C presence and exactly where they combine. This is usually the headline.

## Remediation roadmap
Prioritized table: action · addresses finding IDs · effort (S/M/L) · quick-win vs structural.

## Scope & methodology
What was tested, what was NOT, which phases ran, coverage honesty, residual unknowns.
```

## Honesty clauses (must appear)
- State coverage limits plainly; an audit that overclaims is worse than none.
- State that prompt injection has no complete fix today; the posture is detection + least privilege + containment.
- Distinguish **confirmed** (Phase 5 evidence) from **likely** (passive only) findings.

## Executive-summary tone
Write for a director who is not technical. Lead with risk and money/impact, not mechanism. "A malicious email could cause the assistant to send internal data to an outsider, with no record that it happened" beats "indirect prompt injection enabling exfiltration via unrestricted egress." Put the mechanism in the findings, the consequence in the summary.
