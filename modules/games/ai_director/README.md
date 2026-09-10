# Module: ai-director v1.0.1

Dynamic difficulty and pacing. A zone's threat score becomes a pacing state,
the state becomes a difficulty multiplier and a spawn gate, and transitions can
name an event to fire. The pattern is Left 4 Dead's director: pressure builds,
recovery gives breathing room, the cycle repeats. You update threat; the
battery derives everything else.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["ai-director"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("ai-director", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `threat_level(Zone, Level)` | Current threat score for Zone; 0 when none is set |
| `pacing_state(Zone, State)` | `recovery` / `calm` / `building` / `tense` / `peak`, from the thresholds below |
| `difficulty_modifier(Zone, Modifier)` | The multiplier for Zone's current state |
| `spawn_eligible(Enemy, Zone)` | Threat is within the enemy's `min_threat`..`max_threat` and the zone is not in `recovery` |
| `director_event(Zone, Event)` | The `<state>_event` configured for the zone's current state, if any |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `threat` | zone | number | The zone's current threat. Raise it as enemies spawn and players take pressure, lower it on kills and clears. Absent reads as 0 |
| `min_threat` | enemy | number | The enemy may spawn only at or above this threat |
| `max_threat` | enemy | number | …and at or below this. Either bound is optional |
| `spawn_zone` | enemy | a zone id | Restricts the enemy to that zone; assert several for several zones. An enemy with none may spawn anywhere |
| `peak_threshold` | `director` | number | Threat at or above which the state is `peak`; default 80 |
| `tense_threshold` | `director` | number | `tense` at or above this; default 50 |
| `building_threshold` | `director` | number | `building` at or above this; default 20 |
| `recovery_threshold` | `director` | number | `recovery` *below* this; default 5. Between recovery and building is `calm` |
| `peak_modifier` | `director` | number | Difficulty multiplier in `peak`; default 1.6 |
| `tense_modifier` | `director` | number | Default 1.3 |
| `building_modifier` | `director` | number | Default 1.0 |
| `calm_modifier` | `director` | number | Default 0.7 |
| `recovery_modifier` | `director` | number | Default 0.5 |
| `peak_event`, `tense_event`, `building_event`, `calm_event`, `recovery_event` | `director` | an event id | The event `director_event` returns while the zone is in that state. Built from the state name at query time, so they do not appear in the source as literals |

`director` is a fixed entity name; every threshold, modifier and event lives on
it and is optional. Thresholds are global — there is no per-zone override.

## Pacing States

| State | Threat (defaults) | Modifier (default) |
|---|---|---|
| `recovery` | < 5 | 0.5 |
| `calm` | 5–19 | 0.7 |
| `building` | 20–49 | 1.0 |
| `tense` | 50–79 | 1.3 |
| `peak` | ≥ 80 | 1.6 |

## Setup

```
# Threat, updated as the game runs
{ type="attribute", entity="forest_zone", attribute="threat", value=45 }

# Spawn rules
{ type="attribute", entity="goblin", attribute="spawn_zone", value="forest_zone" }
{ type="attribute", entity="goblin", attribute="min_threat", value=10 }
{ type="attribute", entity="goblin", attribute="max_threat", value=60 }
{ type="attribute", entity="dragon", attribute="min_threat", value=70 }

# Events at pacing states
{ type="attribute", entity="director", attribute="peak_event",     value="boss_spawn" }
{ type="attribute", entity="director", attribute="recovery_event", value="treasure_chest" }

# Tuning (each optional)
{ type="attribute", entity="director", attribute="peak_threshold",    value=75 }
{ type="attribute", entity="director", attribute="peak_modifier",     value=2.0 }
{ type="attribute", entity="director", attribute="recovery_modifier", value=0.4 }
```

## Querying

```
# Where is the zone in the cycle?
pacing_state(forest_zone, State)
   State = building

# Scale damage and HP by it
difficulty_modifier(forest_zone, M)
   M = 1.0

# May this enemy spawn here now?
spawn_eligible(goblin, forest_zone)

# Anything the director wants fired?
director_event(forest_zone, Event)
```

From Tether, in a loop that already speaks it:

```lua
dg:assert("my-game", { type="attribute", entity="forest_zone", attribute="threat", value=threat })
dg:query("my-game", "pacing_state(forest_zone, S)", function(r) if r[1] then setAtmosphere(r[1].S) end end)
```

## Semantics worth knowing

**Nothing spawns in `recovery`.** `spawn_eligible` fails for every enemy while
the zone is below `recovery_threshold`, whatever its own bounds say. That is the
breathing room, and it is deliberate.

**Threat is yours to move.** The battery never changes `threat`; it only reads
it. A workable rhythm: +5 on spawn, −3 on kill, −10 on zone clear. Small steps
give smoother transitions than jumps.

**One director, many zones.** Thresholds and modifiers are global; threat is
per zone. Two zones with the same threat are always in the same state.

## What this battery does not do

- No per-zone thresholds or modifiers.
- No threat decay over time; lower `threat` yourself.
- No spawn *selection* — `spawn_eligible` is a filter over enemies you propose, not a picker.

## Changes

**1.0.1** — `spawn_zone` is enforced. It was read but the clause succeeded
whether or not the zone matched, so zoned enemies spawned everywhere.
