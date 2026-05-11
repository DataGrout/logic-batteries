# Module: economy v1.0.0

Crafting recipes, material tracking, buy/sell pricing, and supply-demand adjustments.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["economy"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("economy", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `can_craft(Player, Item)` | Player has enough materials to craft Item |
| `missing_materials(Player, Item, Missing)` | Missing is a list of `material(Name, Need, Have)` tuples |
| `craft_cost(Item, Cost)` | Gold cost to craft Item (from ingredient prices or flat override) |
| `buy_price(Item, Price)` | Price to buy Item, adjusted for supply and demand |
| `sell_price(Item, Price)` | Price a player receives when selling Item |

## Crafting

### Recipes

```lua
-- Register ingredients (one relation per material)
dg:assert("my-game", { type="relation", subject="iron_sword", relation="requires", object="iron_ingot" })
dg:assert("my-game", { type="relation", subject="iron_sword", relation="requires", object="wood" })

-- Set quantities (attribute name is <material>_qty)
dg:assert("my-game", { type="attribute", entity="iron_sword", attribute="iron_ingot_qty", value=3 })
dg:assert("my-game", { type="attribute", entity="iron_sword", attribute="wood_qty",       value=1 })
-- Quantity defaults to 1 if no _qty attribute is set
```

### Player materials

```lua
-- Each relation(player, has_material, material) counts as one unit
dg:assert("my-game", { type="relation", subject="alice", relation="has_material", object="iron_ingot" })
dg:assert("my-game", { type="relation", subject="alice", relation="has_material", object="iron_ingot" })
dg:assert("my-game", { type="relation", subject="alice", relation="has_material", object="iron_ingot" })
dg:assert("my-game", { type="relation", subject="alice", relation="has_material", object="wood" })
```

## Pricing

```lua
-- Base price (required for buy_price / sell_price)
dg:assert("my-game", { type="attribute", entity="iron_sword", attribute="base_price", value=100 })

-- Supply factor: oversupply makes it cheaper
dg:assert("my-game", { type="attribute", entity="iron_sword", attribute="supply_factor", value=0.8 })

-- Demand factor: high demand makes it more expensive
dg:assert("my-game", { type="attribute", entity="iron_sword", attribute="demand_factor", value=1.5 })
-- buy_price = round(100 * 0.8 * 1.5) = 120

-- Custom sell ratio (default: 0.5)
dg:assert("my-game", { type="attribute", entity="economy", attribute="sell_ratio", value=0.7 })
-- sell_price = round(buy_price * 0.7)

-- Flat recipe gold cost (overrides ingredient price sum)
dg:assert("my-game", { type="attribute", entity="iron_sword", attribute="recipe_gold_cost", value=50 })
```

## Usage

```lua
-- Can alice craft an iron sword?
dg:query("my-game", "can_craft(alice, iron_sword)", function(results)
  if #results > 0 then showCraftButton() end
end)

-- What is alice missing?
dg:query("my-game", "missing_materials(alice, iron_sword, Missing)", function(results)
  if results[1] then
    for _, m in ipairs(results[1].Missing) do
      -- m = material(name, needed, have)
      showMissingMaterial(m)
    end
  end
end)

-- How much does it cost to craft?
dg:query("my-game", "craft_cost(iron_sword, Cost)", function(results)
  if results[1] then showCraftingCost(results[1].Cost) end
end)

-- What is the market price?
dg:query("my-game", "buy_price(iron_sword, P)", function(results)
  if results[1] then showBuyPrice(results[1].P) end
end)

dg:query("my-game", "sell_price(iron_sword, P)", function(results)
  if results[1] then showSellPrice(results[1].P) end
end)
```

## Composing with Other Modules

Works naturally with `inventory` (materials come from player inventory), `quests` (crafting a specific item as a quest objective), and `npc-state` (shop availability gated on faction or relationship level).
