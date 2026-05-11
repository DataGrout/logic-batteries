# Module: ai-director v1.0.0

Dynamic difficulty and pacing for games. Derives pacing state from zone threat levels, adjusts difficulty multipliers, controls enemy spawn eligibility, and fires director events at pacing transitions.

Inspired by the AI Director pattern from Left 4 Dead — threat rises as enemies spawn and players are pressured, recovery kicks in to give breathing room, then the cycle repeats.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["ai-director"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("ai-director", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `threat_level(Zone, Level)` | Current threat score for Zone (0 if unset) |
| `pacing_state(Zone, State)` | Derived pacing: `calm`/`building`/`tense`/`peak`/`recovery` |
| `difficulty_modifier(Zone, Modifier)` | Numeric multiplier for Zone's current pacing state |
| `spawn_eligible(Enemy, Zone)` | Enemy may spawn in Zone given current threat and pacing |
| `director_event(Zone, Event)` | Event triggered by the director at the current pacing state |

## Pacing States

| State | Threat range (defaults) | Modifier |
|---|---|---|
| `recovery` | < 5 | 0.5 |
| `calm` | 5–19 | 0.7 |
| `building` | 20–49 | 1.0 |
| `tense` | 50–79 | 1.3 |
| `peak` | ≥ 80 | 1.6 |

All thresholds and modifiers are configurable.

## Setup

### Zone threat

Update threat as game state changes — enemy spawns raise it, kills lower it:

```lua
local ns = "my-game"

-- Set current threat for a zone
dg:assert(ns, { type="attribute", entity="forest_zone", attribute="threat", value=45 })
```

### Enemy spawn rules

```lua
-- Goblin: spawns between threat 10 and 60 in forest_zone
dg:assert(ns, { type="attribute", entity="goblin", attribute="spawn_zone",  value="forest_zone" })
dg:assert(ns, { type="attribute", entity="goblin", attribute="min_threat",  value=10 })
dg:assert(ns, { type="attribute", entity="goblin", attribute="max_threat",  value=60 })

-- Dragon: spawns anywhere at high threat, no max
dg:assert(ns, { type="attribute", entity="dragon", attribute="min_threat",  value=70 })
```

### Director events

```lua
dg:assert(ns, { type="attribute", entity="director", attribute="peak_event",     value="boss_spawn"    })
dg:assert(ns, { type="attribute", entity="director", attribute="recovery_event", value="treasure_chest" })
```

### Custom thresholds and modifiers

```lua
dg:assert(ns, { type="attribute", entity="director", attribute="peak_threshold",      value=75 })
dg:assert(ns, { type="attribute", entity="director", attribute="peak_modifier",       value=2.0 })
dg:assert(ns, { type="attribute", entity="director", attribute="recovery_modifier",   value=0.4 })
```

## Querying

```lua
-- Poll pacing state every few seconds; adjust music/atmosphere
dg:query(ns, "pacing_state(forest_zone, State)", function(result)
  setAtmosphere(result.State)
end)

-- Check spawn eligibility before spawning an enemy
dg:query(ns, "spawn_eligible(goblin, forest_zone)", function(result)
  if result then spawnEnemy("goblin") end
end)

-- Get difficulty multiplier to scale damage/HP
dg:query(ns, "difficulty_modifier(forest_zone, M)", function(result)
  applyDifficultyScale(result.M)
end)

-- Fire director event when pacing transitions
dg:query(ns, "director_event(forest_zone, Event)", function(result)
  if result then fireEvent(result.Event) end
end)
```

## Design Notes

Enemies never spawn in `recovery` — the director enforces breathing room regardless of individual spawn rules. This prevents the common "endless grind" feel where spawns never let up.

The director works best when threat is updated continuously rather than in large discrete jumps. A good pattern: +5 threat when an enemy spawns, -3 when an enemy dies, -10 on zone clear.
