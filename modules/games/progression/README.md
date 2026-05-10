# Module: progression v1.0.0

XP thresholds, level-up detection, stat scaling, unlocks, and prestige conditions.

## Install

```lua
dg:batteries().install("progression", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

> Lua examples use [Tether](https://github.com/datagrout/tether), the Lua client for DataGrout.

## Exported Predicates

| Predicate | Description |
|---|---|
| `level_for_xp(XP, Level)` | Level a player with XP total experience has reached |
| `xp_to_next_level(Player, Needed)` | XP remaining until Player's next level |
| `stat_at_level(Stat, Level, Value)` | Value of Stat at a given Level |
| `unlock_available(Player, Unlock)` | Unlock is available at Player's current level |
| `can_prestige(Player)` | Player meets all configured prestige conditions |

## XP Curves

Three curve types, all configured with attribute facts. Default is linear.

### Linear (default)

```lua
-- Level 2 costs 100 XP, each subsequent level costs 50 more
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="type",      value="linear" })
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="base_xp",   value=100 })
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="increment", value=50 })
-- → Level 2: 100 total, Level 3: 250, Level 4: 450, ...
```

### Exponential

```lua
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="type",       value="exponential" })
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="base_xp",    value=100 })
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="multiplier", value=1.5 })
-- → Level 2: 100 total, Level 3: 250, Level 4: 475, ...
```

### Custom breakpoints

```lua
-- Explicit cumulative XP per level — overrides curve math entirely
dg:assert("my-game", { type="attribute", entity="level_2", attribute="xp_required", value=100 })
dg:assert("my-game", { type="attribute", entity="level_3", attribute="xp_required", value=300 })
dg:assert("my-game", { type="attribute", entity="level_4", attribute="xp_required", value=700 })
```

### Max level

```lua
dg:assert("my-game", { type="attribute", entity="xp_curve", attribute="max_level", value=50 })
-- default: 100
```

## Stat Scaling

```lua
-- Linear: value = base + (level - 1) * per_level
dg:assert("my-game", { type="attribute", entity="strength", attribute="base_value", value=10 })
dg:assert("my-game", { type="attribute", entity="strength", attribute="per_level",  value=5 })

-- Exponential: value = round(base * multiplier ^ (level - 1))
dg:assert("my-game", { type="attribute", entity="magic_power", attribute="scale",      value="exponential" })
dg:assert("my-game", { type="attribute", entity="magic_power", attribute="base_value", value=10 })
dg:assert("my-game", { type="attribute", entity="magic_power", attribute="multiplier", value=1.2 })

-- Custom per-level value (overrides formula)
dg:assert("my-game", { type="attribute", entity="max_hp", attribute="level_1", value=100 })
dg:assert("my-game", { type="attribute", entity="max_hp", attribute="level_2", value=150 })
dg:assert("my-game", { type="attribute", entity="max_hp", attribute="level_3", value=220 })
```

## Unlocks

```lua
-- Unlock available at or above a level threshold
dg:assert("my-game", { type="attribute", entity="double_jump",   attribute="requires_level", value=5  })
dg:assert("my-game", { type="attribute", entity="fire_spell",    attribute="requires_level", value=10 })
dg:assert("my-game", { type="attribute", entity="prestige_mode", attribute="requires_level", value=50 })
```

## Prestige

```lua
-- Require max level before prestige is available
dg:assert("my-game", { type="attribute", entity="prestige", attribute="requires_max_level", value=true })

-- Or require a specific level + a completed quest
dg:assert("my-game", { type="attribute", entity="prestige", attribute="requires_level", value=50 })
dg:assert("my-game", { type="attribute", entity="prestige", attribute="requires_quest", value="defeat_final_boss" })
```

## Usage

```lua
-- What level is alice at 850 XP?
dg:query("my-game", "level_for_xp(850, Level)", function(results)
  if results[1] then setPlayerLevel(results[1].Level) end
end)

-- How much XP does alice need to level up?
dg:query("my-game", "xp_to_next_level(alice, Needed)", function(results)
  if results[1] then showXPBar(results[1].Needed) end
end)

-- What is alice's strength at her current level?
dg:query("my-game", "player_level(alice, L), stat_at_level(strength, L, V)", function(results)
  if results[1] then applyStrengthBonus(results[1].V) end
end)

-- What has alice unlocked?
dg:query("my-game", "unlock_available(alice, Unlock)", function(results)
  for _, r in ipairs(results) do grantUnlock(r.Unlock) end
end)

-- Can alice prestige?
dg:query("my-game", "can_prestige(alice)", function(results)
  if #results > 0 then showPrestigeButton() end
end)
```

## Composing with Other Modules

Works naturally with `combat` (stat values feed damage calculations), `quests` (prestige quest gates), and `inventory` (level-locked equipment).
