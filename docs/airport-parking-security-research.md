# Airport Parking Security — Research & Realism Reference

Reference document for the **Aviation Cyber AI Injection Challenge**. Every level in this CTF is
supposed to abuse a control that exists in a real airport parking operation. This file is the
accuracy check: if a challenge mechanic can't be traced to a row in §9, it's fiction and should be
fixed or cut.

Compiled 2026-07-26. All claims are sourced in §10. Where something is an inference rather than a
sourced fact, it is marked **[inferred]**.

---

## 1. Why parking is the target

Parking is the single largest non-aeronautical revenue line at North American airports — not
concessions, not retail.

- Parking is **43.2%** of non-aeronautical revenue in North America, versus a **24.1%** global
  average. North America is the outlier; nowhere else does parking dominate like this.
- Parking and ground transportation together: roughly **$6.0B of $13.2B** total non-aeronautical
  revenue in FY2023.
- Consequence for the CTF's premise: an AI agent placed in front of the parking system is placed in
  front of the airport's cash register. That is exactly where a real operator would deploy a
  customer-facing assistant (reservations, rates, "where's my car"), and exactly where the blast
  radius of an insecure one is financial rather than cosmetic.
- Secondary pressure: TNC (Uber/Lyft) curbside competition has pushed airports toward dynamic
  pricing and pre-booking to defend parking revenue — which means more online booking surface, more
  account data, and more automation. **[inferred: this is the trend that makes an AI booking agent
  plausible in 2026]**

## 2. The real technology stack

Vocabulary matters for professional credibility. The correct terms:

**PARCS — Parking Access and Revenue Control System.** The umbrella system: entry/exit lane
hardware, gates, ticket dispensers, pay-on-foot stations, cashier terminals, and the back-office
revenue software. Global market ~$6.6B in 2025. Airports are explicitly a primary segment for the
large integrated deployments. Vendor names that appear in airport work: FlashParking, TIBA, ParqEx,
Survision, plus regional integrators.

**ALPR / LPR — Automated License Plate Recognition.** Cameras plus OCR at entry and exit plazas.
The plate read is linked to the parking event (ticket or reservation) on entry; on exit the plate is
read again, matched, and the gate vends automatically if the stay is paid.

**LPI — License Plate Inventory.** The piece most people outside parking have never heard of, and
the most interesting for a CTF. LPI is a *digital inventory of every plate currently on the
property*, searchable and filterable. It is built from two sources:

- fixed lane LPR cameras (entry/exit), and
- **mobile/handheld scans** — staff drive or walk the lot scanning parked vehicles ("MLPI"). Airport
  parking RFPs literally require staff to *"conduct a license plate inventory of all vehicles in the
  public parking facility each twenty-four (24) hour period"* and to interface that data with the
  revenue control system, plus a monthly occupancy report.

Merging fixed LPR with mobile LPI is what enables: real-time occupancy per lot, **lost-ticket-fee
lookup by plate**, find-my-vehicle, missing/unaccounted-vehicle detection, and hotlist matching for
stolen vehicles.

**Gateless / ticketless / frictionless parking.** Increasingly the plate *is* the credential —
"license plates serving as the access credential, replacing physical or digital permits." No ticket,
no gate stop; enter and exit are pure database events. Airports are named as a primary adopter.
Security consequence: **if the plate is the credential, then plate data is authentication material,
not just PII.** That single sentence justifies levels 3 and 4 of this CTF.

**Validation / coupon systems.** Discount codes issued by tenants, hotels, or the airport itself,
redeemed at exit. Historically the softest spot in parking revenue control (see §4).

**VMS — Video Management System.** The CCTV side: cameras, recording, retention, operator
workstations, export/clip tooling, and an audit trail of who viewed or exported what.

## 3. What the data actually contains (and how long it's kept)

This is the section to check level 3's snapshot against. Published ALPR policies from airports and
public parking operators converge on the following.

**Captured for every vehicle, no account required:**

| Field | Notes |
|---|---|
| license plate number | the OCR result |
| license plate state | jurisdiction |
| license plate **image** | the photo itself, retained separately from the text |
| date + time of capture | to the second |
| location | lane / camera ID / facility; some systems record GPS |

