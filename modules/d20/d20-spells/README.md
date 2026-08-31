# Module: d20-spells v1.0.0

Spellcasting mechanics: spell slots, the full casting gate (known → prepared →
slot free), save resolution against the caster's DC, concentration checks, and
a starter grimoire of 14 SRD spells with cantrip scaling and upcasting. The
cell owns the rules and the ruling; the application rolls the dice — the same
division of labour as `d20_check/4` in `d20-core`.

**Requires:** d20-core (spell save DC, saving throw modifiers).

All mechanics are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-core", "d20-spells"],
    "namespace": "my-campaign"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `d20_spell(Name, Level, School)` | The grimoire; level 0 is a cantrip |
| `spell_range(Name, Range)` | Range in feet (0 = touch/self) |
| `spell_cast_action(Name, Action)` | `action` \| `bonus_action` |
| `spell_save(Name, Ability, OnSuccess)` | Saving-throw spells; OnSuccess: `none` \| `half` |
| `spell_attack_roll(Name)` | Delivered by a spell attack roll vs AC |
| `spell_concentration(Name)` | The spell requires concentration |
| `spell_damage_type(Name, Type)` | fire / cold / radiant / force / thunder / … |
| `spell_known(Caster, Spell)` | Known — or prepared, if the caster prepares |
| `spell_castable(Caster, Spell)` | Known AND a sufficient slot remains (cantrips always) |
| `spell_slots_total(Caster, SlotLevel, N)` | Total slots of that level |
| `spell_slots_expended(Caster, SlotLevel, N)` | Slots already spent (defaults to 0) |
| `spell_slot_available(Caster, SlotLevel)` | At least one slot of that level remains |
| `d20_can_cast(Caster, Spell, SlotLevel)` | The full casting gate; cantrips cast at SlotLevel 0 |
| `spell_effective_dice(Spell, CasterLevel, SlotLevel, NDice, Faces)` | Damage dice after cantrip scaling and upcasting |
| `spell_heal_profile(Spell, SlotLevel, NDice, Faces)` | Healing dice after upcasting (add the caster's ability modifier) |
| `d20_spell_save(Caster, Target, Spell, Roll, Outcome)` | `save_success` \| `save_failure` against the caster's DC |
| `d20_concentration_dc(Damage, DC)` | CON save DC when damaged while concentrating: max(10, Damage // 2) |
| `d20_concentration_check(Entity, Damage, Roll, Outcome)` | `holds` \| `broken` |

## The Grimoire

Cantrips: `fire_bolt` `ray_of_frost` `sacred_flame` ·
Level 1: `magic_missile` `burning_hands` `cure_wounds` `healing_word` `bless`
`shield_of_faith` `thunderwave` ·
Level 2: `hold_person` `misty_step` `scorching_ray` `web`

## Setup

```python
# Slots (mutate the used count like hp — retract and re-assert)
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "wizard",
    "attribute": "slots_l1", "value": 2
})

# Known spells
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "relation", "subject": "wizard",
    "relation": "knows_spell", "object": "burning_hands"
})

# Prepared casters (clerics, wizards) additionally prepare
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "cleric",
    "attribute": "prepares_spells", "value": True
})
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "relation", "subject": "cleric",
    "relation": "prepared_spell", "object": "cure_wounds"
})

# Spellcasting ability (d20-core uses it for the DC)
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "wizard",
    "attribute": "spellcasting_ability", "value": "int"
})
```

## Usage

```python
# Can the wizard cast burning hands from a level-2 slot (upcast)?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "d20_can_cast(wizard, burning_hands, 2)"
})

# What dice does that cast roll? (base 3d6 + 1d6 per slot above 1st)
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "spell_effective_dice(burning_hands, 1, 2, NDice, Faces)"
})

# The target rolled an 11 on its DEX save — ruled against the caster's DC
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "d20_spell_save(wizard, orc, web, 11, Outcome)"
})

# Concentrating caster takes 30 damage and rolls a 12
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "d20_concentration_check(cleric, 30, 12, Outcome)"
})
```

## Rulings & scope

- **The application rolls; the cell rules.** No randomness lives in the cell —
  pass the die roll in, get the ruling back.
- **Cantrips scale with caster level** (SRD tiers 1/5/11/17); **levelled spells
  scale with the slot** they are cast from.
- **Upcasting** uses `d20_can_cast/3` with any slot level at or above the
  spell's level; extra dice come from `spell_effective_dice/5` /
  `spell_heal_profile/4`.
- **Multi-projectile spells** (magic_missile: 3×1d4, +1 each; scorching_ray:
  three rays of 2d6) expose their total dice pool — per-dart bonuses and
  per-ray attack rolls are the application's loop.
- **Slot spending is the application's write** — retract and re-assert
  `slots_lN_used` after a cast the gate approved.
