# Module: crafting v1.0.0

Recipe knowledge, skill requirements, and craftability. Knowing a recipe and
being skilled enough to use it are two separate checks; a recipe can be taught
directly, be a starter, or be discovered when the player reaches a level,
finishes a quest, or holds an item.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["crafting"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("crafting", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `recipe_known(Player, Recipe)` | Taught, a starter, or currently discoverable |
| `can_craft_skilled(Player, Item)` | Knows the recipe and meets every skill requirement |
| `crafting_skill(Player, Skill, Level)` | The player's level in a skill; 0 when none is set |
| `skill_requirement(Item, Skill, MinLevel)` | Each `requires_<skill>` on the item, decomposed |
| `recipe_discoverable(Player, Recipe)` | A discovery condition is met right now |

The recipe and the item it produces share one id: `can_craft_skilled(alice,
iron_sword)` asks whether alice knows the `iron_sword` recipe.

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `starter_recipe` | recipe | `true` | Everyone knows it |
| `discover_on_level` | recipe | integer | Known once the player's `level` reaches this |
| `discover_on_quest` | recipe | a quest id | Known once the player has `completed_quest` it |
| `discover_on_item` | recipe | an item id | Known while the player `has_item` it |
| `requires_<skill>` | recipe | integer | Minimum level in `<skill>`: `requires_smithing`, `requires_arcane`. The skill name is taken from the attribute name, so any `requires_*` attribute on a recipe is read as a skill requirement |
| `level` | player | integer | The player's character level, for `discover_on_level` |
| `level` | `<player>_<skill>` | integer | The player's level in a skill, on a composite entity: `alice_smithing` |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `knows_recipe` | player → recipe | Taught directly — trainer, book, purchase |
| `completed_quest` | player → quest | Satisfies `discover_on_quest` |
| `has_item` | player → item | Satisfies `discover_on_item` |

## Recipe Acquisition

Checked in this order; the first that holds makes the recipe known:

1. `knows_recipe` — taught
2. `starter_recipe = true` — universal
3. any discovery condition currently met

## Setup

```
# Taught
{ type="relation",  subject="alice", relation="knows_recipe", object="iron_sword" }

# Starter
{ type="attribute", entity="basic_bandage", attribute="starter_recipe", value=true }

# Discovery
{ type="attribute", entity="fire_spell",       attribute="discover_on_level", value=10 }
{ type="attribute", entity="rare_potion",      attribute="discover_on_quest", value="find_alchemist" }
{ type="attribute", entity="masterwork_blade", attribute="discover_on_item",  value="ancient_scroll" }

# Skill requirements: the skill is in the attribute name
{ type="attribute", entity="iron_sword", attribute="requires_smithing", value=3 }
{ type="attribute", entity="fire_staff", attribute="requires_arcane",   value=5 }

# The player: character level, then skill levels on <player>_<skill>
{ type="attribute", entity="alice",          attribute="level", value=12 }
{ type="attribute", entity="alice_smithing", attribute="level", value=5 }
{ type="attribute", entity="alice_arcane",   attribute="level", value=2 }
```

## Querying

```
# Can alice make a sword?
can_craft_skilled(alice, iron_sword)

# Everything she knows
recipe_known(alice, Recipe)

# What does the staff need, and where is she?
skill_requirement(fire_staff, Skill, Min)
   Skill = arcane, Min = 5
crafting_skill(alice, arcane, Level)
   Level = 2
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "can_craft_skilled(alice, iron_sword)", function(r) if #r > 0 then showCraftButton() end end)
```

## Semantics worth knowing

**Discovery is a live condition, not an event.** `discover_on_item` holds only
while the player holds the item; give the scroll away and the recipe is
forgotten unless you also assert `knows_recipe`. Assert `knows_recipe` when a
discovery happens if you want it to stick.

**Every `requires_*` is a skill.** Attach a `requires_level` to a recipe and it
is read as a requirement on a skill called `level`, checked against
`<player>_level`. Use `discover_on_level` for level gates.

**Missing skill is level 0.** A recipe requiring smithing 3 is uncraftable by a
player with no `<player>_smithing` entity; there is no error, just `false`.

**Composite keys.** `<player>_<skill>` joins with `_`, so a player id containing
`_` can collide with another player-skill pair. Keep ids free of `_`.

## Pairs Well With

`progression` for `level`, `quests` for `completed_quest`, `inventory` for
`has_item` — each asserts the fact this battery reads.
