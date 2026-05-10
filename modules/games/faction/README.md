# Module: faction v1.0.0

Numeric reputation tracking, standing tier derivation, alliance and war relationships, and area access gating.

## Install

```lua
dg:batteries().install("faction", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

> Lua examples use [Tether](https://github.com/datagrout/tether), the Lua client for DataGrout.

## Exported Predicates

| Predicate | Description |
|---|---|
| `faction_reputation(Player, Faction, Rep)` | Numeric reputation score (0 if never set) |
| `faction_standing(Player, Faction, Standing)` | Standing tier derived from reputation |
| `faction_allied(F1, F2)` | Factions are allied (symmetric) |
| `faction_at_war(F1, F2)` | Factions are at war (symmetric) |
| `faction_access(Player, Area)` | Player meets the standing requirement to enter Area |

## Standing Tiers

From lowest to highest: `hostile` → `unfriendly` → `neutral` → `friendly` → `honored` → `revered` → `exalted`

Default thresholds:

| Standing | Score threshold |
|---|---|
| `exalted` | ≥ 21000 |
| `revered` | ≥ 12000 |
| `honored` | ≥ 9000 |
| `friendly` | ≥ 3000 |
| `neutral` | 0 to 2999 |
| `unfriendly` | -2999 to -1 |
| `hostile` | < -6000 |

Override any threshold globally:
```lua
dg:assert(ns, { type="attribute", entity="faction", attribute="friendly_threshold", value=1000 })
```

## Setup

### Reputation scores

Keyed as `<player>_<faction>` to avoid collisions:

```lua
local ns = "my-game"

dg:assert(ns, { type="attribute", entity="alice_traders_guild", attribute="score", value=5000 })
dg:assert(ns, { type="attribute", entity="alice_bandits",        attribute="score", value=-7000 })
```

### Faction relationships

```lua
dg:assert(ns, { type="relation", subject="traders_guild", relation="allied_with",  object="merchants_guild" })
dg:assert(ns, { type="relation", subject="bandits",       relation="at_war_with",  object="kingdom" })
```

### Area access gates

```lua
-- Requires any non-hostile standing
dg:assert(ns, { type="attribute", entity="guild_hall", attribute="requires_faction",  value="traders_guild" })

-- Requires a specific standing tier or higher
dg:assert(ns, { type="attribute", entity="inner_vault", attribute="requires_faction",  value="traders_guild" })
dg:assert(ns, { type="attribute", entity="inner_vault", attribute="requires_standing", value="honored" })
```

## Querying

```lua
-- Get alice's standing with the traders guild
dg:query(ns, "faction_standing(alice, traders_guild, S)", function(result)
  print(result.S)  -- "friendly"
end)

-- Check area access before teleporting a player
dg:query(ns, "faction_access(alice, inner_vault)", function(result)
  if result then teleport(alice, innerVault) end
end)

-- List all areas alice can enter
dg:query_all(ns, "faction_access(alice, Area)", function(results)
  for _, r in ipairs(results) do print(r.Area) end
end)
```

## Namespace Pattern for Roblox

On player join, assert the player's reputation scores from your DataStore:

```lua
local function loadFactionReps(player, data)
  for faction, score in pairs(data.factionReps) do
    local key = player.Name .. "_" .. faction
    dg:assert(ns, { type="attribute", entity=key, attribute="score", value=score })
  end
end
```

On player leave, roll up to the player's personal namespace before the server namespace is torn down.