**Additionally, for account holders / permit holders / app users:**

| Field | Notes |
|---|---|
| name | |
| employee or account ID | |
| permit type | monthly, employee, reserved, economy |
| vehicle year, make, model, color | |
| **VIN** | yes, really — Alameda County GSA's policy lists it |
| payment / parking device info | tokenized card, transponder, app device ID |

**Retention, from real published policies:**

- **30 days** — AirGarage purges plate data after 30 days; photos with no visible plate deleted
  within 30 days.
- **90 days** — Alameda County GSA retains plate *images* no longer than 90 days, extended to **one
  year after determination** if tied to an active appeal.
- **30 days minimum for CCTV** — TSA's agreements with airports include archiving a minimum of 30
  days of CCTV footage; airports generally delete after 30. Note the cameras are typically
  airport-owned, not government-owned, with TSA co-funding checkpoint cameras and airport, local law
  enforcement, and TSA all able to view.
- "Varies by facility / until storage capacity is exceeded" is a common and much weaker clause —
  i.e. retention is often bounded by disk, not by policy. **Good CTF material: an agent that can
  read a record that policy says should already be gone.**

**Access control and audit — the part CTF players should learn to look for.** Alameda County's
policy is the clearest published example:

- A named, enumerated list of roles may query the system (parking manager, admin support clerk,
  enforcement technicians, and the third-party ALPR/citation vendor). Nobody else.
- *"All logins and queries will be stored and monitored, including: Username, Date, Time, **Purpose
  of query**, License plate and other elements."*
- Use is restricted to parking management and enforcement of parking regulations. Commercial sale or
  unauthorized sharing prohibited. Outside sharing requires subpoena/warrant/court order or an
  approved business need-to-know.

**Purpose-of-query logging is the control the CTF's level 3 breaks.** An AI lookup agent that
answers "who owns plate X" without binding the query to an authorized role and a recorded purpose
has silently deleted the only accountability mechanism in the entire policy.

## 4. Real incidents — one anchor per level

**Port of Seattle / Seattle-Tacoma International, August 2024 — the direct precedent.**
Rhysida ransomware. The IT outage hit reservation check-in, passenger display boards, the Port
website, the flySEA app, and delayed flights; airport Wi-Fi went down and staff ran flight and
baggage info off dry-erase boards. The Port declined to pay. Roughly **90,000 people** were later
notified, and the stolen data came from systems holding **employee, contractor, and parking
customer** records — names, dates of birth, **Social Security numbers, driver's license / ID
numbers**, and in some cases medical information. This is the "airport parking data is real PII, at a
real airport, recently" citation.

**ParkMobile, March 2021 — the parking-app breach.** Misconfigured AWS S3 bucket. **21 million
users**; exposed email addresses, phone numbers, **license plate numbers**, and in some cases mailing
addresses. Payment cards and SSNs reportedly not affected. Settled for **$32.8M** (final approval
hearing March 13, 2025). This is the citation for "plate + contact info is a breach class of its
own," and for why level 3's leak is a realistic harm rather than a curiosity.

**Misconfigured ALPR cameras streaming to the open internet, 2025.** More than **150** misconfigured
Motorola plate readers were found streaming live video and vehicle data — including plate numbers —
in color and infrared to the open internet, reachable **without authentication**. EFF's earlier work
(2024) documented ALPR vulnerabilities generally; its 2025 Flock Safety investigations documented
the access-control side: a networked database structure that let agencies query other agencies' ALPR
data far more broadly than state law permitted, plus abuse cases (tracking protesters, discriminatory
searches, surveillance of people seeking reproductive healthcare). Litigation is active.

Two distinct lessons, both useful: **(a)** plate infrastructure gets deployed with authentication
missing, and **(b)** even when authentication works, *authorization scope* is where it fails — which
is exactly BOLA (§6).

