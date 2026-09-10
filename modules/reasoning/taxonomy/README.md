# Module: taxonomy v1.0.1

Hierarchies with property inheritance. One relation, `is_a`, carries both
membership and subclassing; the battery follows it transitively to answer what
something is, what it inherits, what two things have in common, and how the
tree is shaped. Domain-agnostic: monster types, product categories, capability
trees, any knowledge hierarchy.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["taxonomy"],
    "namespace": "my-ns"
})
```

From Tether: `dg:batteries().install("taxonomy", "my-ns", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `isa(Entity, Class)` | Direct or transitive `is_a` |
| `inherits_property(Entity, Property, Value)` | The attribute on the entity, else on the nearest ancestor that has it |
| `most_specific_class(Entity, Class)` | A direct parent that is not an ancestor of another direct parent |
| `common_ancestor(E1, E2, Ancestor)` | Every class both are `isa` |
| `siblings(E1, E2)` | Two different things with the same direct parent |
| `subclasses(Class, Subs)` | Everything transitively `isa` the class — entities included |
| `class_members(Class, Members)` | The same list; kept for readability |
| `depth_in_hierarchy(Class, Depth)` | Hops up to a class with no parent |
| `compatible_types(E1, E2)` | They share at least one ancestor |
| `root_class(Class)` | An entity with no `is_a` parent |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `<any>` | entity or class | any | `inherits_property` looks up a named attribute on the entity first, then up the `is_a` chain until an ancestor has it. Any attribute name qualifies; there is no fixed vocabulary |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `is_a` | entity or class → class | Membership and subclassing in one relation, followed transitively. An entity may have several parents; a class with no `is_a` is a root |

**Entity facts.** `root_class` looks for classes among asserted *entities*
(`{ type="entity", name="creature" }`); a class that appears only as the object
of `is_a` relations is never returned as a root. Assert your classes as
entities if you want to enumerate roots.

## Setup

```
# The hierarchy
{ type="relation", subject="goblin",   relation="is_a", object="humanoid" }
{ type="relation", subject="orc",      relation="is_a", object="humanoid" }
{ type="relation", subject="humanoid", relation="is_a", object="creature" }
{ type="relation", subject="wolf",     relation="is_a", object="beast" }
{ type="relation", subject="beast",    relation="is_a", object="creature" }

# Properties on classes; instances inherit them
{ type="attribute", entity="creature", attribute="has_soul",  value=true }
{ type="attribute", entity="humanoid", attribute="can_speak", value=true }
{ type="attribute", entity="goblin",   attribute="base_hp",   value=30 }

# Classes as entities, so root_class can find them
{ type="entity", name="creature" }
```

## Querying

```
# Transitive membership
isa(goblin, creature)

# Inherited, and not inherited
inherits_property(goblin, can_speak, V)
   V = true
inherits_property(wolf, can_speak, V)
   false

# What do a goblin and a wolf share?
common_ancestor(goblin, wolf, A)
   A = creature

# Structure
siblings(goblin, orc)
most_specific_class(goblin, C)
   C = humanoid
subclasses(creature, Subs)
   Subs = [humanoid, beast, goblin, orc, wolf]     % order follows fact order
depth_in_hierarchy(goblin, D)
   D = 2
root_class(R)
   R = creature
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-ns", "inherits_property(" .. mob .. ", loot_multiplier, M)", function(r) if r[1] then applyLoot(r[1].M) end end)
```

## Property Inheritance Resolution

1. An attribute on the entity itself — always wins.
2. Otherwise the same attribute on a direct parent.
3. Otherwise on ancestors, depth-first along the first parent chain that has
   it.

So a class default can be overridden on any subclass or instance:

```
{ type="attribute", entity="creature", attribute="loot_multiplier", value=1.0 }
{ type="attribute", entity="dragon",   attribute="loot_multiplier", value=5.0 }

inherits_property(goblin, loot_multiplier, M)    M = 1.0   (inherited)
inherits_property(dragon, loot_multiplier, M)    M = 5.0   (own)
```

## Semantics worth knowing

**Entities and classes are the same kind of thing.** `subclasses(creature, S)`
returns goblins and wolves alongside `humanoid` and `beast`; nothing marks a
node as a leaf. If you need only classes, keep instances out of the query by
naming convention or a marker attribute.

**Multiple parents, first-found inheritance.** With two parents that both carry
a property, `inherits_property` returns the first in fact order and stops.

**Cycles terminate.** `isa`, `inherits_property` and `depth_in_hierarchy` all
walk `is_a` with a visited set. A cycle makes its members mutually `isa` each
other and share inherited properties; a cycle with no root has no depth and
`depth_in_hierarchy` fails for it rather than looping.

**Depth is per path.** `depth_in_hierarchy` on a node with two parents returns
a depth for each parent chain on backtracking.

## Changes

**1.0.1** — every `is_a` walk carries a visited set; a cycle in the hierarchy
no longer hangs `isa`, `inherits_property` or `depth_in_hierarchy`.
