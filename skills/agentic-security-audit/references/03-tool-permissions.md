# Phase 2 — Tool & Permission Audit

Injection is the trigger; **excessive permissions are the blast radius.** This phase quantifies how much damage a successful injection or a model error can do. Maps to OWASP LLM06 (Excessive Agency) and the OWASP Agentic threats around tool misuse and privilege compromise.

## For EVERY tool the agent can call, fill this row

| Field | Question |
|---|---|
| Tool | name |
| Capability | what it can do (read/write/execute/send/pay/delete) |
| Scope | how broad — one record? whole table? whole filesystem? arbitrary shell? |
| Identity | what credential/account does it run as; what can that account do *outside* the intended use |
| Reversibility | can its effects be undone? (irreversible = higher severity) |
| Trigger path | can untrusted content (Phase 0) cause this tool to fire? |
| Gate | is there a human approval / policy check before it fires? |
| Rate/quota limit | can it be called in a runaway loop? |

## The three excessive-agency dimensions (check each)
1. **Excessive functionality** — the agent has tools it doesn't need for its job (e.g., a summarizer agent with shell access). Every unused capability is pure attack surface.
2. **Excessive permissions** — a tool's credential grants more than the tool needs (e.g., read-only task given a read-write DB user; an API key with admin scope). Classic: "we used the service account because it was already set up."
3. **Excessive autonomy** — the agent can take high-impact/irreversible actions with no human confirmation (send external email, delete data, move money, push code, modify infra).

## Least-privilege analysis (the core deliverable)
For each tool, state the **minimum** capability/scope/credential it would need, then the delta vs. what it actually has. The delta IS the finding. Example format:

> Tool `query_db`: needs SELECT on 3 views. Actually runs as `app_rw` (full DDL+DML on all schemas). Delta: write + drop on entire DB. An injection that reaches this tool can destroy data. → Excessive permissions, High.

## Credential hygiene checks
- Keys/tokens hardcoded in config, env files, workflow JSON (n8n!), or the prompt itself?
- Long-lived vs. short-lived/rotating credentials?
- One shared credential across many agents/tools (no blast-radius isolation)?
- Secrets ever placed into model context where a prompt-leak would expose them?
- Are credentials scoped per-agent and per-environment (dev vs prod separation)?

## Composition / chaining risk
The dangerous combinations are emergent. Explicitly look for tool pairs that compose into an attack:
- read-sensitive + any-egress = exfiltration (this is the trifecta in tool form).
- read + write-to-shared-location = persistence / poisoning of future runs.
- execute + network = arbitrary remote action.
- a "safe" read tool whose output feeds a "safe" action tool, where the chain is unsafe.
List every such pair and whether anything breaks the chain.

## Confused-deputy / authorization checks
- Does the agent act with ITS privileges or the END USER's? If the agent has broad rights and any user can drive it, low-priv users can reach high-priv actions through the agent.
- Is per-user authorization enforced *inside* each tool, or does the agent assume "if I can call it, it's allowed"?
- Can user A's request cause the agent to touch user B's data (multi-tenant leakage)?

## Top-5 fast checks (triage mode)
1. Does the agent have shell/exec or arbitrary HTTP it doesn't strictly need? → High.
2. Any write/delete/send/pay tool with no human gate, reachable from untrusted input? → Critical.
3. Are tool credentials over-scoped vs. need? → High.
4. Are secrets in plaintext config/env/prompt? → High.
5. Does the agent act with its own broad identity rather than the user's? → High (confused deputy).

## Severity guidance
- Irreversible/high-impact tool + untrusted trigger + no gate = **Critical**.
- Over-scoped credential reachable by injection = High.
- Unused dangerous capability (present but not currently reachable) = Medium (latent).
- Missing rate limits enabling runaway loops/cost = Medium.
