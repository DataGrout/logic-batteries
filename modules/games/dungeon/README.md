# Module: dungeon v1.0.0

Room connectivity, key-locked access, a depth-first walk through the rooms a
player can reach, clearance tracking, and dungeon completion.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["dungeon"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("dungeon", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `room_connected(Room1, Room2)` | A directed passage from Room1 to Room2 |
| `room_accessible(Player, Room)` | Room has no `requires_key`, or the player `has_item` the key |
| `dungeon_path(Player, From, Path)` | Paths of accessible rooms from From, depth-first; every prefix is a solution — see below |
| `room_cleared(Player, Room)` | The player has cleared the room, by either clearance shape |
| `dungeon_complete(Player, Dungeon)` | Every room the dungeon `has_room` is cleared |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `requires_key` | room | an item id | The room is locked; the player must hold this item to enter |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `connects_to` | room → room | A one-way passage. Assert both directions for a door you can walk back through |
| `has_room` | dungeon → room | Membership; `dungeon_complete` checks exactly these rooms |
| `has_item` | player → item | Satisfies `requires_key` (the `inventory` battery asserts this shape) |
| `cleared_room` | player → room | The player has cleared the room — the simple shape |
| `cleared` | `<player>_dungeon` → room | The same, on a composite entity: `alice_dungeon`. The suffix is the literal word `dungeon`, not a dungeon id |

Either clearance shape satisfies `room_cleared`; use one.

## Setup

```
# Passages (directed)
{ type="relation", subject="entrance",   relation="connects_to", object="corridor_a" }
{ type="relation", subject="corridor_a", relation="connects_to", object="entrance" }
{ type="relation", subject="corridor_a", relation="connects_to", object="boss_room" }

# A locked room
{ type="attribute", entity="boss_room", attribute="requires_key", value="iron_key" }

# Membership
{ type="relation", subject="catacombs", relation="has_room", object="entrance" }
{ type="relation", subject="catacombs", relation="has_room", object="corridor_a" }
{ type="relation", subject="catacombs", relation="has_room", object="boss_room" }

# The player
{ type="relation", subject="alice", relation="has_item", object="iron_key" }

# As alice clears rooms
{ type="relation", subject="alice", relation="cleared_room", object="entrance" }
{ type="relation", subject="alice", relation="cleared_room", object="corridor_a" }
```

## Querying

```
# May she enter?
room_accessible(alice, boss_room)

# Where can she get to from the entrance? (the longest solution is the full walk)
dungeon_path(alice, entrance, Path)
   Path = [entrance] ;
   Path = [entrance, corridor_a] ;
   Path = [entrance, corridor_a, boss_room]

# Done yet?
dungeon_complete(alice, catacombs)
   false
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "dungeon_complete(alice, catacombs)", function(r) if #r > 0 then triggerVictory() end end)
```

## Semantics worth knowing

**`dungeon_path` returns every prefix.** The first solution is `[From]` alone;
each further solution extends the walk by one accessible room. Take the last
solution for the full reachable path, or use `findall` and pick the longest.
It is a depth-first walk, not a shortest path — for that, model rooms as states
in the `fsm` battery.

**Clearance is per player, not per dungeon.** Both clearance shapes key on the
player only. If two dungeons each have a room called `entrance`, clearing one
clears the other. Give rooms dungeon-unique ids.

**Passages are one-way.** Trap doors, slides and portals fall out of this for
free; ordinary doors need two facts.

**Accessibility is not reachability.** `room_accessible` looks only at the
lock; a room can be accessible and still unreachable from where the player is.
`dungeon_path` is what combines the two.

## What this battery does not do

- No shortest path, no path cost.
- No per-dungeon clearance state.
- No key consumption; holding the key is enough, and it stays held.
