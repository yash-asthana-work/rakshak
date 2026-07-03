# Phase 0 — Scope & Threat Model

Goal: before hunting for bugs, build a map. You cannot find what you cannot see. This phase produces the inventory that every later phase references.

## Step 1 — Enumerate the system

Produce a table of every component:

| Component type | What to capture |
|---|---|
| LLM calls | model(s), provider, system prompt source, who can edit it |
| Tools | name, what it does, read vs write, scope of access, auth used |
| Input channels | where text/data enters the agent (user, files, web, email, DB, API, MCP) |
| Output/action channels | where the agent can cause effects (FS, shell, HTTP, send, payment, DB write) |
| Data stores | what data the agent can read; classify sensitivity (public / internal / PII / secret) |
| Identities & creds | service accounts, API keys, OAuth tokens, DB users the agent runs as |
| Execution env | local process / container / VM / serverless; network posture |

If you have the code/config, extract these from it and **quote the source**. If you only have a description, mark each row "asserted, unverified."

## Step 2 — Classify every input channel by trust

This is the single most important classification in the whole audit.

- **Trusted**: authenticated operator typing directly.
- **Semi-trusted**: internal documents, internal DB rows — could be poisoned by an insider or a prior compromise.
- **Untrusted**: anything an external party can influence — incoming email, web pages fetched, uploaded files, third-party API responses, MCP tool results, RAG documents, code in a PR, calendar invites, ticket text.

Rule of thumb: **if content was authored by someone other than the human currently operating the agent, treat it as untrusted.** Untrusted channels are the injection surface for Phase 1.

## Step 3 — Map trust boundaries & data flows

Draw (in text or as a simple diagram) the path: input channel → LLM → tool → effect. Mark each arrow where data crosses from a lower trust level to a higher-privilege action. Those crossings are where attacks live.

## Step 4 — Identify the lethal trifecta exposure

Answer explicitly, yes/no with evidence:

- **A. Untrusted input** — can the agent ingest attacker-influenced content? (almost always yes for useful agents)
- **B. Access to sensitive data or privileged actions** — can it read secrets/PII or perform irreversible/high-impact actions?
- **C. An outbound channel** — can it send data out? (HTTP, email, webhook, DB write to a readable table, even URLs in logs or error messages, even tool parameters that get transmitted)

**If A + B + C are all present and not mitigated, this is a critical structural finding on its own**, independent of any specific bug, because it means a single successful injection can exfiltrate or act. Record it as such and carry it into Phase 6's lethal-trifecta analysis.

## Step 5 — Define attacker profiles

For scoring later, name the relevant attackers:
- External, no access (can only influence untrusted content the agent reads).
- Authenticated low-priv user of the product.
- Malicious insider.
- Compromised dependency / supply chain (a poisoned MCP server, a malicious npm package, a tampered RAG source).

A finding's severity depends on which attacker can reach it. An injection reachable by an anonymous external party is far worse than one needing insider access.

## Output of this phase

- Component inventory table (with sources quoted).
- Trust classification of every input channel.
- Data-flow / trust-boundary map.
- Lethal-trifecta yes/no/where.
- Attacker profile list.

Carry all of this forward; later phases reference these IDs.
