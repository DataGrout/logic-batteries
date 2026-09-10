# Module: economy v1.0.0

Recipes as material lists, whether a player can craft one and what they lack,
the gold cost of crafting, and buy and sell prices adjusted for supply and
demand.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["economy"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("economy", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `can_craft(Player, Item)` | The item has at least one ingredient and the player holds enough of every one |
| `missing_materials(Player, Item, Missing)` | One list of `material(Name, Need, Have)` for each shortfall |
| `craft_cost(Item, Cost)` | `recipe_gold_cost` if set, else the sum of `quantity × buy_price` over ingredients |
| `buy_price(Item, Price)` | `round(base_price × supply_factor × demand_factor)` |
| `sell_price(Item, Price)` | `round(buy_price × sell_ratio)` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `<material>_qty` | recipe item | integer | How many of that material the recipe needs: `iron_ingot_qty`. Default 1. Built from the material name, so it does not appear in the source as a literal |
| `recipe_gold_cost` | recipe item | number | Flat crafting cost; when present the ingredient sum is skipped |
| `base_price` | item | number | Required for any price; an item without one has no `buy_price` |
| `supply_factor` | item | multiplier | Default 1.0; below 1 is abundant and cheaper |
| `demand_factor` | item | multiplier | Default 1.0; above 1 is sought-after and dearer |
| `sell_ratio` | `economy` | fraction | Fraction of the buy price a vendor pays; default 0.5 |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `requires` | recipe item → material | One per ingredient |
| `has_material` | player → material | One unit held. Quantity is the *number of these facts*; three facts mean three units |

`economy` is a fixed entity name for the sell ratio.

## Setup

```
# A recipe
{ type="relation",  subject="iron_sword", relation="requires", object="iron_ingot" }
{ type="relation",  subject="iron_sword", relation="requires", object="wood" }
{ type="attribute", entity="iron_sword", attribute="iron_ingot_qty", value=3 }
# wood has no _qty, so 1

# Prices
{ type="attribute", entity="iron_sword", attribute="base_price",    value=100 }
{ type="attribute", entity="iron_sword", attribute="supply_factor", value=0.8 }
{ type="attribute", entity="iron_sword", attribute="demand_factor", value=1.5 }
{ type="attribute", entity="iron_ingot", attribute="base_price",    value=10 }
{ type="attribute", entity="wood",       attribute="base_price",    value=2 }
{ type="attribute", entity="economy",    attribute="sell_ratio",    value=0.7 }

# What alice holds: three ingots, no wood
{ type="relation", subject="alice", relation="has_material", object="iron_ingot" }
{ type="relation", subject="alice", relation="has_material", object="iron_ingot" }
{ type="relation", subject="alice", relation="has_material", object="iron_ingot" }
```

## Querying

```
# Can she make it?
can_craft(alice, iron_sword)
   false

# What is she short of?
missing_materials(alice, iron_sword, Missing)
   Missing = [material(wood, 1, 0)]

# What would it cost to craft, and to buy?
craft_cost(iron_sword, Cost)
   Cost = 32
buy_price(iron_sword, P)
   P = 120
sell_price(iron_sword, P)
   P = 84
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "missing_materials(alice, iron_sword, M)", function(r) if r[1] then showMissing(r[1].M) end end)
```

## Semantics worth knowing

**Quantity is a count of identical facts.** `has_material` has no amount; three
units are three identical relation facts. Check that your fact store keeps
duplicates — a store that collapses identical facts would cap every material at
one. If that is your situation, model quantities as an attribute and query it
yourself.

**`craft_cost` skips unpriced ingredients silently.** An ingredient with no
`base_price` contributes nothing to the sum rather than failing the query, so
a partially priced recipe under-reports. Set `recipe_gold_cost` when that
matters.

**No ingredients, no craft.** `can_craft` requires at least one `requires`
relation; an item nobody has given a recipe is uncraftable, not free.

## Composing with Other Modules

`inventory` for what the player holds, `quests` for crafting as an objective,
`npc-state` for gating a shop on standing.
