# Module: taxonomy v1.0.0

Hierarchical classification with property inheritance. Assert `is_a` relations between entities and classes; query transitive membership, inherited attributes, common ancestors, and class structure at zero token cost. Domain-agnostic — works for monster types, product categories, capability trees, or any knowledge hierarchy.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["taxonomy"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install_many({"taxonomy"}, "my-namespace", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `isa(Entity, Class)` | Entity is a Class (direct or transitive) |
| `inherits_property(Entity, Property, Value)` | Entity has Property via direct attribute or ancestor chain |
| `most_specific_class(Entity, Class)` | Most specific `is_a` class Entity belongs to |
| `common_ancestor(E1, E2, Ancestor)` | Shared ancestor of E1 and E2 |
| `siblings(E1, E2)` | E1 and E2 share the same direct parent class |
| `subclasses(Class, Subs)` | All transitive subclasses of Class |
| `class_members(Class, Members)` | All entities that isa Class |
| `depth_in_hierarchy(Class, Depth)` | Hops from Class to a root (no parent) |
| `compatible_types(E1, E2)` | E1 and E2 share at least one common ancestor |
| `root_class(Class)` | Class has no `is_a` parent |

## Setup

```lua
-- Build a hierarchy with is_a relations
dg:assert("my-ns", { type="relation", subject="goblin",      relation="is_a", object="humanoid" })
dg:assert("my-ns", { type="relation", subject="orc",         relation="is_a", object="humanoid" })
dg:assert("my-ns", { type="relation", subject="humanoid",    relation="is_a", object="creature" })
dg:assert("my-ns", { type="relation", subject="wolf",        relation="is_a", object="beast" })
dg:assert("my-ns", { type="relation", subject="beast",       relation="is_a", object="creature" })

-- Attach properties to classes; instances inherit them automatically
dg:assert("my-ns", { type="attribute", entity="creature",  attribute="has_soul",  value=true })
dg:assert("my-ns", { type="attribute", entity="humanoid",  attribute="can_speak", value=true })
dg:assert("my-ns", { type="attribute", entity="goblin",    attribute="base_hp",   value=30 })
```

## Usage

```lua
-- Is a goblin a creature? (transitive)
dg:query("my-ns", "isa(goblin, creature)", function(r)
  print(#r > 0 and "yes" or "no")  -- "yes"
end)

-- Can a wolf speak? (inherits from humanoid? no — beast doesn't inherit that)
dg:query("my-ns", "inherits_property(wolf, can_speak, V)", function(r)
  print(#r > 0 and tostring(r[1].V) or "no")  -- "no"
end)

-- What do goblins and wolves have in common?
dg:query("my-ns", "common_ancestor(goblin, wolf, A)", function(r)
  for _, row in ipairs(r) do print(row.A) end  -- "creature"
end)

-- Are goblin and orc siblings?
dg:query("my-ns", "siblings(goblin, orc)", function(r)
  print(#r > 0 and "yes" or "no")  -- "yes" (both isa humanoid)
end)

-- All subclasses of creature
dg:query("my-ns", "subclasses(creature, Subs)", function(r)
  if r[1] then
    -- Subs = [goblin, orc, humanoid, wolf, beast] (order may vary)
    print(table.concat(r[1].Subs, ", "))
  end
end)

-- What is goblin's most specific class?
dg:query("my-ns", "most_specific_class(goblin, C)", function(r)
  print(r[1] and r[1].C or "none")  -- "humanoid"
end)

-- All members of the humanoid class
dg:query("my-ns", "class_members(humanoid, M)", function(r)
  if r[1] then
    for _, m in ipairs(r[1].M) do print(m) end  -- goblin, orc
  end
end)
```

## Property Inheritance Resolution

Properties resolve in order:
1. Direct attribute on the entity — always wins
2. Direct attribute on the entity's `is_a` parent
3. Transitive ancestors, depth-first

This means you can set a default on a class and override it on any subclass or instance:

```lua
-- Default for all creatures
dg:assert("my-ns", { type="attribute", entity="creature", attribute="loot_multiplier", value=1.0 })
-- Boss override
dg:assert("my-ns", { type="attribute", entity="dragon", attribute="loot_multiplier", value=5.0 })
-- inherits_property(goblin, loot_multiplier, 1.0) — inherited
-- inherits_property(dragon, loot_multiplier, 5.0) — overridden
```
