# Module: risk-assessment v1.0.1

Should this character fight that enemy? A simple turn-trade model over `hp`
and `base_damage` gives a survival probability, a recommendation, and how many
of an enemy a character can chain before dropping — at zero token cost.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["risk-assessment"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("risk-assessment", "my-game", cb)`.

No dependencies. It reads the same `hp` attribute `combat` does, so the two
compose on the same entities, but nothing here calls `combat`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `survival_probability(Player, Enemy, HP, P)` | P in 0.05–0.99; HP is what the player has left, floored at 0 |
| `recommended_action(Player, Enemy, Action)` | `fight` when P > 0.6, else `flee` |
| `kills_to_exhaust(Player, Enemy, MaxHP, N)` | How many of the enemy the player can kill in sequence starting from MaxHP; at least 1 |
| `fight_outcome_summary(Player, Enemy, Turns, Damage, P)` | Turns to kill, total damage taken, and P |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `hp` | player, enemy | number | Hit points. Both sides need one; the same attribute `combat` reads |
| `base_damage` | player, enemy | number | Damage dealt per turn. Must be above 0 on both sides or every predicate fails |

## The Model

```
Turns  = ceiling(EnemyHP / PlayerDamage)
Damage = Turns × EnemyDamage
if Damage <  PlayerHP:  P = min(0.99, 1 − (Damage / PlayerHP) × 0.5)
if Damage >= PlayerHP:  P = max(0.05, 0.5 − (Damage − PlayerHP) / (2 × PlayerHP))
```

Both sides hit every turn for exactly `base_damage`; the enemy gets a full
`Turns` of hits in. No armor, dodge, initiative, or variance — those are what
you would extend it with.

## Setup

```
{ type="attribute", entity="player",      attribute="hp",          value=80 }
{ type="attribute", entity="player",      attribute="base_damage", value=15 }
{ type="attribute", entity="goblin",      attribute="hp",          value=30 }
{ type="attribute", entity="goblin",      attribute="base_damage", value=10 }
{ type="attribute", entity="warden_boss", attribute="hp",          value=200 }
{ type="attribute", entity="warden_boss", attribute="base_damage", value=45 }
```

## Querying

```
# The goblin: 2 turns, 20 damage taken
recommended_action(player, goblin, Action)
   Action = fight
survival_probability(player, goblin, HP, P)
   HP = 60, P = 0.875

# The boss: 14 turns, 630 damage taken
fight_outcome_summary(player, warden_boss, Turns, Damage, P)
   Turns = 14, Damage = 630, P = 0.05
recommended_action(player, warden_boss, Action)
   Action = flee

# Goblins before the player drops, from 80 HP
kills_to_exhaust(player, goblin, 80, N)
   N = 4
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "fight_outcome_summary(player, " .. enemy .. ", T, D, P)", function(r) if r[1] then setDangerGlow(1 - r[1].P) end end)
```

## Semantics worth knowing

**`kills_to_exhaust` takes the HP you pass, not the player's `hp` fact.** That
is deliberate: ask about a full-health run or a wounded one without asserting.

**Zero damage is a failure, not zero.** A side with `base_damage = 0` makes
every predicate fail rather than answer "never".

**P is bounded, not probabilistic.** It is a score in 0.05–0.99 derived from
the damage ratio; treat the number as a ranking, not as odds.

## What this battery does not do

- No armor, resistances, or status effects — see `combat` for those, and
  compute an effective damage to pass in if you want them reflected.
- No randomness; two identical queries always agree.

## Changes

**1.0.1** — the declared dependency on `combat` was removed; no predicate here
ever called it.
