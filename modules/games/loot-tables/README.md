# Module: loot-tables v1.0.0

What a source can drop, under which world conditions, at what chance. Rarity
tiers give default chances; conditions are terms evaluated against world facts.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["loot-tables"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("loot-tables", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `drops(Source, Item)` | The source `can_drop` the item, conditions aside |
| `drops_at(Source, Item, Conditions)` | The item's `loot_conditions` list, for items that have one |
| `eligible_loot(Source, Item)` | Drops, and every condition holds against `world` right now |
| `rarity_tier(Item, Tier)` | The item's `rarity`; `common` when unset |
| `condition_met(Condition, Context)` | One condition term, evaluated against a context entity |
| `loot_chance(Source, Item, Pct)` | `drop_chance` if set, else the tier's default |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `rarity` | item | `common` \| `uncommon` \| `rare` \| `epic` \| `legendary` | Selects the default chance. Default `common` |
| `drop_chance` | item | 0–100 | Overrides the tier default for this item |
| `loot_conditions` | item | a Prolog list of condition terms | e.g. `[time(night), weather(rain)]`. All must hold. Must be a real list term — a quoted string is never satisfied |
| `time_of_day` | `world` | any | Matched by `time(T)` |
| `weather` | `world` | any | Matched by `weather(W)` |
| `moon_phase` | `world` | any | Matched by `moon(M)` |
| `level` | context | integer | Matched by `player_level_gte(N)` when the context is a player |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `can_drop` | source → item | The drop table entry |
| `has_item` | context → item | Matched by `player_has(Item)` when the context is a player |

`world` is a fixed entity name; `eligible_loot` always evaluates conditions
against it.

## Conditions

| Term | Holds when |
|---|---|
| `time(T)` | `world` has `time_of_day = T` |
| `weather(W)` | `world` has `weather = W` |
| `moon(M)` | `world` has `moon_phase = M` |
| `player_level_gte(N)` | the context has `level ≥ N` |
| `player_has(Item)` | the context `has_item` Item |
| `always` | always |

## Default Chances by Rarity

| Tier | Chance |
|---|---|
| `common` | 70 |
| `uncommon` | 30 |
| `rare` | 10 |
| `epic` | 3 |
| `legendary` | 1 |

## Setup

```
# The table
{ type="relation",  subject="cave_chest", relation="can_drop", object="gold_coin" }
{ type="relation",  subject="cave_chest", relation="can_drop", object="rare_gem" }
{ type="attribute", entity="rare_gem",    attribute="rarity",  value="rare" }

# A conditional drop
{ type="relation",  subject="lake",      relation="can_drop",        object="rare_fish" }
{ type="attribute", entity="rare_fish",  attribute="rarity",          value="uncommon" }
{ type="attribute", entity="rare_fish",  attribute="loot_conditions", value=[time(night), weather(rain)] }

# An explicit chance
{ type="attribute", entity="gold_coin", attribute="drop_chance", value=95 }

# The world, kept current by you
{ type="attribute", entity="world", attribute="time_of_day", value="night" }
{ type="attribute", entity="world", attribute="weather",     value="rain" }
```

## Querying

```
# What can this chest give right now?
eligible_loot(cave_chest, Item)

# At what odds?
loot_chance(cave_chest, rare_gem, Pct)
   Pct = 10

# Is the fish on tonight?
eligible_loot(lake, rare_fish)

# A player-scoped condition, checked directly
condition_met(player_level_gte(10), alice)
```

Rolling is yours: take each eligible item with its chance and compare against
your own random number.

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "eligible_loot(cave_chest, I), loot_chance(cave_chest, I, C)", function(rs)
  for _, r in ipairs(rs) do if math.random(100) <= r.C then spawnItem(r.I) end end
end)
```

## Semantics worth knowing

**`eligible_loot` knows nothing about the player.** Its context is always
`world`, so `player_level_gte` and `player_has` inside `loot_conditions` look
for `level` and `has_item` on the `world` entity and fail. Use those two only
through `condition_met(Cond, Player)` directly, or gate player-specific loot
yourself before asking `eligible_loot`.

**Conditions are terms, not strings.** `loot_conditions` is walked as a list;
the value has to reach the cell as `[time(night), weather(rain)]`, not as text.
How that is encoded depends on your client — confirm one conditional drop
works before relying on it.

**Chance is per item, not per source.** `loot_chance` ignores its `Source`
argument; the same item drops at the same odds everywhere.

## What this battery does not do

- No rolling or selection; it reports odds.
- No per-source chance, quantity, or pity timers.
- No player-aware eligibility through `eligible_loot`.
