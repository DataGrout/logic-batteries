# Module: inventory v1.0.0

What a player carries, weight and slot limits on picking things up, and
equipment slots.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["inventory"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("inventory", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `can_carry(Player, Item)` | Not already held, and adding its weight and one slot stays within both limits |
| `inventory_full(Player)` | Weight at or over the limit, or slots at or over the limit |
| `carrying_weight(Player, W)` | Sum of held items' `weight` |
| `item_count(Player, N)` | Number of `has_item` facts |
| `has_item(Player, Item)` | The relation, as a predicate |
| `item_in_slot(Player, Slot, Item)` | The player is `equipped_in` the slot and the slot `contains` the item |
| `slot_available(Player, Slot)` | A slot with a `slot_type` the player `owns_slot` and has nothing in |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `max_carry_weight` | player | number | Weight limit; default 50 |
| `max_slots` | player | integer | Item-count limit; default 20 |
| `weight` | item | number | Default 1 |
| `slot_type` | slot | any | Marks an entity as an equipment slot; only slots with one count for `slot_available` |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `has_item` | player → item | The player carries the item. You assert this on pickup; the battery never writes it |
| `owns_slot` | player → slot | The slot belongs to the player |
| `equipped_in` | player → slot | The player has something in the slot |
| `contains` | slot → item | What the slot holds |

A slot is its own entity (`alice_main_hand`) with a `slot_type`; the player
`owns_slot` it, and equipping is `equipped_in` from the player plus `contains`
from the slot.

## Setup

```
# Limits (optional; defaults 50 and 20)
{ type="attribute", entity="alice", attribute="max_carry_weight", value=80 }
{ type="attribute", entity="alice", attribute="max_slots",        value=30 }

# Items
{ type="attribute", entity="iron_sword", attribute="weight", value=8 }
{ type="attribute", entity="potion",     attribute="weight", value=1 }

# What alice holds
{ type="relation", subject="alice", relation="has_item", object="potion" }

# Her equipment slots
{ type="attribute", entity="alice_main_hand", attribute="slot_type", value="weapon" }
{ type="relation",  subject="alice",          relation="owns_slot",   object="alice_main_hand" }

# Equipping the sword once she has it
{ type="relation",  subject="alice",          relation="equipped_in", object="alice_main_hand" }
{ type="relation",  subject="alice_main_hand", relation="contains",   object="iron_sword" }
```

## Querying

```
# Before granting a pickup
can_carry(alice, iron_sword)

# How loaded is she?
carrying_weight(alice, W)
   W = 1
item_count(alice, N)
   N = 1

# Anything free to equip into?
slot_available(alice, Slot)
   Slot = alice_main_hand

# What is in her hand?
item_in_slot(alice, alice_main_hand, Item)
```

The pickup flow is: ask `can_carry`, grant the item in the game, then assert
`has_item`. The check and the write are two steps by design; nothing here
mutates state.

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "can_carry(alice, iron_sword)", function(r)
  if #r > 0 then giveItem("alice", "iron_sword"); dg:assert("my-game", { type="relation", subject="alice", relation="has_item", object="iron_sword" }) end
end)
```

## Semantics worth knowing

**`can_carry` wants a specific item.** With the item unbound it cannot answer
"what could she carry": if she holds anything the negation fails outright, and
if she holds nothing the default weight clause leaves the item unbound. Ask
about one item at a time.

**Slots are ignored by weight and count.** Equipped items are not `has_item`
unless you also assert that; `carrying_weight` counts only `has_item`.

**`inventory_full` is at-or-over.** A player exactly at `max_slots` is full,
and `can_carry` is stricter still — it needs room for one more.

## Composing with Other Modules

`combat` reads `damage_type` from whatever you decide the equipped weapon sets;
`quests` and `crafting` read `has_item`; `economy` reads `has_material`, which
is a separate relation.
