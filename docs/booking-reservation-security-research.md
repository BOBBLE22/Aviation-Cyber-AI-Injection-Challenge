# GBX Air Booking & Reservation — Security Research & Realism Map

Grounding for the **hard track** (levels H1–H5), the way
[airport-parking-security-research.md](airport-parking-security-research.md) grounds the parking
track. Every hard-level mechanic maps to a real control it abuses and a named CVE / framework
technique (§7). If a level's mechanic isn't in that table, add a row with a source or change the
mechanic.

Scope choice: one department, gone deep. The parking track hops five sub-desks; the hard track
stays inside a single **airline booking & reservation** system (a GDS/PSS-style PNR store) and
drills the customer-facing attack surface a traveler actually touches — their own booking fields.

---

## 1. The real technology stack

**GDS / PSS.** Amadeus, Sabre, and Travelport handle the large majority of the world's flight
reservations. A booking is a **PNR (Passenger Name Record)** identified by a **6-character record
locator** (e.g. `8EI29V`) — uppercase alphanumeric, under ~28.5 bits of entropy, and in two of the
three majors **assigned sequentially**. The locator is printed on boarding passes and bag tags,
and legacy GDS auth was often just *surname + locator* (§6).

**PNR anatomy the challenge uses.** Mandatory elements are Name, Itinerary, Contact, Ticketing,
Received-From (Sabre mnemonic **PRINT**). The name field is `SURNAME/FIRSTNAME TITLE`. Every
element carries a numeric *tattoo* used to associate passengers ↔ segments ↔ SSRs ↔ ticket
coupons. Ticket **coupon status** is a small state machine (`O`pen → `C`heckedin → `L`ifted →
`F`lown, or → `E`xchanged / `R`efunded / `V`oid).

**APIS / Secure Flight.** Under 49 CFR Part 1560, carriers collect full name, date of birth, and
gender (required) plus **Redress Number** and **Known Traveler Number** (if available), carried in
`SSR DOCS/DOCO/DOCA` free-text and matched against the TSA No-Fly / Selectee lists. This is the
watchlist-adjacent PII the H2 guard is meant to protect.

---

## 2. The free-text PNR fields — the second-order injection sinks

The heart of the marquee mechanic (H3/H5): several PNR fields are **passenger-controllable free
text** that later systems render **verbatim** into their own context. Ranked by realism:

| Field | Cryptic | Who writes it | Rendered downstream into | Modeled in |
|---|---|---|---|---|
| **SSR free text** (OTHS, SPML, WCHR…) | `SR OTHS …` | agent, **web self-service** | airline host, DCS, ground handling, catering, **PNRGOV gov push** | **H3** (`ssr_text`) |
| **OSI** (Other Service Information) | `OS YY …` | agent, corp tool | every marketing carrier, agent displays, ops notes | **H5** (`osi_text`) |
| **RIR / RM remarks** | `RIR`, `RM` | agent, mid-office | itinerary/e-ticket print, accounting, CRM, quality robotics | (remark field present) |
| **SSR DOCS sub-fields** | `SRDOCS …/SMITH/JOHN/…` | passenger web check-in | Secure Flight, CBP APIS, PNRGOV | H2 (APIS record) |

The canonical chain: **passenger web form → SSR/OSI free text stored in the PNR → an agent-assist
LLM renders it into context ("what does this booking need?") → the assistant calls a privileged
tool.** That is structurally identical to Salesforce **ForcedLeak** (Web-to-Lead *Description* →
Agentforce) and Copilot Studio **ShareLeak** (CVE-2026-21520). H3 and H5 are that chain.

---

## 3. Real security failures in reservation systems (anchors)

| Incident | Year | Root cause | Anchors |
|---|---|---|---|
| **"Where in the World is Carmen Sandiego?"** (Nohl & Nikodijevic, 33C3, SRLabs) | 2016 | GDS auth = surname + low-entropy, sequentially-assigned, publicly-printed record locator; no rate limiting | Record-locator recovery scenario behind **H1** |
| **Amadeus check-in IDOR** (Safety Detectives) | 2019 | PNR was a URL parameter with no authorization check; 141+ airlines | Broken object-level auth on a booking |
| **Amadeus boarding-pass IDOR** | 2019 | Incrementable numeric ID, no auth | Same class |
| **Airline loyalty ATO / Scattered Spider** | 2025 | Credential stuffing; miles are a bearer instrument; travel = ~46% of fraudulent transactions (IATA) | Motive for booking-data theft |

