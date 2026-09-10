# Module: prob-loot v1.0.2

Drop odds as numbers. Wraps `loot-tables` so a game or agent can ask the
probability of a drop, the expected yield over many kills, and whether a drop is
guaranteed — and, through ProbLog, the marginal probability of `drop_occurs`.

**Requires:** `loot-tables`, for `drops/2`, `rarity_tier/2` and `loot_chance/3`.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["loot-tables", "prob-loot"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install_many({"loot-tables", "prob-loot"}, "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `drop_occurs(Source, Item)` | Probabilistic, weighted by rarity tier on the same scale as `drop_probability` |
| `guaranteed_drop(Source, Item)` | The item's `drop_chance` is 100 or more |
| `drop_probability(Source, Item, P)` | `loot-tables`' `loot_chance` as 0–1 |
| `expected_drops(Source, Item, N, Expected)` | `N × drop_probability` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `drop_chance` | item | 0–100 | At 100 or above the drop is `guaranteed_drop`. Also the per-item override `drop_probability` reads through `loot-tables` |

Everything else comes from the `loot-tables` battery: `drops/2` for the table,
`rarity_tier/2` for the tier, `loot_chance/3` for the deterministic chance. Its
facts — `can_drop`, `rarity`, `loot_conditions` — are what you assert; see its
table.

**One scale.** `drop_occurs/2`'s ProbLog weights are `loot-tables`' tier
chances as probabilities, so a marginal over `drop_occurs` and
`drop_probability/3` agree by construction. An item's `drop_chance` overrides
the tier for `drop_probability`; the annotated clauses read the tier only.

## Weights by Rarity

| Tier | Weight (`drop_occurs`) | Chance (`drop_probability`) |
|---|---|---|
| `common` | 0.70 | 70 |
| `uncommon` | 0.30 | 30 |
| `rare` | 0.10 | 10 |
| `epic` | 0.03 | 3 |
| `legendary` | 0.01 | 1 |

## Setup

```
# The table, in loot-tables' shape
{ type="relation",  subject="warden_boss", relation="can_drop", object="boss_key" }
{ type="relation",  subject="warden_boss", relation="can_drop", object="gold_coin" }
{ type="attribute", entity="boss_key",  attribute="rarity",      value="legendary" }
{ type="attribute", entity="gold_coin", attribute="rarity",      value="common" }

# A drop that always happens
{ type="attribute", entity="gold_coin", attribute="drop_chance", value=100 }
```

## Querying

```
# Deterministic odds (legendary is 1% in loot-tables)
drop_probability(warden_boss, boss_key, P)
   P = 0.01

# Over a hundred kills
expected_drops(warden_boss, boss_key, 100, E)
   E = 1.0

# Always?
guaranteed_drop(warden_boss, gold_coin)

# Marginal, through ProbLog — the same 0.01
probability(drop_occurs(warden_boss, boss_key), P)
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "drop_probability(warden_boss, boss_key, P)", function(r) if r[1] then showRate(r[1].P) end end)
```

## Semantics worth knowing

**`drop_chance` reaches one path only.** A per-item `drop_chance` changes
`drop_probability` and `guaranteed_drop`; the annotated `drop_occurs` clauses
always use the tier. An item you override will read differently through
ProbLog than through the accessor.

**`guaranteed_drop` needs a number.** A `drop_chance` of `"100"` as text does
not count; the clause checks `number/1`.

**Conditions are `loot-tables`' business.** Nothing here reads
`loot_conditions`; `drop_occurs` and `drop_probability` ignore whether the drop
is currently eligible. Check `eligible_loot` first if that matters.

## Changes

**1.0.2** — `drop_occurs` weights are now 0.70 / 0.30 / 0.10 / 0.03 / 0.01,
matching `loot-tables`. They were 0.90 / 0.65 / 0.35 / 0.10 / 0.15, which
disagreed with `drop_probability` and made legendary drops likelier than epic.
