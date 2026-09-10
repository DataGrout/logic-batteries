# Module: world v1.0.0

Time of day, weather, season and moon phase as facts on one entity, with
defaults, so every other battery reads the same world.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["world"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("world", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `world_time(Period)` | `time_of_day` if set, else derived from `hour`, else `day` |
| `world_weather(Condition)` | `weather`, default `clear` |
| `world_season(Season)` | `season`, default `summer` |
| `world_moon(Phase)` | `moon_phase`, default `crescent` |
| `is_daytime` | Period is `dawn` or `day` |
| `is_nighttime` | Period is `dusk` or `night` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `time_of_day` | `world` | `dawn` \| `day` \| `dusk` \| `night` | The period, set explicitly. Takes precedence over `hour` |
| `hour` | `world` | 0–23 | The period is derived: 5–6 dawn, 7–17 day, 18–20 dusk, otherwise night |
| `weather` | `world` | `clear` \| `rain` \| `storm` \| `fog` \| `snow` | Nothing validates the value; any atom is returned as asserted |
| `season` | `world` | `spring` \| `summer` \| `autumn` \| `winter` | Likewise |
| `moon_phase` | `world` | `new` \| `crescent` \| `quarter` \| `gibbous` \| `full` | Likewise |

`world` is a fixed entity name. Every attribute is optional; the defaults are
`day`, `clear`, `summer`, `crescent`.

## Setup

```
# Either the period…
{ type="attribute", entity="world", attribute="time_of_day", value="night" }
# …or the hour, and let the period follow
{ type="attribute", entity="world", attribute="hour", value=22 }

{ type="attribute", entity="world", attribute="weather",    value="storm" }
{ type="attribute", entity="world", attribute="season",     value="winter" }
{ type="attribute", entity="world", attribute="moon_phase", value="full" }
```

Update these on a tick or when conditions change; asserting a new value for
the same attribute replaces the reading.

## Querying

```
world_time(T)
   T = night

is_nighttime

world_weather(W), world_moon(M)
   W = storm, M = full
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "is_nighttime", function(r) if #r > 0 then spawnNightEnemies() end end)
```

## Semantics worth knowing

**Set the period or the hour, not both.** An explicit `time_of_day` wins
outright; a stale one will mask a live `hour`.

**Other batteries read the facts, not the predicates.** `loot-tables` checks
`attribute(world, time_of_day, night)` directly, so a world driven only by
`hour` will not satisfy a `time(night)` loot condition. When another battery
reads `time_of_day`, assert the period.

## Why a Separate Battery

One authoritative place for world state means every battery that branches on
time or weather reads the same facts, and one assert updates all of them.