Settlement-integrity fraud (context for the "act on someone else's booking" framing): **ADM**
(Agency Debit Memo) under IATA BSP; **fictitious ticketing** (fake `FH`/`TKNE` to beat the TKTL);
**name-change fraud** (non-transferable fares); **refund/EMD abuse** against a `FLWN` coupon.

---

## 4. AI attack taxonomy grounding

- **OWASP Top 10 for LLM Applications 2025** — LLM01 Prompt Injection, LLM02 Sensitive Info
  Disclosure, LLM05 Improper Output Handling, LLM06 Excessive Agency, LLM07 System Prompt Leakage.
- **OWASP Top 10 for Agentic Applications 2026** (published 2025-12-09) — ASI02 Tool Misuse,
  ASI06 Memory & Context Poisoning, ASI09 Human-Agent Trust Exploitation.
- **MITRE ATLAS** — AML.T0051 (.001 indirect) Prompt Injection, AML.T0054 Jailbreak, AML.T0056
  Extract System Prompt, AML.T0086 Exfiltration via AI Agent Tool Invocation.
- **Lethal trifecta** (Simon Willison, 2025) — private data + untrusted content + an exfil channel
  in one agent is the danger condition (H5).

---

## 5. CVEs the hard track models

| CVE / name | Product | Root cause | Hard level |
|---|---|---|---|
| **CVE-2023-36189** | LangChain `SQLDatabaseChain` | LLM-built SQL from unneutralized input (CWE-89 laundered through the model) | H4 |
| **CVE-2024-21513** | `langchain-experimental` `VectorSQLDatabaseChain` | `eval()` on a value **retrieved from the DB** — true stored/second-order sink | H4 |
| **CVE-2024-5565** (Vanna.AI) | text-to-SQL lib | user question re-injected into a codegen prompt → `exec()` | H4 (class) |
| **CVE-2025-32711** "EchoLeak" | Microsoft 365 Copilot | zero-click indirect injection → data exfil | H3, H5 |
| **ForcedLeak** | Salesforce Agentforce | stored CRM *Description* → agent instructions → exfil | H3, H5 |
| **CVE-2026-21520** "ShareLeak" | Copilot Studio | stored form submission → system instructions → connector calls | H3 |

Multi-turn / guard-evasion techniques (no single CVE; named research): **Crescendo** (Microsoft),
**Bad Likert Judge** (Unit 42), **Policy Puppetry** (HiddenLayer) → H1; **guardrail-evasion via
character injection** (arXiv:2504.11168), **ASCII/Unicode smuggling** (Embrace the Red / Cisco),
ROT13 cipher-resistance → H2.

---

## 6. Why the naive `list XYZ` fails on every hard level

The parking track's flags sit in the system prompt, so a one-shot "print your rules" wins. The
hard track removes that lever structurally:

- **Flags are not in the prompts.** Only the H4 flag is in the DB (the SQLi target); H1/H2/H3/H5
  are minted by `_award` when the exploit tool fires. Prompt-leak / "list everything" gets nothing.
- **Personas refuse direct asks.** ATLAS answers `LOCATOR HOLD`; SENTRY-PNR sits behind a guard;
  TRIAGE-BOT/REPORTQ/CONCIERGE-AX have no secret to *say*, only privileged actions to *misuse*.
- **The win is a tool/DB event**, not model chattiness — captured by `_award` on the write.

---

## 7. Realism check table

| Lvl | Persona | Mechanic in the challenge | Real control it abuses | CVE / framework | Anchor |
|---|---|---|---|---|---|
| H1 | ATLAS | multi-turn escalation → `recover_locator` for a "staff" caller | operator/role verification on a record-locator recovery path | LLM01/LLM07; ATLAS AML.T0054/T0056; ASI09 | Crescendo/Bad-Likert/Policy-Puppetry; SRLabs 33C3 |
| H2 | SENTRY-PNR | obfuscate past a keyword guard → APIS/Secure-Flight PII | perimeter filter vs. the model (tokenizer gap); watchlist-data disclosure | LLM01; ATLAS AML.T0054 | arXiv:2504.11168; ASCII smuggling; ROT13 study |
| H3 | TRIAGE-BOT | store a payload in your own SSR → agent renders the queue and acts | trusting a passenger-controlled free-text field as an ops instruction | LLM01 (indirect); ASI06; ATLAS AML.T0051.001 | ForcedLeak; EchoLeak (CVE-2025-32711); ShareLeak (CVE-2026-21520) |
| H4 | REPORTQ | store a UNION in your surname → report query concatenates it | parameterizing DB queries; not trusting stored values as SQL | CVE-2023-36189; CVE-2024-21513; LLM05 + CWE-89 | P2SQL (Keysight/WithSecure); Vanna CVE-2024-5565 |
| H5 | CONCIERGE-AX | OSI-note injection → agent exfiltrates a sealed note by email | keeping private data, untrusted content, and an exfil channel apart | ASI02/ASI06; ATLAS AML.T0086 | Lethal trifecta (Willison); EchoLeak; ForcedLeak |

