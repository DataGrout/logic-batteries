# Module: faction v1.0.1

Reputation as a number, standing as a tier derived from it, alliances and wars
between factions, and area access gated on standing.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["faction"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("faction", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `faction_reputation(Player, Faction, Rep)` | The score; 0 when none is set |
| `faction_standing(Player, Faction, Standing)` | The tier the score falls in — see thresholds |
| `faction_allied(F1, F2)` | `allied_with` in either direction |
| `faction_at_war(F1, F2)` | `at_war_with` in either direction |
| `faction_access(Player, Area)` | Standing with the area's faction is at least `requires_standing`, or, without one, anything but `hostile` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `score` | `<player>_<faction>` | number | Reputation, on a composite entity: `alice_traders_guild`. Absent reads as 0 |
| `requires_faction` | area | a faction id | Whose standing gates the area |
| `requires_standing` | area | a standing | Minimum tier to enter. Without it, any non-`hostile` standing will do |
| `exalted_threshold` | `faction` | number | Score at or above which standing is `exalted`; default 21000 |
| `revered_threshold` | `faction` | number | Default 12000 |
| `honored_threshold` | `faction` | number | Default 9000 |
| `friendly_threshold` | `faction` | number | Default 3000. Between `unfriendly_threshold` and this, exclusive, is `neutral` |
| `unfriendly_threshold` | `faction` | number | Scores at or below this are `unfriendly`; default −3000 |
| `hostile_threshold` | `faction` | number | Scores at or below this are `hostile`; default −6000 |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `allied_with` | faction → faction | Read symmetrically; one fact is enough |
| `at_war_with` | faction → faction | Read symmetrically |

`faction` is a fixed entity name for the thresholds; each is optional and
global — there is no per-faction override, whatever the source comments say.

## Standing Tiers

Lowest to highest: `hostile` → `unfriendly` → `neutral` → `friendly` →
`honored` → `revered` → `exalted`.

| Standing | Score (defaults) |
|---|---|
| `exalted` | ≥ 21000 |
| `revered` | ≥ 12000 |
| `honored` | ≥ 9000 |
| `friendly` | ≥ 3000 |
| `neutral` | −2999 to 2999 |
| `unfriendly` | −5999 to −3000 |
| `hostile` | ≤ −6000 |

Every tier reads the same way: a score at or beyond its threshold, on either
side of zero. Neutral is the band between the friendly and unfriendly
thresholds.

## Setup

```
# Reputation, on <player>_<faction>
{ type="attribute", entity="alice_traders_guild", attribute="score", value=5000 }
{ type="attribute", entity="alice_bandits",       attribute="score", value=-7000 }

# Between factions
{ type="relation", subject="traders_guild", relation="allied_with", object="merchants_guild" }
{ type="relation", subject="bandits",       relation="at_war_with", object="kingdom" }

# Areas
{ type="attribute", entity="guild_hall",  attribute="requires_faction",  value="traders_guild" }
{ type="attribute", entity="inner_vault", attribute="requires_faction",  value="traders_guild" }
{ type="attribute", entity="inner_vault", attribute="requires_standing", value="honored" }

# Tuning (optional)
{ type="attribute", entity="faction", attribute="friendly_threshold", value=1000 }
```

## Querying

```
# Where does alice stand?
faction_standing(alice, traders_guild, S)
   S = friendly
faction_standing(alice, bandits, S)
   S = hostile

# May she enter? (the hall wants non-hostile; the vault wants honored)
faction_access(alice, guild_hall)
faction_access(alice, inner_vault)
   false

# Everywhere she may go
faction_access(alice, Area)
```

From Tether, in a loop that already speaks it:

```lua
dg:assert("my-game", { type="attribute", entity=player.Name .. "_" .. faction, attribute="score", value=score })
dg:query("my-game", "faction_access(" .. player.Name .. ", inner_vault)", function(r) if #r > 0 then teleport(player, vault) end end)
```

## Semantics worth knowing

**Alliances and wars are facts about factions, not about players.** Nothing
here derives a player's standing with an ally from their standing with the
faction; if allied standing should carry over, compute it yourself from
`faction_allied` and `faction_reputation`.

**Composite keys.** `<player>_<faction>` joins with `_`, so a player id
containing `_` can collide with another player-faction pair. Keep ids free of
`_`.

## What this battery does not do

- No reputation changes — assert the new `score`.
- No spill-over between allied or warring factions.
- No per-faction thresholds.

## Changes

**1.0.1** — negative standings mirror the positive thresholds. Scores between
`unfriendly_threshold` and `hostile_threshold` were matched by neither rule
and fell through to `neutral`; now anything at or below `unfriendly_threshold`
is `unfriendly`, and at or below `hostile_threshold` is `hostile`. Small
negative scores (above `unfriendly_threshold`) are now `neutral` rather than
`unfriendly`.
