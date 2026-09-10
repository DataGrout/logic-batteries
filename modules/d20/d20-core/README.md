# Module: d20-core v1.0.0

Foundation rules for the d20 SRD battery suite. Ability scores and modifiers,
proficiency bonus by level, skill modifiers with proficiency/expertise, saving
throws, passive perception, spell save DC, and attack bonus for melee/ranged/spell.

All mechanics are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-core"],
    "namespace": "my-campaign"
})
```

Install the full suite:

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-core", "d20-combat", "d20-conditions", "d20-monsters", "d20-xp"],
    "namespace": "my-campaign"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `ability_modifier(Score, Mod)` | Floor((Score-10)/2) — SRD modifier formula |
| `proficiency_bonus(Level, PB)` | PB by character/monster level (2–6) |
| `skill_modifier(Entity, Skill, Mod)` | Total modifier including proficiency/expertise |
| `saving_throw_modifier(Entity, Ability, Mod)` | Save modifier with proficiency if marked |
| `passive_perception(Entity, PP)` | 10 + Perception modifier |
| `spell_save_dc(Entity, DC)` | 8 + PB + spellcasting ability modifier |
| `attack_bonus(Entity, Type, Bonus)` | Melee/ranged/spell attack bonus |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `str`, `dex`, `con`, `int`, `wis`, `cha` | entity | 1–30 | Ability scores. Every modifier is `(score − 10) div 2`; a missing score counts as modifier 0 |
| `level` | entity | integer | Drives proficiency bonus: 2 at level 1, +1 every four levels. Default 1 |
| `proficient_<skill>` | entity | `true` | Adds the proficiency bonus to that skill: `proficient_stealth` |
| `expertise_<skill>` | entity | `true` | Adds double proficiency; wins over `proficient_<skill>` |
| `skill_<skill>` | entity | integer | A stated total modifier for the skill, overriding the computed one |
| `save_<ability>` | entity | `true` | Proficient in that saving throw: `save_dex` |
| `spellcasting_ability` | entity | `int` \| `wis` \| `cha` \| … | Required for `spell_save_dc` and the `spell` attack bonus |
| `attack_bonus` | entity | integer | A stated total attack bonus, for every attack type, overriding the computed one |
| `attack_ability` | entity | an ability | Which ability drives melee (default `str`) or ranged (default `dex`) attacks |
| `finesse_attack` | entity | `true` | Melee uses the better of Str and Dex |
| `proficient_attack` | entity | `true` | Adds the proficiency bonus to melee and ranged attacks. Spell attacks always add it |

Skills are the eighteen SRD skills by name (`acrobatics` … `survival`), each
tied to its ability; a `<skill>` or `<ability>` in an attribute name above is
one of those. The suffixed names are built at query time and do not appear in
the source as literals.

## Setup

### Ability Scores

```python
# Assert the six ability scores
for attr, val in [("str", 18), ("dex", 14), ("con", 16),
                  ("int", 8), ("wis", 12), ("cha", 10)]:
    client.perform("data-grout@1/logic.assert@1", {
        "namespace": "my-campaign",
        "type": "attribute",
        "entity": "fighter",
        "attribute": attr,
        "value": val
    })
```

### Level and Proficiency

```python
# Level governs proficiency bonus (PB = 2+floor((level-1)/4))
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter", "attribute": "level", "value": 5
})
```

### Skills

```python
# Mark proficiency in a skill
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter",
    "attribute": "proficient_athletics", "value": True
})
# Mark expertise (double PB)
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "rogue",
    "attribute": "expertise_stealth", "value": True
})
```

Available skills: `acrobatics`, `animal_handling`, `arcana`, `athletics`,
`deception`, `history`, `insight`, `intimidation`, `investigation`, `medicine`,
`nature`, `perception`, `performance`, `persuasion`, `religion`,
`sleight_of_hand`, `stealth`, `survival`

### Saving Throws

```python
# Mark saving throw proficiencies
for save in ["save_str", "save_con"]:
    client.perform("data-grout@1/logic.assert@1", {
        "namespace": "my-campaign",
        "type": "attribute", "entity": "fighter", "attribute": save, "value": True
    })
```

### Attack Bonus

```python
# Melee weapon attack (STR-based, proficient)
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter",
    "attribute": "attack_ability", "value": "str"
})
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter",
    "attribute": "proficient_attack", "value": True
})

# Finesse attack (rogue with rapier — picks best of STR/DEX)
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "rogue",
    "attribute": "finesse_attack", "value": True
})

# Spell attack (wizard)
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "wizard",
    "attribute": "spellcasting_ability", "value": "int"
})
```

## Usage

```python
# What is the fighter's Athletics modifier?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "skill_modifier(fighter, athletics, Mod)"
})

# What is the wizard's spell save DC?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "spell_save_dc(wizard, DC)"
})

# What attack bonus does the fighter have?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "attack_bonus(fighter, melee, Bonus)"
})
```

## Composing with Other d20 Batteries

- **d20-combat** — uses `attack_bonus/3` and `entity_ability_mod/3` from this battery
- **d20-conditions** — standalone, but `can_attack/2` in d20-combat checks condition state
- **d20-monsters** — stat blocks are raw attributes; pair with d20-core predicates to compute modifiers
- **d20-xp** — standalone encounter math; pair with d20-monsters for name-based difficulty queries
