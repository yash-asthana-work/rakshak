---
name: agentic-security-audit
description: Run a comprehensive, structured security vulnerability assessment of an agentic AI tool, agent, or LLM-powered workflow that the user OWNS or is authorized to test. Use this whenever the user wants to audit, pentest, threat-model, or harden an AI agent, an LLM application, a Claude Code workflow, an n8n/LangChain/custom agent, an MCP integration, or any system where an LLM calls tools or reads untrusted data. Trigger on phrases like "security audit", "is this agent safe", "prompt injection test", "check tool permissions", "data exfiltration risk", "sandbox escape", "review my agent for vulnerabilities", or "AI red team", even if the user does not name a specific framework. This skill encodes expert methodology so the assessment is rigorous regardless of which model executes it.
---

# Agentic Security Audit

## What this skill is for

You are auditing an **agentic system** — an LLM that reads inputs, makes decisions, and acts through tools (file I/O, shell, HTTP, email, DB, MCP servers, APIs). The model's own safety training does NOT cover the operational risks of *what the agent can touch and do*. This skill audits that gap.

**Core thesis you must keep in mind throughout:** the dangerous failure is almost never "the model turns evil." It is a *correctly-functioning* model being driven by **untrusted input** (prompt injection) while holding **excessive permissions** and an **outbound channel** — the "lethal trifecta." Most findings will be combinations, not single flaws. Always reason about chains, not isolated checks.

## Authorization gate (do this first, every time)

Before producing any active test payloads, confirm in one line that the target is owned by or authorized for the user. If the system under audit appears to belong to a third party with no stated authorization, run only the **passive** phases (threat model, design review, static checks) and explicitly decline to generate active attack payloads. This is non-negotiable and protects both the user and you.

## How to run an audit (the loop)

Work through SEVEN phases in order. Each has a dedicated reference file with the full checklist, taxonomy, and severity rubric — **read the reference file at the start of each phase**; do not work from memory, because the value of this skill is that the expertise lives in those files.

| # | Phase | Reference file | Output |
|---|-------|----------------|--------|
| 0 | Scope & threat model | `references/01-threat-model.md` | Asset/trust-boundary map, attack surface inventory |
| 1 | Prompt injection (direct + indirect) | `references/02-prompt-injection.md` | Injection findings per untrusted channel |
| 2 | Tool & permission audit | `references/03-tool-permissions.md` | Per-tool blast-radius + least-privilege gaps |
| 3 | Data privacy & egress | `references/04-data-privacy-egress.md` | PII flows, exfiltration paths, log leaks |
| 4 | Sandbox & isolation | `references/05-sandbox-isolation.md` | Execution/network/FS isolation findings |
| 5 | Active red-team (authorized only) | `references/06-active-redteam.md` | Executed probes + pass/fail evidence |
| 6 | Score & report | `references/07-scoring-and-report.md` | Risk-scored report (exec + technical) |

Phases 0–4 are **passive** (review/static — safe on any system you may read). Phase 5 is **active** and requires the authorization gate to pass. Phase 6 always runs last.

### Adapting depth
- **Quick triage** (≤30 min): Phase 0, then the "Top-5 fast checks" box in each of phases 1–4, then Phase 6 with a one-page report.
- **Full audit**: every phase, every checklist item, active probes for everything in scope.
- Always state up front which mode you are running so the user knows the coverage.

## Evidence discipline (this is what makes a junior model produce senior output)

For **every** finding, you MUST record all five fields. A finding without evidence is a guess and must be downgraded to "needs verification."

1. **Finding** — one sentence, what is wrong.
2. **Evidence** — the exact config line, code snippet, tool definition, or probe response that proves it. Quote it. No evidence → not a finding.
3. **Attack chain** — the concrete sequence an attacker would use. "An attacker who controls X can do Y to achieve Z."
4. **Mapping** — OWASP LLM Top-10 ID and/or OWASP Agentic threat ID and/or MITRE ATLAS technique (the reference files give you the catalog).
5. **Severity** — computed via the rubric in `references/07`, never eyeballed.

Never invent a finding to fill a category. If a phase yields nothing, write "No findings; checks performed: [list]." Empty-with-evidence is a valid and valuable result.

## Helper scripts

- `scripts/injection_corpus.py` — emits a categorized corpus of **benign** prompt-injection *probe* strings (canary-token style; they instruct the agent to do something harmless-but-observable like emit a marker) for testing YOUR OWN agent's susceptibility. Run: `python scripts/injection_corpus.py --list` or `--category indirect`. These are detectors, not weapons.
- `scripts/score.py` — takes a findings JSON and computes per-finding and aggregate risk scores using the rubric. Run: `python scripts/score.py findings.json`. Keeps severity objective and reproducible.

## Output contract

The final deliverable (Phase 6) ALWAYS has this exact top-level structure:

```
# Security Assessment: <system name>
## Executive summary            (≤200 words, non-technical, risk posture + top 3 risks + go/no-go)
## Risk register                (table: ID | finding | severity | OWASP/ATLAS | status)
## Findings                     (one block per finding, all 5 evidence fields)
## Lethal-trifecta analysis     (does this system combine untrusted input + privilege + egress? where?)
## Remediation roadmap          (prioritized: quick wins → structural fixes, with effort estimate)
## Scope & methodology          (what was and was NOT tested — be honest about coverage)
```

The executive summary is for leadership; write it so a non-technical director understands the business risk in 60 seconds. The findings are for engineers; be precise.

## What this skill deliberately does NOT do

- It does not write weaponized exploits or malware. Probes are benign and observable.
- It does not test third-party systems without authorization.
- It does not claim prompt injection is "solved" — no one has solved it. The honest posture is *detection, containment, and least privilege*, and the report must say so.
- It does not replace a formal pentest engagement for regulated/production systems; it complements one and surfaces the AI-specific layer those often miss.
