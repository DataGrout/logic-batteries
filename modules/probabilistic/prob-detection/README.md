# Module: prob-detection v1.0.0

Probabilistic guard perception and stealth. Layers ProbLog-annotated detection probabilities on top of combat line-of-sight, so the game can answer "what is the probability this guard sees the player right now?" in a single zero-token query.

**Requires:** `combat` installed in the same namespace.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["combat", "prob-detection"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"combat", "prob-detection"}, "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `detected(Guard, Player)` | Probabilistic: Guard detects Player (use with ProbLog inference) |
| `detection_probability(Guard, Player, P)` | P is probability (0.0–1.0) Guard detects Player right now |
| `stealth_success(Guard, Player)` | True when detection probability < 0.5 |
| `environmental_detection_factor(Guard, Factor)` | Aggregate environmental modifier (0.0–1.0) |

## Setup

```lua
-- Guard stats
dg:assert("my-game", { type="attribute", entity="guard_a", attribute="perception", value=9 })
dg:assert("my-game", { type="attribute", entity="guard_a", attribute="alert_state", value="active" })
dg:assert("my-game", { type="attribute", entity="guard_a", attribute="faction", value="city_watch" })

-- Player stealth
dg:assert("my-game", { type="attribute", entity="player", attribute="stealth_bonus", value=4 })

-- World conditions
dg:assert("my-game", { type="attribute", entity="world", attribute="light_level", value="dark" })
dg:assert("my-game", { type="attribute", entity="world", attribute="weather", value="rain" })
```

## Usage

```lua
-- What is the detection probability for a specific guard?
dg:query("my-game", "detection_probability(guard_a, player, P)", function(results)
  if results[1] then
    print(string.format("Detection chance: %.0f%%", results[1].P * 100))
    -- "Detection chance: 38%" (reduced by dark + rain + stealth_bonus)
  end
end)

-- Can the player safely pass this guard?
dg:query("my-game", "stealth_success(guard_a, player)", function(results)
  if #results > 0 then
    print("Safe to pass")
  else
    print("Too risky")
  end
end)

-- ProbLog marginal probability query
dg:query("my-game", "probability(detected(guard_a, player), P)", function(results)
  if results[1] then
    -- pulse a tension indicator proportional to P
    setTensionLevel(results[1].P)
  end
end)
```

## Detection Rules

| Condition | Probability |
|---|---|
| High perception (>8) + active alert | 0.95 |
| Medium perception (5–8) + active alert | 0.75 |
| Low perception (≤5) + active alert | 0.45 |
| High perception + passive | 0.60 |
| Medium perception + passive | 0.35 |
| Low perception + passive | 0.15 |
| Player wearing matching faction disguise | 0.10 |

## Environmental Modifiers

These multiply into `detection_probability/3`:

| World attribute | Factor |
|---|---|
| `light_level = dark` | ×0.50 |
| `light_level = dim` | ×0.75 |
| `weather = rain` | ×0.80 |
| `weather = fog` | ×0.85 |
| `noise_level = loud` | ×1.30 |

Player `stealth_bonus` (0–10 scale) reduces detection by ~7% per point.
