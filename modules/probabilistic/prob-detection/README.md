# Module: prob-detection v1.0.0

Does the guard see the player? Two answers to the same question: a
ProbLog-weighted `detected/2` for marginal inference, and a deterministic
`detection_probability/3` that multiplies perception, alertness, environment
and stealth into one number.

**Requires:** `combat`, for `detected/2` only — its rules call `can_attack/2`
to establish that the guard can reach the player. The deterministic predicates
do not use it.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["combat", "prob-detection"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install_many({"combat", "prob-detection"}, "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `detected(Guard, Player)` | Probabilistic; query its marginal with `probability(detected(G, P), X)`. Weights in the table below |
| `detection_probability(Guard, Player, P)` | Deterministic: `base × environment × stealth`, clamped to 0.01–0.99 |
| `stealth_success(Guard, Player)` | `detection_probability` below 0.5 |
| `environmental_detection_factor(_, Factor)` | Product of the environmental multipliers. The first argument is ignored; the factor is global |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `perception` | guard | 1–10 | Deterministic base is `perception / 10` (×1.3 when active), capped at 0.95. Without it the base is 0.3 passive or 0.5 active |
| `alert_state` | guard | `active` | Alerted. Any other value, or none, is passive |
| `faction` | guard | a faction id | For the disguise rule of `detected/2` |
| `stealth_bonus` | player | 0–10 | Multiplies detection by `1 − 0.07 × bonus`, floored at 0.1 |
| `disguise_faction` | uniform item | a faction id | A held item whose faction matches the guard's drops `detected/2` to 0.10 against a passive guard |
| `light_level` | `world` | `dark` \| `dim` | ×0.5 / ×0.75 |
| `weather` | `world` | `rain` \| `fog` | ×0.8 / ×0.85 |
| `noise_level` | `world` | `loud` | ×1.3 |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `has_item` | player → item | Read for the disguise rule: a held item with a matching `disguise_faction` |

`world` is a fixed entity name; the `world` battery maintains the same
attributes.

## The Two Models

**`detected/2`** — ProbLog clauses; each fires when its conditions hold and the
guard `can_attack` the player:

| Guard | Weight |
|---|---|
| perception > 8, active | 0.95 |
| perception 6–8, active | 0.75 |
| perception ≤ 5, active | 0.45 |
| perception > 8, passive | 0.60 |
| perception 6–8, passive | 0.35 |
| perception ≤ 5, passive | 0.15 |
| passive, player holds a uniform of the guard's faction | 0.10 |

**`detection_probability/3`** — arithmetic, no inference and no `combat`:

```
base   = min(0.95, perception/10 × (1.3 if active else 1.0))   (0.3 / 0.5 with no perception)
env    = product of light, weather and noise multipliers
stealth = max(0.1, 1 − 0.07 × stealth_bonus)
P      = clamp(base × env × stealth, 0.01, 0.99)
```

The two do not agree by construction; pick one per feature.

## Setup

```
{ type="attribute", entity="guard_a", attribute="perception",  value=9 }
{ type="attribute", entity="guard_a", attribute="alert_state", value="active" }
{ type="attribute", entity="guard_a", attribute="faction",     value="city_watch" }

{ type="attribute", entity="player",        attribute="stealth_bonus",     value=4 }
{ type="relation",  subject="player",       relation="has_item",           object="watch_uniform" }
{ type="attribute", entity="watch_uniform", attribute="disguise_faction",  value="city_watch" }

{ type="attribute", entity="world", attribute="light_level", value="dark" }
{ type="attribute", entity="world", attribute="weather",     value="rain" }
```

## Querying

```
# Deterministic: 0.95 × (0.5 × 0.8) × 0.72
detection_probability(guard_a, player, P)
   P = 0.2736

stealth_success(guard_a, player)

# Marginal, through ProbLog
probability(detected(guard_a, player), P)
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "detection_probability(guard_a, player, P)", function(r) if r[1] then setTension(r[1].P) end end)
```

## Semantics worth knowing

**Disguise only helps against passive guards, and only in `detected/2`.** The
deterministic path ignores `faction`, `has_item` and `disguise_faction`.

**Environment is global.** Multipliers come from `world`; there is no per-guard
or per-location lighting.

**Stealth caps at 90% reduction.** `stealth_bonus` beyond 12 changes nothing.

## What this battery does not do

- No line of sight or distance of its own; `detected/2` borrows `can_attack`,
  the deterministic path has neither.
- No per-guard environment.
