# Module: d20-combat v1.0.0

AC-based hit resolution, damage calculation, initiative ordering, and
advantage/disadvantage derivation. Requires **d20-core**; works best with
**d20-conditions** for full condition-driven advantage logic.

All mechanics are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-core", "d20-combat", "d20-conditions"],
    "namespace": "my-campaign"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `hits_ac(Attacker, Target, Roll)` | True if melee Roll+attack_bonus ≥ Target's AC; nat 1 always misses, nat 20 always hits |
| `hits_ac(Attacker, Target, Roll, Type)` | Type: `melee` \| `ranged` \| `spell` |
| `d20_damage(Attacker, Target, DiceRoll, Final)` | DiceRoll + ability mod × resistance factor, floored at 0 |
| `d20_crit_damage(Attacker, Target, DiceRoll, Final)` | DiceRoll doubled before modifier (SRD crit rule) |
| `is_defeated(Entity)` | Entity has 0 or fewer HP |
| `initiative_order(Combatants, Ordered)` | Sorted by initiative descending; uses `keysort` (ISO-safe) |
| `d20_resistance(Entity, DamageType, Factor)` | 0=immune, 0.5=resist, 1=normal, 2=vulnerable |
| `damage_category(Type, Category)` | `slashing`/`piercing`/`bludgeoning` → `physical` |
| `advantage_on_attack(Attacker, Target)` | Condition or terrain grants advantage |
| `disadvantage_on_attack(Attacker, Target)` | Condition or terrain imposes disadvantage |
| `can_attack(Attacker, Target)` | Both alive, no action-blocking condition, not out of range |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `ac` | entity | integer | Armor class, stated outright. Takes precedence over the computed form |
| `armor_base_ac` | entity | integer | Armor's base; AC is this plus the Dex modifier (unless `no_dex_to_ac`) plus 2 for a `shield`. Without it the base is 10 |
| `no_dex_to_ac` | entity | `true` | Heavy armor: the Dex modifier is not added |
| `shield` | entity | `true` | +2 AC |
| `hp` | entity | integer | `d20_is_defeated` at 0 or below |
| `hp_max` | entity | integer | `d20_instant_death` when remaining damage at 0 HP meets or exceeds it |
| `initiative` | entity | integer | Stated initiative; otherwise the Dex modifier |
| `damage_type` | attacker | `slashing` \| `piercing` \| `bludgeoning` \| any other type | Default `bludgeoning`. The three physical types also match `<prefix>_physical` resistances |
| `damage_bonus` | attacker | integer | Flat bonus added to the dice, stated outright |
| `damage_ability` | attacker | `str` \| `dex` \| … | Which ability's modifier is added when `damage_bonus` is absent. Default `str`, or the better of Str/Dex with `finesse_attack` |
| `finesse_attack` | attacker | `true` | Damage uses the higher of the Str and Dex modifiers |
| `immune_<type>`, `resist_<type>`, `vulnerable_<type>` | target | any | Factor 0 / 0.5 / 2.0 for that damage type — `immune_fire`, `resist_physical`. Checked for the specific type first, then its category |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `adjacent_to` | attacker → target | Within reach: advantage against a prone target; without it, disadvantage against one |
| `can_see` | attacker → target | A frightened attacker who can see the target has disadvantage |
| `flanking` | attacker → target | Advantage |
| `has_high_ground_vs` | attacker → target | Advantage |
| `has_cover_vs` | attacker → target | Disadvantage |
| `out_of_range` | attacker → target | `d20_can_attack` fails |

Ability scores (`str`, `dex`, …), `level`, `attack_bonus` and the proficiency
flags are `d20-core`'s facts; conditions (`condition`) are `d20-conditions`'.
This battery reads them through those batteries' predicates.

## Key Design Differences from the `combat` Battery

The generic `combat` battery uses flat armor reduction and elemental type charts.
`d20-combat` follows SRD mechanics:

- **Armor Class** — target number to meet or beat (Roll + bonus ≥ AC), not subtracted from damage
- **Physical subtypes** — `slashing`, `piercing`, `bludgeoning` group under `physical` via `damage_category/2`; `resist_physical` catches all three
- **Initiative** — uses `keysort/2` instead of `msort/2` (safe in all LC sandbox flavors)
- **Crits** — double the dice roll, then add the ability modifier (SRD 5.1)

## Setup

### AC and HP

```python
# Direct AC assertion
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter", "attribute": "ac", "value": 16
})
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter", "attribute": "hp", "value": 28
})
```

### Resistances and Immunities

```python
# Resist a specific type
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fire_elemental",
    "attribute": "immune_fire", "value": True
})
# Resist all physical — catches slashing, piercing, and bludgeoning
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "shadow",
    "attribute": "resist_physical", "value": True
})
# Vulnerable to a type
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "troll",
    "attribute": "vulnerable_fire", "value": True
})
```

### Initiative

```python
# Assert rolled initiatives after each combatant rolls
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "fighter", "attribute": "initiative", "value": 17
})
# Fallback: uses DEX modifier if initiative is not set
```

### Terrain / Positional Relations

```python
# Grant advantage via high ground
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "relation", "subject": "archer",
    "relation": "has_high_ground_vs", "object": "goblin"
})
# Flanking
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "relation", "subject": "fighter",
    "relation": "flanking", "object": "orc"
})
```

## Usage

```python
# Did the fighter hit the goblin on a roll of 14?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "hits_ac(fighter, goblin, 14)"
})

# How much damage does a longsword swing deal (rolled 6)?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "d20_damage(fighter, goblin, 6, Final)"
})

# Who goes first?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "d20_initiative_order([fighter, wizard, goblin, orc], Ordered)"
})

# Does the rogue have advantage against this target?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "advantage_on_attack(rogue, guard)"
})
```

## Resistance Precedence

1. `immune_<type>` or `immune_physical` (for slashing/piercing/bludgeoning) → 0
2. `resist_<type>` or `resist_physical` → 0.5
3. `vulnerable_<type>` or `vulnerable_physical` → 2.0
4. Default → 1.0

Specific type always checked before category, so `immune_slashing` works even without `immune_physical`.
