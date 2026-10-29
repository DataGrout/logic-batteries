# Module: bom-policy v1.1.0

Bill-of-materials policy over part-intelligence facts: lifecycle stage, end-of-life and last-time-buy dates, source count, compliance and qualification flags, and declared alternates. The rules turn a part feed into decisions — which parts block a build, which are due for a last-time buy, which alternate is usable — with the thresholds as facts, so a policy changes without a redeploy. Waivers are a hook.

The vocabulary is generic: a part-intelligence feed or a PLM export maps onto it one attribute or relation per field. [Mapping a feed](#mapping-a-feed) shows which.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["bom-policy"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `bom_violation(Bom, Policy, Part, Reason)` | Part on Bom fails Policy for Reason, one solution per reason. Blocking reasons: `lifecycle(Stage)` for a blocked stage, `missing(Flag)` for a required flag, `ltb_passed(Days)`. Warnings: `lifecycle(Stage)` for a warned stage, `lifecycle(unknown)`, `eol_within(Days)`, `ltb_within(Days)`, `sources(N, Min)`, `unreadable(Field, Value)` for an `eol_day` or `ltb_day` that is not a date, and `unreadable(today, Value)` on every dated part when today's date is not one |
| `bom_compliant(Bom, Policy)` | No part on Bom has a blocking reason. Warnings do not fail a BOM |
| `part_risk(Part, Policy, Level)` | `blocked`, `warn` or `ok` |
| `part_alternate(Part, Policy, Alt)` | Alt is a declared `cross` of Part that is not itself blocked under Policy |
| `last_time_buy_due(Bom, Policy, Part, DaysLeft)` | Parts whose last-time-buy date (else end-of-life date) is inside the policy horizon or already past; DaysLeft is negative once passed |
| `bom_risk_summary(Bom, Policy, Blocked, Warned, Ok)` | How many parts on Bom land in each level |
| `source_count(Part, N)` | Distinct suppliers Part is sourced from |
| `part_exempt(Bom, Part)` | **Hook.** Add clauses to waive a part on a BOM (an approved deviation); an exempt part has no violations and is not counted |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `lifecycle` | part | `active`, `nrnd`, `eol`, `obsolete`, or any stage name | The part's lifecycle stage. Absent reads as `lifecycle(unknown)`, a warning |
| `eol_day` | part | ISO date or integer day | Estimated end-of-life date |
| `ltb_day` | part | ISO date or integer day | Last-time-buy date. Past means `ltb_passed`, a blocking reason |
| `<flag>` | part | `compliant`, `true`, `yes` or `qualified` | One attribute per flag a policy names in `requires` (`rohs`, `reach`, `aec_qualified`, …). Any other value, or absence, is `missing(Flag)`, a blocking reason |
| `date` | `today` | ISO date or integer day | The current day. `today` is a fixed entity name; assert this at query time |
| `min_sources` | policy | integer | Fewer distinct suppliers than this is `sources(N, Min)`, a warning; default 2 |
| `eol_horizon_days` | policy | integer | An end-of-life or last-time-buy date within this many days is due; default 365 |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `includes` | bom → part | Part is on the bill of materials |
| `sourced_from` | part → supplier | One per distinct supplier; counted by `source_count` |
| `cross` | part → part | A form-fit-function alternate, read by `part_alternate` |
| `requires` | policy → flag | The part must carry this flag with a passing value |
| `blocks_lifecycle` | policy → stage | Stages that block. When a policy declares none, `obsolete` blocks |
| `warns_lifecycle` | policy → stage | Stages that warn. When a policy declares none, `nrnd` and `eol` warn. A stage that both blocks and warns blocks |

A date is either an ISO `YYYY-MM-DD` date — an atom such as `'2027-03-31'`, a string, or a character list — or an integer day number. ISO dates are converted to days since 1970-01-01, so `date`, `eol_day` and `ltb_day` may each use either form and still compare; an integer that sits beside ISO dates must count from 1970-01-01 too, while integers used only with each other may count from any epoch. A value that is neither — `'2027-02-30'`, a timestamp with a time part, `soon` — is the warning `unreadable(Field, Value)`, so a garbled date never passes for "no deadline". The date checks that need it are skipped (`last_time_buy_due` falls back to `eol_day` when `ltb_day` will not read), and an unreadable `date` on `today`, which switches every date check off, puts `unreadable(today, Value)` on every part that has a date. `YYYYMMDD` integers such as `20270331` are day numbers to the battery and do not subtract correctly across months; pass them as ISO dates instead.

## Mapping a feed

What a part-intelligence feed or PLM export provides, and the fact each field becomes. Map field by field; the battery never sees the feed itself.

| Feed field | Fact | Notes |
|---|---|---|
| BOM line items | `relation(Bom, includes, Part)` | One per part on the bill of materials |
| Lifecycle stage | `attribute(Part, lifecycle, Stage)` | Map the feed's stages onto `active`, `nrnd`, `eol` and `obsolete`, or keep its own names and list them in the policy's `blocks_lifecycle` and `warns_lifecycle` |
| Estimated end-of-life date | `attribute(Part, eol_day, Date)` | The ISO date as delivered, or a day number |
| Last-time-buy date | `attribute(Part, ltb_day, Date)` | Same forms as `eol_day` |
| Compliance flags (RoHS, REACH, …) | `attribute(Part, rohs, compliant)`, one per flag | The attribute name is the flag a policy names in `requires`. Only `compliant`, `true`, `yes` and `qualified` pass; decide how the feed's other values (exemptions, unknown, not assessed) map before asserting |
| Qualification (AEC-Q100, AEC-Q200, …) | `attribute(Part, aec_qualified, true)`, one per qualification | Same rule as a compliance flag; name the attribute after the qualification the policy requires |
| Supplier or source list | `relation(Part, sourced_from, Supplier)`, one per supplier | Duplicates collapse; `source_count` counts distinct suppliers |
| Form-fit-function alternates | `relation(Part, cross, Alt)` | `part_alternate` judges the alternate on its own facts, so assert its lifecycle and flags too |

Fields a policy does not name are ignored, so assert what the feed has. The clock is not a feed field: assert `today`'s `date` at query time.

## Setup

### The BOM and its parts

```
{ type="relation", subject="board_a", relation="includes", object="mcu_1" }
{ type="relation", subject="board_a", relation="includes", object="cap_7" }

{ type="attribute", entity="mcu_1", attribute="lifecycle",     value="active" }
{ type="attribute", entity="mcu_1", attribute="rohs",          value="compliant" }
{ type="attribute", entity="mcu_1", attribute="aec_qualified", value=true }
{ type="attribute", entity="mcu_1", attribute="eol_day",       value="2026-02-16" }
{ type="relation",  subject="mcu_1", relation="sourced_from", object="supplier_x" }
{ type="relation",  subject="mcu_1", relation="sourced_from", object="supplier_y" }
{ type="relation",  subject="mcu_1", relation="cross",        object="mcu_1b" }

{ type="attribute", entity="today", attribute="date", value="2024-10-04" }
```

### A policy

```
{ type="relation",  subject="auto", relation="requires", object="rohs" }
{ type="relation",  subject="auto", relation="requires", object="aec_qualified" }
{ type="attribute", entity="auto",  attribute="min_sources",      value=2 }
{ type="attribute", entity="auto",  attribute="eol_horizon_days", value=730 }
```

### A waiver

```prolog
part_exempt(board_a, cap_7).
```

## Querying

```
# Does the board pass the automotive policy?
bom_compliant(board_a, auto)

# Everything wrong with it, by part and reason
bom_violation(board_a, auto, Part, Reason)

# What to buy before it is too late, and how many days are left
last_time_buy_due(board_a, auto, Part, DaysLeft)

# A usable replacement for an obsolete part
part_alternate(reg_old, auto, Alt)

# The one-line status
bom_risk_summary(board_a, auto, Blocked, Warned, Ok)
```

## Agent Use Cases

**Design review gate.** Before a BOM is released, `bom_compliant(Bom, Policy)` is the answer and `bom_violation/4` is the list of what to fix. With `why/2` the review shows which fact ruled each part out.

**Obsolescence sweep.** `last_time_buy_due/4` across every BOM in a namespace is the buy list, ordered by days left; `part_alternate/3` gives the redesign option beside each.

**Feed refresh.** Re-assert the part attributes from the intelligence feed on a schedule; nothing in the rules changes. A part that moved from `active` to `nrnd` shows up in the next query.

**Policy change.** A new market means a new policy: assert its `requires` flags and thresholds. Every BOM is judged against it on the next query.

## Design Note

The battery knows nothing about any particular feed or standard. It knows that a policy names flags, stages and thresholds, and that a part carries facts. Everything a feed provides that a policy does not name is ignored; everything a policy names that a feed does not provide is `missing`, which is the honest answer. Blocking and warning are kept separate so a BOM with parts nearing end of life is still buildable today and still visible in the buy list.