**Verkada, March 2021 — the CCTV lesson.** Attackers reached a **Jenkins server** used by Verkada's
support team for bulk maintenance on customer cameras, obtained credentials that **bypassed the
authorization system including two-factor authentication**, and had access for ~36 hours to live
feeds and archives from **~150,000 cameras** across hospitals, clinics, police departments, prisons,
schools, and companies. Some cameras ran facial recognition. The relevant shape for level 5: *the
operator tooling, not the camera, is the way in* — an over-privileged maintenance/support path that
sidesteps normal auth.

**Parking revenue fraud — the insider lesson.** Fraud in parking operations sorts into four
categories: cash theft, **validation/discount-coupon theft**, financial statement fraud, and
monthly-parker access abuse — usually committed directly by attendants. The classic mechanic is
charging the customer full price, recording the transaction as a discount, and pocketing the
difference. A county internal audit of airport parking (Volusia County, 2024) found **coupons still
being honored after expiration** — **$5,401** in discounts — and that airport staff only received
*monthly* reports until auditors asked for daily ones. Recommended controls are unannounced spot
audits of daily revenue and pay-on-foot float replenishment.

That audit finding is the template for level 4: **a discount/adjustment path with no second control
and reporting too coarse to notice.** An AI agent that can apply an adjustment is a cashier who never
takes a day off and never gets spot-audited.

## 5. AI is already deployed here — the premise is not speculative

**Heathrow — "Hallie"** (built with Salesforce Agentforce, launched March 2025, on WhatsApp) is the
closest real analogue to this CTF's target. It draws on a Service Cloud knowledge base of ~500
articles **plus live APIs, maps, and flight-status data**, resolves ~**90%** of chat queries without
human transfer, and by March 2026 had cut phone calls from **70% to 10%** of customer enquiries.
Planned expansion to the website, app, and terminal kiosks. An assistant wired to live operational
APIs, at an airport, today.

**Airlines:** Delta Concierge (announced CES 2025, personalization over a very large data
footprint); United embedding ChatGPT in its app; **Alaska Airlines "Alaska Inspires"** — customer-
facing natural-language destination search (Gemini and Azure OpenAI implementations both reported),
90+ languages, voice input, ~75% reduction in destination-planning time, and a chatbot that cut
live-agent interaction by **34%**. KLM, Lufthansa, AirAsia, Qatar all run disruption-handling bots.

**The direction of travel that creates the risk:** these systems are moving from "chatbots that
reply" to **agents that act** — checking status, updating accounts, **processing refunds**, creating
tickets, escalating. Refund and account-mutation authority in a chat surface is precisely the
excessive-agency pattern in §6.

**The liability precedent — cite this one on the demo slide.** *Moffatt v. Air Canada*, BC Civil
Resolution Tribunal, February 2024. Air Canada's website chatbot told a customer he could apply
retroactively for a bereavement fare. That was wrong. Air Canada argued the chatbot was effectively
a separate entity responsible for its own statements; the tribunal rejected that and held the airline
responsible for all information on its website, chatbot or static page. Damages: **CAD $812.02**.
Small money, large principle — the operator owns what its agent says. Extend that to an agent that
*acts* and the exposure is no longer $812.

## 6. Frameworks to tag each level with

**OWASP Top 10 for LLM Applications (2025):**

- **LLM01 Prompt Injection** — the whole CTF.
- **LLM02 Sensitive Information Disclosure** — moved up from #6 to #2 in the 2025 edition,
  specifically because of demonstrated extraction of data *and of the model's own configuration*
  through targeted queries. Levels 2 and 3.
- **LLM06 Excessive Agency** — significantly expanded in 2025 and split into three root causes:
  **excessive functionality** (the agent can reach tools beyond its task), **excessive permissions**
  (those tools run with broader privilege than needed), and **excessive autonomy** (high-impact
  actions proceed with no human in the loop). Documented abuse examples include manipulating an agent
  with database access into deleting records. Mitigation: manual approval for high-impact actions.
  Levels 4 and 5 are this entry, verbatim.

**OWASP Top 10 for Agentic Applications (2026)** — ASI01–ASI10, covering agent goal hijack, tool
misuse, memory poisoning, and rogue agents. Companion projects: an **MCP Top 10** for the
agent-to-tool connection layer, and an Agentic Skills Top 10. Useful ambient stat for the talk:
one 2026 analysis of 7,000+ MCP servers found ~**36.7%** potentially vulnerable to SSRF.

