# Module: d20-monsters v1.0.0

SRD 5.1 monster stat blocks as attribute facts. 16 monsters from CR 0 to CR 13,
ready to use with `d20-combat` and `d20-xp`. Override any attribute to customise
for your campaign.

All stat blocks are from the **SRD 5.1**, published under **CC BY 4.0** by Wizards of the Coast LLC.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["d20-monsters"],
    "namespace": "my-campaign"
})
```

## Included Monsters

| Name | CR | Type | AC | HP |
|---|---|---|---|---|
| `commoner` | 0 | humanoid | 10 | 4 |
| `bandit` | 1/8 | humanoid | 12 | 11 |
| `guard` | 1/8 | humanoid | 16 | 11 |
| `goblin` | 1/4 | humanoid | 15 | 7 |
| `skeleton` | 1/4 | undead | 13 | 13 |
| `zombie` | 1/4 | undead | 8 | 22 |
| `orc` | 1/2 | humanoid | 13 | 15 |
| `shadow` | 1/2 | undead | 12 | 16 |
| `ghoul` | 1 | undead | 12 | 22 |
| `giant_spider` | 1 | beast | 14 | 26 |
| `ogre` | 2 | giant | 11 | 59 |
| `manticore` | 3 | monstrosity | 14 | 68 |
| `minotaur` | 3 | monstrosity | 14 | 76 |
| `troll` | 5 | giant | 15 | 84 |
| `stone_golem` | 10 | construct | 17 | 178 |
| `vampire` | 13 | undead | 16 | 144 |

## Customising

Override any attribute in your namespace — the battery's assertion is the default,
your assertion is checked first in logic.query if you assert after install:

```python
# Stronger skeleton variant
client.perform("data-grout@1/logic.assert@1", {
    "namespace": "my-campaign",
    "type": "attribute", "entity": "skeleton", "attribute": "hp", "value": 20
})
```

Or install the battery and then assert a custom monster using the same attribute shape:

```python
for attr, val in [("cr", "1/2"), ("xp", 100), ("monster_type", "undead"),
                  ("ac", 14), ("hp", 20), ("str", 12), ("dex", 12),
                  ("damage_type", "necrotic"), ("srd", False)]:
    client.perform("data-grout@1/logic.assert@1", {
        "namespace": "my-campaign",
        "type": "attribute", "entity": "revenant_soldier", "attribute": attr, "value": val
    })
```

## Usage

```python
# What CR is the stone_golem?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "monster_cr(stone_golem, CR)"
})

# List all SRD undead monsters
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "srd_monster(M), monster_type(M, undead)"
})

# What does the troll resist/is vulnerable to?
client.perform("data-grout@1/logic.query@1", {
    "namespace": "my-campaign",
    "prolog": "attribute(troll, Attr, Val), (sub_atom(Attr,0,_,_,vulnerable) ; sub_atom(Attr,0,_,_,resist) ; sub_atom(Attr,0,_,_,immune))"
})
```
