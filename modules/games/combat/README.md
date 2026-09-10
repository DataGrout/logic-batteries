# Module: combat v1.0.0

Damage after resistances, armor and buffs; whether an attack is allowed; status
effects; turn order; defeat. Stats and statuses are facts you assert; the
battery computes, it never applies damage.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["combat"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("combat", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `effective_damage(Attacker, Target, Base, Final)` | `Base × buffs × resistance − armor`, rounded, floored at 0 |
| `can_attack(Attacker, Target)` | Neither is defeated, the attacker is not stunned/frozen/sleeping, and the target is not out of range |
| `status_effect_active(Entity, Effect)` | Entity has a `status` fact with that value |
| `turn_order(Combatants, Ordered)` | Fastest first; ties by name |
| `is_defeated(Entity)` | `hp` is 0 or below |
| `resistance(Entity, DamageType, Factor)` | The multiplier applied to that damage type against the entity — see precedence |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `hp` | entity | number | Hit points. `≤ 0` is defeated |
| `speed` | entity | number | Turn order key, highest first; default 0 |
| `status` | entity | an effect id | One fact per active effect. `stunned`, `frozen` and `sleeping` prevent attacking; any other value is just reported by `status_effect_active` |
| `element` | entity | a damage type | The entity's own type, matched against the type chart when it is the *target* |
| `armor` | target | number | Flat reduction after buffs and resistance |
| `armor_type` | target | a damage type | Optional: armor applies only to this damage type. Without it, armor applies to everything |
| `damage_type` | attacker | a damage type | What the attacker deals; default `physical` |
| `buff_damage` | attacker | multiplier | Default 1.0 |
| `debuff_damage` | attacker | multiplier | Default 1.0. Both multiply the base together |
| `immune_<type>` | target | any | Damage of `<type>` does 0. Highest precedence |
| `resist_<type>` | target | multiplier | Damage of `<type>` is multiplied by this (e.g. 0.5) |
| `weak_<type>` | target | multiplier | Likewise (e.g. 2.0). `immune_fire`, `resist_fire`, `weak_fire` are the attribute names for fire — built from the damage type at query time |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `strong_against` | damage type → element | Type chart: this damage does ×2.0 to targets of that `element` |
| `weak_against` | damage type → element | Type chart: ×0.5 |
| `out_of_range` | attacker → target | The attacker cannot reach the target this turn |

## Resistance Precedence

For one target and one damage type, the first rule that matches wins:

1. `immune_<type>` → 0
2. `resist_<type>` → its value
3. `weak_<type>` → its value
4. type chart, `strong_against` the target's `element` → 2.0
5. type chart, `weak_against` the target's `element` → 0.5
6. otherwise 1.0

## Setup

```
# Stats
{ type="attribute", entity="goblin", attribute="hp",    value=40 }
{ type="attribute", entity="goblin", attribute="speed", value=8 }
{ type="attribute", entity="knight", attribute="hp",    value=120 }
{ type="attribute", entity="knight", attribute="speed", value=5 }
{ type="attribute", entity="knight", attribute="armor", value=10 }

# Damage types and the type chart
{ type="attribute", entity="fire_mage", attribute="damage_type", value="fire" }
{ type="attribute", entity="ice_golem", attribute="element",     value="ice" }
{ type="relation",  subject="fire",      relation="strong_against", object="ice" }
{ type="relation",  subject="fire",      relation="weak_against",   object="water" }

# Per-entity resistances; the type is part of the attribute name
{ type="attribute", entity="goblin", attribute="resist_fire", value=0.5 }
{ type="attribute", entity="goblin", attribute="weak_water",  value=2.0 }
{ type="attribute", entity="dragon", attribute="immune_fire", value=true }

# Status effects: one `status` fact per effect, on the affected entity
{ type="attribute", entity="goblin", attribute="status", value="poisoned" }
{ type="attribute", entity="knight", attribute="status", value="stunned" }
```

## Querying

```
# Damage before applying it
effective_damage(fire_mage, ice_golem, 50, Final)
   Final = 100

# Who acts first?
turn_order([goblin, knight, fire_mage], Ordered)
   Ordered = [goblin, knight, fire_mage]

# Is this attack allowed? (knight is stunned)
can_attack(knight, goblin)
   false

# Anyone down?
is_defeated(Entity)

# What does fire do to the golem?
resistance(ice_golem, fire, Factor)
   Factor = 2.0
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "effective_damage(fire_mage, ice_golem, 50, F)", function(r) if r[1] then applyDamage("ice_golem", r[1].F) end end)
```

## Semantics worth knowing

**Statuses are attributes on the entity, not entities of their own.** The
shape is `attribute(knight, status, stunned)`; a `has_status` relation to a
`stunned` entity with `active` or `prevents` attributes is not read by any
clause and does nothing. Only the three names `stunned`, `frozen`, `sleeping`
block attacking; a status with any other name is inert here. Remove a status by
retracting the fact — there is no duration tracking.

**Immunity ignores its value.** Any `immune_<type>` fact, whatever its value,
makes the factor 0.

**Armor is flat, after multipliers.** `50 × 1.5 × 2.0 − 10`, not
`(50 − 10) × …`. With `armor_type` set, armor applies only to that type.

**Type chart direction.** `relation(fire, strong_against, ice)` means fire
*damage* hurts *ice-element targets* more. It is read from the target's
`element`, never from the attacker's.

## Composing with Other Modules

`progression` for stat values, `inventory` for what sets `damage_type`,
`npc-state` for who counts as hostile.
