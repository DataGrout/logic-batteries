# Module: dungeon v1.0.1

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
| `dungeon_path(Player, From, Path)` | Maximal walks of accessible rooms from From, depth-first: one solution per dead end |
| `room_cleared(Player, Room)` | The player has cleared the room, by either per-player shape |
| `room_cleared(Player, Dungeon, Room)` | Cleared in that dungeon — the per-dungeon key, falling back to the per-player shapes |
| `dungeon_complete(Player, Dungeon)` | Every room the dungeon `has_room` is cleared, per `room_cleared/3` |

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
| `cleared_room` | player → room | The player has cleared the room — the simple per-player shape |
| `cleared` | `<player>_<dungeon>` → room | Per dungeon, on a composite entity: `alice_catacombs`. Read by `room_cleared/3` and `dungeon_complete`. The older `<player>_dungeon` key (literal suffix) is still read as a per-player shape |

Use one shape. The per-dungeon key is the one to prefer when two dungeons can
share a room name.

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

# As alice clears rooms, per dungeon
{ type="relation", subject="alice_catacombs", relation="cleared", object="entrance" }
{ type="relation", subject="alice_catacombs", relation="cleared", object="corridor_a" }
```

## Querying

```
# May she enter?
room_accessible(alice, boss_room)

# Where can she get to from the entrance? (one walk per dead end)
dungeon_path(alice, entrance, Path)
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

**`dungeon_path` returns maximal walks.** Each solution ends where no unvisited
accessible room remains, so a branching dungeon yields one path per dead end
and a corridor yields one path. It is depth-first, not shortest — for that,
model rooms as states in the `fsm` battery.

**Clearance can be per dungeon.** With the `<player>_<dungeon>` key, the same
room name in two dungeons is two separate clearances. The two per-player
shapes (`cleared_room`, and the older `<player>_dungeon` key) still count
everywhere, so mixing them with the per-dungeon key gives per-player
behaviour for those rooms.

**Passages are one-way.** Trap doors, slides and portals fall out of this for
free; ordinary doors need two facts.

**Accessibility is not reachability.** `room_accessible` looks only at the
lock; a room can be accessible and still unreachable from where the player is.
`dungeon_path` is what combines the two.

## What this battery does not do

- No shortest path, no path cost.
- No key consumption; holding the key is enough, and it stays held.

## Changes

**1.0.1** — `dungeon_path` returns maximal walks instead of every prefix (its
first answer used to be `[From]` alone). `room_cleared/3` and
`dungeon_complete` read a per-dungeon `<player>_<dungeon>` key; the source's
own comment had promised that key while the code used a fixed `_dungeon`
suffix.
