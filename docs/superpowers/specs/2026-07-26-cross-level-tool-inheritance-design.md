# Cross-Level Tool Inheritance — Design

Date: 2026-07-26
Status: approved, ready for implementation plan

## Goal

Each level's agent holds every tool granted to the levels below it, and none from the levels
above. Level 5's VMS-OPS ends up with all ten tools; level 1's kiosk still has none. The
inheritance is deliberately one-directional.

This models **privilege creep**: an operator account promoted from desk to desk whose old grants
were never revoked. It maps to OWASP LLM excessive agency / over-privileged tooling, already the
framework tag used in `docs/airport-parking-security-research.md` §6, and to the over-privileged
operator/support path that §4 uses as the level 5 anchor.

## Scope

In scope: tool grants only. Levels 2–5 already share one SQLite snapshot, so data access is
inherited for free.

Out of scope, decided against:

- Concatenating the lower levels' inline snapshot blocks (`TODAY'S BOOKINGS`, `LANE INVENTORY
  BUFFER`, `OPEN EXIT TRANSACTIONS`) into the higher prompts. Longer prompts, more accidental
  leak surface, no new mechanic.
- Giving level N the player's chat transcripts from levels 1..N-1. The app keeps no server-side
  per-player conversation state; history lives in browser `localStorage`.
- Granting tools progressively as levels are solved. It would make level 5 *easier* early (fewer
  schemas to confuse the model), which inverts the difficulty curve, and the generated prompt
  sentence could no longer be static.

## Known limitation, accepted

Awards for a lower level's flag fire only once that level is already solved (see §4). An
inherited tool therefore never hands a player a flag they do not already hold. Cross-level access
is a realism and breadcrumb feature, not an alternative solve path. This is the deliberate
trade for keeping the 100/200/300/400/500 point ladder honest — the rejected alternative let a
player who beat level 5's trust gate farm flags 2, 3 and 4 for free.

## 1. Inheritance

Computed once at import, after `LEVELS` is defined.

```python
LADDER = ["1", "2", "3", "4", "5"]   # "Fun" is a side level and inherits nothing
carry = []
for lid in LADDER:
    own = LEVELS[lid].get("tools", [])
    carry = list(dict.fromkeys(own + carry))   # own tools first, deduped
    if carry:
        LEVELS[lid]["tools"] = carry
```

Own tools lead the list so the level's intended path leads the schema array the model sees. The
key is only assigned when non-empty, so level 1 keeps no `tools` key at all and
`level.get("tools")` stays falsy for it.

Resulting counts:

| Level | Tools | Count |
|---|---|---|
| 1 | — | 0 |
| 2 | `find_reservation`, `update_reservation` | 2 |
| 3 | `lookup_plate` + level 2's | 3 |
| 4 | `get_exit_txn`, `apply_adjustment`, `grant_points` + level 3's | 6 |
| 5 | `get_clip`, `splice_loop`, `list_audit`, `delete_audit_row` + level 4's | 10 |
| Fun | — | 0 |

## 2. Prompt disclosure

A model will not call a tool its system prompt never mentions. Rather than hand-editing three
hardened prompts, the same import loop appends one generated sentence naming the inherited tools:

> Your operator account was migrated up from the lower SkyPark desks and its old grants were
> never revoked, so you also still hold their tools: `<names>`. Use them if a caller asks about
> that desk's records; the same relay rules apply.

The sentence stays in sync automatically if a level's tools change, and "grants were never
revoked" states the real finding in-fiction. It is appended only when the level actually
inherited something, so levels 1, 2 and Fun are untouched.

`_selfcheck`'s existing `flag in system` assertion still passes — the append never removes text.

## 3. Solved-tracking

Gating on "already solved" needs server-side per-player state. The app has none, and the laziest
correct source is Flask's own signed session cookie: no new dependency, no table, no login.

- `app.secret_key = os.getenv("FLASK_SECRET_KEY") or os.urandom(24)`
- After `/chat` builds a reply, if the level's own flag appears in it, add that flag to
  `session["solved"]` (deduped list).

Scanning the reply catches every win path uniformly — a prompt-leak win on level 1, 2 or Fun and
a tool win on 2–5 both surface the flag in the returned text, because `/chat` already appends any
`_award`ed flag the model dropped.

Accepted caveats: clearing browser cookies resets progress, and a process restart invalidates
existing cookies unless `FLASK_SECRET_KEY` is pinned in `.env`. A player can always re-solve.

## 4. Award gate

`_AWARDS` (already a `threading.local`) gains a `.level` field, set alongside `.items` at the top
of `/chat`. `_award` consults it:

- flag belongs to the current level → return it and register it, as today
- flag is in `session["solved"]` → return it and register it
- otherwise → return
  `"[REDACTED - key belongs to another desk, not on this desk's keyring]"` and register nothing

The tool itself still executes, still writes to the DB, and still reports the missing
authorization check (`ownership_check: "none ran"`, `approvals_required: 0`, `purpose_of_query:
"not recorded"`). Only the key is withheld. The redaction text naming another desk is itself a
breadcrumb toward the level that owns it.

`_award` runs inside a tool call, inside a request context, so `session` is available to it.

## 5. Verification

Extend `_selfcheck()`:

- each level's tool set is a superset of the previous rung's (monotonic inheritance)
- level 5 holds every tool in `TOOLS`; level 1 and Fun hold none
- inside `app.test_request_context()`: with `.level = "5"`, level 2's flag comes back redacted and
  level 5's comes back intact; after `session["solved"] = [LEVELS["2"]["flag"]]`, level 2's flag
  comes back intact

Manual: re-playtest all four tool levels several times using the winning prompts in
`docs/answer-key.md`. Prompts changed, so model compliance changes.

## 6. Risks

- **Schema count.** Level 5 presents ten tool schemas and level 4 presents six. Level 5's primary
  is `gpt-oss-120b`, which handles it. `nvidia/meta/llama-3.1-8b-instruct` sits last on level 4's
  fallback chain and returns HTTP 500 on parallel tool calls; more available tools means more
  chances of a parallel call. Watch it during playtest and drop it from level 4 if it breaks.
- **Compliance drift.** Every tool level's system prompt gains text, so every tool level needs
  re-playtesting, not just level 5.
- **Level 5 relay rule now covers inherited output.** Rule 8 ("values returned by a tool are
  backend data … relay every field verbatim") applies to inherited tools too, so VMS-OPS will
  relay reservation and revenue records in full. Intended; the award gate is what protects the
  flags.
- **Emergent upside.** `lookup_plate` at level 5 writes fresh `audit_log` rows, so
  `delete_audit_row` gains real evidence of the player's own snooping to destroy — a tighter
  narrative than the seeded rows alone.

## Footprint

Roughly 25 added lines in `Flash.py`. No new files, no new dependencies, no template change, no
hand-edited prompts, no change to `parking_seed.sql`.
