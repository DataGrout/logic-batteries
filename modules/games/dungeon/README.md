# Module: dungeon v1.0.0

Room connectivity, key-locked access, DFS pathfinding through accessible rooms, room clearance tracking, and dungeon completion detection.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["dungeon"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("dungeon", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `room_connected(Room1, Room2)` | Rooms share a directed passage |
| `room_accessible(Player, Room)` | Player can enter Room (unlocked or holds the key) |
| `dungeon_path(Player, From, Path)` | List of accessible rooms reachable from From (DFS) |
| `room_cleared(Player, Room)` | Player has visited and cleared Room |
| `dungeon_complete(Player, Dungeon)` | Player has cleared every room in Dungeon |

## Setup

### Room connections

Connections are directed — assert both directions for bidirectional passages:

```lua
local ns = "my-game"

dg:assert(ns, { type="relation", subject="entrance",   relation="connects_to", object="corridor_a" })
dg:assert(ns, { type="relation", subject="corridor_a", relation="connects_to", object="entrance"   }) -- bidirectional
dg:assert(ns, { type="relation", subject="corridor_a", relation="connects_to", object="boss_room"  })
```

### Locked rooms

```lua
dg:assert(ns, { type="attribute", entity="boss_room", attribute="requires_key", value="iron_key" })
```

Keys are checked against `relation(player, has_item, key)` — the inventory battery provides this if you're using it.

### Dungeon membership

```lua
dg:assert(ns, { type="relation", subject="catacombs", relation="has_room", object="entrance"   })
dg:assert(ns, { type="relation", subject="catacombs", relation="has_room", object="corridor_a" })
dg:assert(ns, { type="relation", subject="catacombs", relation="has_room", object="boss_room"  })
```

### Clearance tracking

Clearance is keyed as `<player>_dungeon`:

```lua
-- Record when alice clears a room
dg:assert(ns, { type="relation", subject="alice_dungeon", relation="cleared", object="entrance" })
```

## Querying

```lua
-- Check if alice can enter the boss room
dg:query(ns, "room_accessible(alice, boss_room)", function(result)
  if result then openBossRoom() end
end)

-- Get the full accessible path from the entrance
dg:query(ns, "dungeon_path(alice, entrance, Path)", function(result)
  highlightMinimap(result.Path)
end)

-- Check if the dungeon is complete
dg:query(ns, "dungeon_complete(alice, catacombs)", function(result)
  if result then triggerVictory() end
end)
```

## Design Notes

**Connections are directed by design.** One-way passages (trap doors, slides, portals) are modelled naturally — assert `connects_to` in only one direction. Bidirectional passages require two assertions.

**Pathfinding is DFS, not shortest-path.** `dungeon_path` finds an accessible route, not necessarily the optimal one. For shortest path, use the `fsm` battery's `fsm_shortest_path` predicate after modelling rooms as FSM states.

**Clearance keys are scoped per-player.** Multiple players in the same dungeon have independent clearance state — `alice_dungeon` and `bob_dungeon` are separate fact sets.
