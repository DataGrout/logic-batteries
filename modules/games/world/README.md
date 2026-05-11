# Module: world v1.0.0

Time of day, weather, season, and moon phase as queryable facts. Assert world state once per server tick; every other battery reads it automatically.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["world"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("world", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `world_time(Period)` | Current period: `dawn`/`day`/`dusk`/`night` |
| `world_weather(Condition)` | Current weather: `clear`/`rain`/`storm`/`fog`/`snow` |
| `world_season(Season)` | Current season: `spring`/`summer`/`autumn`/`winter` |
| `world_moon(Phase)` | Moon phase: `new`/`crescent`/`quarter`/`gibbous`/`full` |
| `is_daytime` | Succeeds during `dawn` and `day` |
| `is_nighttime` | Succeeds during `dusk` and `night` |

## Setup

Assert world state as attributes on the atom `world`. Update these on a server tick or whenever conditions change.

```lua
local ns = "my-game"

-- Time of day (explicit period)
dg:assert(ns, { type="attribute", entity="world", attribute="time_of_day", value="night" })

-- Or assert the hour and let the module derive the period
dg:assert(ns, { type="attribute", entity="world", attribute="hour", value=22 })
-- 22:00 → night (dawn 5–6, day 7–17, dusk 18–20, night otherwise)

-- Weather, season, moon
dg:assert(ns, { type="attribute", entity="world", attribute="weather",    value="storm"  })
dg:assert(ns, { type="attribute", entity="world", attribute="season",     value="winter" })
dg:assert(ns, { type="attribute", entity="world", attribute="moon_phase", value="full"   })
```

**Defaults** (when no facts are asserted): `day`, `clear`, `summer`, `crescent`.

## Querying

```lua
-- Check current time period
dg:query(ns, "world_time(T)", function(result)
  print(result.T)  -- "night"
end)

-- Gate game logic on time
dg:query(ns, "is_nighttime", function(result)
  if result then spawnNightEnemies() end
end)
```

## How Other Batteries Use It

World facts are plain `attribute/3` assertions, so any battery can branch on them by reading the same namespace:

- **loot-tables**: `condition_met` checks `attribute(world, time_of_day, night)` for night-only drops
- **ai-director**: threat thresholds can be modulated by weather in custom rules
- **npc-state**: dialogue variants can check `is_daytime` for time-aware greetings

## Why a Separate Battery

Without a world battery, every game module that wants to branch on time or weather needs its own copy of the condition logic, or you end up with duplicate `attribute(world, ...)` reads scattered across modules. Centralising time/weather in a single authoritative namespace means updates propagate automatically to everything else reading the same facts.
