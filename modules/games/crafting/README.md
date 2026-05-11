# Module: crafting v1.0.0

Recipe knowledge, skill requirements, automatic discovery via level/quest/item, and craftability checks. Designed so that acquiring knowledge and meeting requirements are two independent checks.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["crafting"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("crafting", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `recipe_known(Player, Recipe)` | Player has learned or discovered Recipe |
| `can_craft_skilled(Player, Item)` | Player knows the recipe and meets all skill requirements |
| `crafting_skill(Player, Skill, Level)` | Player's current level in a crafting skill |
| `skill_requirement(Item, Skill, MinLevel)` | Item requires Skill at minimum Level |
| `recipe_discoverable(Player, Recipe)` | Player currently meets the discovery conditions |

## Recipe Acquisition

Three paths to knowing a recipe, checked in order:

1. **Directly taught**: `relation(player, knows_recipe, item)` — from a trainer, book, or purchase
2. **Starter recipe**: `attribute(item, starter_recipe, true)` — all players know this
3. **Auto-discovered**: when the player reaches a level, completes a quest, or holds an item

## Setup

### Direct recipe knowledge

```lua
local ns = "my-game"

dg:assert(ns, { type="relation", subject="alice", relation="knows_recipe", object="iron_sword" })
```

### Starter recipes (universal)

```lua
dg:assert(ns, { type="attribute", entity="basic_bandage", attribute="starter_recipe", value=true })
```

### Discovery conditions

```lua
-- Discovered when player reaches a level
dg:assert(ns, { type="attribute", entity="fire_spell", attribute="discover_on_level", value=10 })

-- Discovered when player completes a quest
dg:assert(ns, { type="attribute", entity="rare_potion", attribute="discover_on_quest",
                value="find_alchemist" })

-- Discovered when player holds an item
dg:assert(ns, { type="attribute", entity="masterwork_blade", attribute="discover_on_item",
                value="ancient_scroll" })
```

### Skill requirements

Skill names are stored as `requires_<skill>` attributes on the item:

```lua
dg:assert(ns, { type="attribute", entity="iron_sword", attribute="requires_smithing", value=3 })
dg:assert(ns, { type="attribute", entity="fire_staff", attribute="requires_arcane",   value=5 })
```

### Player skill levels

Keyed as `<player>_<skill>`:

```lua
dg:assert(ns, { type="attribute", entity="alice_smithing", attribute="level", value=5 })
dg:assert(ns, { type="attribute", entity="alice_arcane",   attribute="level", value=2 })
```

## Querying

```lua
-- Check if alice can craft a sword
dg:query(ns, "can_craft_skilled(alice, iron_sword)", function(result)
  if result then showCraftButton() end
end)

-- List all recipes alice currently knows
dg:query_all(ns, "recipe_known(alice, Recipe)", function(results)
  for _, r in ipairs(results) do addToRecipeBook(r.Recipe) end
end)

-- Check a specific skill level
dg:query(ns, "crafting_skill(alice, smithing, Level)", function(result)
  print("Smithing level: " .. result.Level)
end)
```

## Pairs Well With

- **progression**: Assert `attribute(player, level, N)` so `discover_on_level` conditions trigger automatically as the player levels up.
- **quests**: Assert `relation(player, completed_quest, Q)` on quest completion to unlock `discover_on_quest` recipes.
- **inventory**: Assert `relation(player, has_item, I)` when items enter the player's inventory to unlock `discover_on_item` recipes.