**OWASP API Security Top 10 — API1:2023 Broken Object Level Authorization (BOLA).** Number one since
2019, present in roughly **40% of API attacks**. The mechanic: manipulate an object ID in a request
and the API hands back data belonging to someone else. Real examples cited by OWASP-adjacent writeups
include Volkswagen connected-car APIs exposing owner data and a T-Mobile endpoint leaking 37M
records. **This is what a parking agent does when it will look up any `conf_code` or `txn_id` you
name instead of only yours.** Note also **API3:2023 Broken Object *Property* Level Authorization** —
the agent that returns the whole record including internal fields.

**EchoLeak — CVE-2025-32711**, CVSS 9.3, disclosed June 2025 by Aim Security: a **zero-click**
indirect prompt injection in Microsoft 365 Copilot enabling data exfiltration from a single crafted
email, chaining an XPIA-classifier bypass, reference-style markdown to dodge link redaction,
auto-fetched images, and a CSP-allowed Teams proxy. Patched server-side, no in-the-wild exploitation
confirmed. Significance for the demo: this is the existence proof that prompt injection produces
**real exfiltration in a production system**, not just funny chatbot screenshots. The stated lesson —
scope the data the agent can reach, rather than patching injections one at a time — is the defensive
takeaway the CTF should end on.

## 7. Regulatory and community context

- **TSA cybersecurity amendment, March 7, 2023** — emergency action amending the security programs of
  TSA-regulated **airport and aircraft operators**. Requires a TSA-approved implementation plan
  describing measures to improve cyber resilience, including **network segmentation** so OT can
  operate safely if the IT network is compromised. Note for accuracy: as of the sources reviewed,
  TSA's published cybersecurity *rulemaking* (NPRM) addresses surface transportation — pipelines,
  rail, bus — not aviation; the FAA separately convened a Civil Aviation Cybersecurity Aviation
  Rulemaking Committee, with no fixed aviation timeline published. **Don't claim an aviation cyber
  rule exists.**
- **49 CFR Part 1542** — Airport Security Program, the framework under which commercial airports
  document perimeter and access controls (and the hook for CCTV coverage/retention expectations).
- **Aviation ISAC (A-ISAC)** — founded 2014; global community of airlines, airports, OEMs, IFE/satcom
  and service providers sharing threat intel. Member cadence: annual summit, quarterly AvTech
  Exchange, bi-weekly analyst calls, annual tabletop, CISO roundtables. **2026 Aviation
  Cybersecurity Summit: September 29 – October 2, Vancouver** (Sheraton Vancouver Wall Centre;
  registration closes Sept 14, 2026).
- **DEF CON Aerospace Village** — the venue format to echo: the **Aviation ISAC CTF** there is run as
  an aviation "who-dunnit" spanning airlines, aircraft, and airports, alongside hands-on demos like
  Bricks in the Air. If this challenge is aimed at that audience, the narrative-investigation framing
  is the house style.

## 8. What professional software people miss

The teaching payload. Each item is something a competent developer ships wrong, and each maps to a
level.