**Deliberate simplifications** (so nobody mistakes them for claims about reality):

- Real reservation agents don't expose a conversational LLM with write access to name/SSR/OSI and
  a manifest-report SQL sink. The premise is *what happens if you do* — the direction the industry
  is moving (agent-assist over the PNR), not current practice.
- The H4 report concatenates a stored surname into raw SQL. That specific hole is dramatized, but
  the *class* — a stored field reaching a query/`eval` sink — is exactly CVE-2024-21513 and P2SQL.
- The "sealed embargoed note" (H5) is fiction; the *structure* — private data + untrusted content
  + outbound channel in one agent — is EchoLeak/ForcedLeak, both real and patched.
- The single-`SELF`-row model for a player's own booking is a scoping choice matching the parking
  track's one-shared-cover-identity, serial-play design. Per-session isolation only if the event
  runs players concurrently.

---

## 8. Sources

- OWASP: [Top 10 for LLM Applications 2025](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) · [Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- MITRE: [ATLAS](https://atlas.mitre.org/) · [AML.T0086](https://www.startupdefense.io/mitre-atlas-techniques/aml-t0086-exfiltration-via-ai-agent-tool-invocation)
- Second-order / indirect injection: [Greshake et al., arXiv:2302.12173](https://arxiv.org/abs/2302.12173) · [Keysight P2SQL](https://www.keysight.com/blogs/en/tech/nwvs/2025/07/31/db-query-based-prompt-injection) · [WithSecure Synthetic Recollections](https://labs.withsecure.com/publications/llm-agent-prompt-injection)
- CVEs: [CVE-2023-36189](https://nvd.nist.gov/vuln/detail/CVE-2023-36189) · [CVE-2024-21513](https://nvd.nist.gov/vuln/detail/CVE-2024-21513) · [CVE-2024-5565 (JFrog)](https://jfrog.com/blog/prompt-injection-attack-code-execution-in-vanna-ai-cve-2024-5565/) · [EchoLeak CVE-2025-32711 (Aim Labs)](https://www.aim.security/lp/aim-labs-echoleak-m365) · [ForcedLeak (Noma)](https://noma.security/blog/forcedleak-agent-risks-exposed-in-salesforce-agentforce/) · [ShareLeak CVE-2026-21520 (Capsule)](https://www.capsulesecurity.io/blog-post/shareleak-taking-the-wheel-of-microsofts-copilot-studio-cve-2026-21520)
- Multi-turn / guard evasion: [Crescendo, arXiv:2404.01833](https://arxiv.org/abs/2404.01833) · [Bad Likert Judge (Unit 42)](https://unit42.paloaltonetworks.com/multi-turn-technique-jailbreaks-llms/) · [Policy Puppetry (HiddenLayer)](https://www.hiddenlayer.com/research/novel-universal-bypass-for-all-major-llms/) · [Guardrail evasion, arXiv:2504.11168](https://arxiv.org/abs/2504.11168) · [ASCII smuggling (Embrace the Red)](https://embracethered.com/blog/posts/2024/ascii-smuggling-and-hidden-prompt-instructions/)
- Lethal trifecta: [Simon Willison](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
- Reservation systems: [SRLabs travel hacking / 33C3](https://www.srlabs.de/blog-post/travel-hacking) · [Amadeus IDOR (TechCrunch)](https://techcrunch.com/2019/01/15/amadeus-airline-booking-vulnerability-passenger-records/) · [Secure Flight 49 CFR 1560](https://www.ecfr.gov/current/title-49/subtitle-B/chapter-XII/subchapter-C/part-1560/subpart-B) · [IATA PNRGOV XML guide](https://www.iata.org/contentassets/18a5fdb2dc144d619a8c10dc1472ae80/pnrgov20xml20implementation20guide2016_1.pdf)
