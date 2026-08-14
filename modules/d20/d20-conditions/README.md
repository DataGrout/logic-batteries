# Module: d20-conditions v1.0.0

All 15 SRD conditions and 6 exhaustion levels, with each condition's mechanical
effects queryable as facts. Plugs into `d20-combat` for advantage/disadvantage
derivation and action gating. Can also be used standalone for status UIs.

All mechanics are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-conditions"],
    "namespace": "my-campaign"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `d20_condition_active(Entity, Condition)` | Entity currently has this condition |
| `condition_effect(Condition, Effect, Value)` | What a condition does (for UI / AI queries) |
| `exhaustion_level(Entity, Level)` | 0 if none; 1–6 per SRD table |
| `active_exhaustion_effect(Entity, Effect, Value)` | Cumulative effects at current exhaustion level |
| `condition_blocks_action(Entity)` | Entity cannot take actions this turn |
| `condition_blocks_reaction(Entity)` | Entity cannot take reactions |
| `condition_grants_advantage_on_attack(Attacker, Target)` | A condition gives advantage on the attack |
| `condition_imposes_disadvantage_on_attack(Attacker, Target)` | A condition imposes disadvantage |

## The 15 Conditions

`blinded` `charmed` `deafened` `frightened` `grappled` `incapacitated`
`invisible` `paralyzed` `petrified` `poisoned` `prone` `restrained` `stunned` `unconscious`

Plus exhaustion (6 levels).

## Setup

```python
# Apply a condition
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "goblin",
    "attribute": "condition", "value": "poisoned"
})
# Multiple conditions are allowed — assert each separately
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "goblin",
    "attribute": "condition", "value": "prone"
})

# Exhaustion level
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "barbarian",
    "attribute": "exhaustion", "value": 2
})
```

## Usage

```python
# Is this entity unable to act?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "condition_blocks_action(goblin)"
})

# What does prone do?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "condition_effect(prone, Effect, Value)"
})
# Returns all effects: attack_rolls→disadvantage, attack_rolls_incoming_melee→advantage, etc.

# List all conditions on an entity
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "d20_condition_active(goblin, C)"
})

# What exhaustion effects apply at level 3?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "active_exhaustion_effect(barbarian, Effect, Value)"
})
```