1. **Authentication is not authorization.** The agent verified *who you are* (or didn't) and then
   honored any object ID you named. BOLA — #1 API risk for seven years running.
2. **No purpose-binding on a lookup.** Real ALPR policy requires the *purpose of query* to be logged.
   An assistant that answers plate lookups conversationally records nothing an auditor could use.
3. **Property-level over-return.** The record comes back whole — internal fields, adjustment
   authority tokens, cashier IDs — because nobody wrote a response schema.
4. **Tool permissions broader than the task.** A read-only assistant handed a write-capable
   credential because it was the credential that was already lying around. (LLM06, excessive
   permissions.)
5. **Mutating actions with no human in the loop.** Zeroing a charge, granting points, deleting a
   record — all reachable in one conversational turn. (LLM06, excessive autonomy.)
6. **Audit logs the application can delete.** If the same identity can write the record and remove
   it, there is no audit log; there is a diary.
7. **Zero and negative amounts accepted without a second control.** The Volusia finding in software
   form: a discount path with no dual approval and reporting too coarse to catch it.
8. **PII minimization ignored.** Plate + name + itinerary + vehicle description in a single helpful
   answer is a dossier, not a customer-service response.
9. **Retention limits unenforced in code.** Policy says 30 or 90 days; the data is still queryable
   because deletion was never implemented and disk is cheap.
10. **Model output trusted as a command.** The text the model produced becomes a SQL statement, an
    API call, or an authorization decision with nothing in between.
11. **When the plate is the credential, plate data is authentication material.** Gateless parking
    quietly converts a public-facing identifier into a key, and nobody re-runs the threat model.

## 9. Realism check table

Use this when validating each level. If a level's mechanic isn't here, add a row with a source or
change the mechanic.

| Lvl | Persona | Mechanic in the challenge | Real control it abuses | Anchor |
|---|---|---|---|---|
| 1 | SKYPARK-KIOSK | authority claim ("garage technician, running an audit") flips the assistant | no operator/role verification on a public kiosk assistant | LLM01; Heathrow-style public assistant |
| 2 | RESERVE-1 | leak own config / rate-override table; touch a reservation that isn't yours | LLM02 config disclosure + **BOLA** on `conf_code` | OWASP LLM02, API1:2023 |
| 3 | PLATEWATCH | evade a keyword filter, get plate → owner PII with no purpose recorded | ALPR purpose-of-query logging; enumerated authorized roles; retention limits | Alameda County GSA policy; ParkMobile; misconfigured ALPRs |
| 4 | REVCON | format-constrained API coughs up all internal fields; zero out an exit charge / grant points | validation & adjustment controls, dual approval, daily (not monthly) reporting | Volusia audit ($5,401, expired coupons); parking fraud taxonomy; LLM06 |
| 5 | VMS-OPS | rapport as an "ops-floor colleague" → splice looped coverage over a 4-minute gap, then edit the audit log | VMS operator authorization + export/view audit trail; 30-day retention | Verkada (support path bypassing authz/2FA); TSA 30-day CCTV archive |
| Fun | GATE-9 | persona/goal derailment | goal hijack, ASI01 | OWASP Agentic 2026 |

Notes on deliberate simplifications, so nobody mistakes them for claims about reality:

- Real PARCS deployments do not expose a conversational agent with write access to exit transactions.
  The CTF's premise is *what happens if you do* — which is the direction the industry is moving
  (agents that act, §5), not current practice. Say this out loud in the demo.
- The single-day snapshot is a scoping choice. Real LPI is a rolling 24-hour inventory, so a one-day
  dataset is actually faithful to how LPI is described.
- Loop-splicing CCTV via an operator tool is dramatized. What's real is the over-privileged operator/
  support path (Verkada) and the existence of clip export tooling with an audit trail. **[inferred:
  a "splice loop" function is not a documented VMS feature]**

## 10. Sources

**Revenue**
- ACI World — https://blog.aci.aero/airport-economics/maximizing-non-aeronautical-revenues-key-to-airport-financial-sustainability/
- ACI-NA, State of Airport Non-Aeronautical Revenues (2025) — https://airportscouncil.org/wp-content/uploads/2025/07/State-of-ANAR_CMC-Meeting_Slide-Deck_Slava-Cheglatonyev.pdf
- ACI-NA 2025 Concessions Benchmarking Survey — https://airportscouncil.org/wp-content/uploads/2025/07/20250619-ACI-NA-Concession-Survey_BM-Success.pdf
- DWU Consulting, parking revenue + TNC dynamic pricing — https://dwuconsulting.com/dwu-ai/airport-parking-tnc-dynamic-pricing

**Technology stack**
- Survision, What is License Plate Inventory (LPI) — https://www.parking.net/parking-news/survision/what-is-license-plate-inventory-lpi
- Survision, LPR: a quiet revolution for airports — https://survisiongroup.com/post-lpr:-a-quiet-revolution-for-airports
- Parking Today, LPR and beyond coming to an airport near you — https://parkingtoday.com/segments/airport/license-plate-recognition-and-beyond-coming-to-an-airport-near-you/
- City of Chicago airport parking RFP spec — https://www.chicago.gov/content/dam/city/depts/dps/ContractAdministration/Specs/2020/Spec1157052.pdf
- Port of Pasco, Tri-Cities Airport parking management RFP — https://www.portofpasco.org/uploads/RFP-RFQ/Parking-Management-Contract-RFP-FINAL-9.5.23.pdf
- FlashParking, PARCS — https://www.flashparking.com/parking-access-and-revenue-control/
- AirGarage, what is gateless parking — https://www.airgarage.com/resources/what-is-a-gateless-parking-system-and-how-does-it-work
- PARCS market sizing — https://www.archivemarketresearch.com/reports/parking-access-and-revenue-control-systems-parcs-179892

**Data fields, retention, access control**
- Alameda County GSA LPR privacy & usage policy — https://gsa.acgov.org/local-services/find-parking/license-plate-recognition-privacy-and-usage-policy/
- San Diego International ALPR procedure — https://www.san.org/wp-content/uploads/2025/08/ALPR-SAN_Procedure_2017.pdf
- Omaha Airport Authority ALPR policy — https://www.flyoma.com/wp-content/uploads/2018/07/alpr-policy.pdf
- AirGarage LPR privacy policy — https://www.airgarage.com/lpr-privacy
- UPP Global ALPR policy — https://uppglobal.com/automated-license-plate-recognition-alpr-policy
- Airport CCTV retention / TSA 30-day archive — https://www.ncesc.com/how-long-do-airports-keep-cctv/ and https://www.elliott.org/blog/smile-the-tsa-is-taping-you-and-heres-what-you-need-to-know-about-it/
- PHL parking reservation terms — https://parking.phl.org/book/PHL/Content/Reservation+Terms+And+Conditions
- LAS lost-ticket fee structure — https://www.triplypro.com/blog/las-vegas-airport-long-term-parking-lost-ticket
- myDFW Rewards — https://www.dfwairport.com/mydfw-rewards/ ; The Parking Spot Spot Club — https://www.theparkingspot.com/spot-club

**Incidents**
- Port of Seattle, 90,000 notified — https://www.bleepingcomputer.com/news/security/port-of-seattle-says-ransomware-breach-impacts-90-000-people/
- Port of Seattle official notice — https://www.portseattle.org/news/port-seattle-providing-notice-individuals-affected-fall-2024-cyberattack
- Port of Seattle cyberattack archive — https://www.portseattle.org/news/port-cyberattack-archive
- ParkMobile settlement — https://www.forbes.com/sites/larsdaniel/2024/12/13/parkmobile-328-million-data-breach-settlement-are-you-eligible/
- ParkMobile settlement site — https://www.parkmobilesettlement.com/
- Misconfigured Motorola ALPRs leaking to the open internet — https://www.tomsguide.com/computing/online-security/millions-at-risk-due-to-severe-security-flaw-in-license-plate-readers
- EFF, new ALPR vulnerabilities — https://www.eff.org/deeplinks/2024/06/new-alpr-vulnerabilities-prove-mass-surveillance-public-safety-threat
- EFF, Flock Safety investigations 2025 in review — https://www.eff.org/deeplinks/2025/12/effs-investigations-expose-flock-safetys-surveillance-abuses-2025-review
- Verkada mass hack public report (IPVM) — https://ipvm.com/reports/verkada-hack
- Verkada coverage — https://www.securitymagazine.com/articles/94789-verkada-breach-exposed-live-feeds-of-150-000-surveillance-cameras-inside-schools-hospitals-and-more
- Volusia County internal audit 2024-05, airport parking — https://www.volusia.org/government/pdf/2024-05_Audit_Report_Airport_Parking_ADA.pdf
- Parking fraud taxonomy — https://blog.bindy.com/7-easy-steps-to-help-identify-fraud-in-a-reits-parking-operations/
- Parking Today, the lost art of the parking audit — https://parkingtoday.com/segments/airport/the-lost-art-of-the-parking-audit/

**AI in aviation**
- Salesforce, Heathrow Agentforce "Hallie" — https://www.salesforce.com/uk/news/press-releases/2025/06/11/heathrow-airport-agentforce-passenger-experience/
- Hallie one-year results — https://app.dealroom.co/news/feed/heathrow-s-ai-assistant-hallie-cuts-phone-inquiries-from-70-to-10-in-one-year
- diginomica on Hallie — https://diginomica.com/agentforce-flight-status-update-heathrow-airport-no-turbulence-en-route-hallie-agent-takes-air
- Delta Concierge — https://www.ajc.com/news/business/meet-your-newest-ai-chatbot-delta-concierge/3GFA5DFBOBBXVCYHNT2SMWCHAA/
- Alaska Inspires (Microsoft) — https://www.microsoft.com/en/customers/story/25850-alaska-airlines-azure-openai
- Alaska natural-language search (CX Dive) — https://www.customerexperiencedive.com/news/alaska-airlines-natural-language-search-trip-planning/807705/
- Moffatt v. Air Canada (CBC) — https://www.cbc.ca/news/canada/british-columbia/air-canada-chatbot-lawsuit-1.7116416
- Moffatt legal analysis (McCarthy Tétrault) — https://www.mccarthy.ca/en/insights/blogs/techlex/moffatt-v-air-canada-misrepresentation-ai-chatbot
- Moffatt (ABA Business Law Today) — https://www.americanbar.org/groups/business_law/resources/business-law-today/2024-february/bc-tribunal-confirms-companies-remain-liable-information-provided-ai-chatbot/

**Frameworks**
- OWASP Top 10 for LLM Apps 2025 — https://www.confident-ai.com/blog/owasp-top-10-2025-for-llm-applications-risks-and-mitigation-techniques
- OWASP LLM 2025 practical guide — https://www.gravitee.io/blog/owasp-top-10-for-llm-applications-2025-a-practical-guide
- OWASP Top 10 for Agentic Applications 2026 — https://www.paloaltonetworks.com/blog/cloud-security/owasp-agentic-ai-security/
- Real-world attacks behind the agentic top 10 — https://www.bleepingcomputer.com/news/security/the-real-world-attacks-behind-owasp-agentic-ai-top-10/
- OWASP API1:2023 BOLA — https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/
- OWASP API3:2023 Broken Object Property Level Authorization — https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/
- EchoLeak CVE-2025-32711 analysis — https://www.hackthebox.com/blog/cve-2025-32711-echoleak-copilot-vulnerability
- EchoLeak paper — https://arxiv.org/abs/2509.10540

**Regulatory / community**
- TSA press release, cyber requirements for airport & aircraft operators — https://www.tsa.gov/news/press/releases/2023/03/07/tsa-issues-new-cybersecurity-requirements-for-airport-and-aircraft
- Claroty, unpacking the TSA requirements — https://claroty.com/blog/unpacking-new-tsa-cybersecurity-requirements-aviation
- Covington Inside Privacy on the directive — https://www.insideprivacy.com/data-security/tsa-issues-new-cybersecurity-requirements-for-airport-and-aircraft-operators/
- Aviation ISAC — https://www.a-isac.com/ ; 2026 Summit — https://www.a-isac.com/summit ; member benefits — https://www.a-isac.com/member-benefits
- DEF CON Aerospace Village — https://www.aerospacevillage.org/def-con-33/def-con-33-activites

**Asset tooling**
- FFmpeg filters reference — https://ffmpeg.org/ffmpeg-filters.html
- Vintage/grain filter recipes — https://zayne.io/articles/vintage-camera-filters-with-ffmpeg
- Pixabay parking lot/garage video — https://pixabay.com/videos/search/parking%20lot%20garage/
- Pexels parking lot video — https://www.pexels.com/search/videos/parking%20lot/
- Free LicensePlate.ttf (Dave Hansen, 2005) — https://www.fontsaddict.com/font/license-plate.html
- Penitentiary Gothic specimen (California plates) — https://www.leewardpro.com/articles/licplatefonts/font-penitentiary.html
- Veo 3 vs Sora 2 2026, on-screen text limitation — https://pxz.ai/blog/veo-3-vs-sora-2-2026-full-comparison
