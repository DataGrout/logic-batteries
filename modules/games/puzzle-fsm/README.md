# Module: puzzle-fsm v1.0.1

A puzzle as a small state machine: which moves are open from the current
state, whether it is solved, a move sequence that solves it, a hint, and why
it is stuck.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["puzzle-fsm"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("puzzle-fsm", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `can_transition(Puzzle, Move, NextState)` | A `move` out of the current state whose item gate is met |
| `puzzle_solved(Puzzle)` | The current state is a solve state |
| `valid_sequence(Puzzle, Moves)` | A move list from `initial_state` to a solve state, depth-first without revisiting states |
| `hint_for(Puzzle, Move)` | The first open move — one answer only |
| `blocked_by(Puzzle, Reason)` | `already_solved`, `missing_item(Item)`, or `no_moves` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `initial_state` | puzzle | a state id | Where the puzzle starts, and where `valid_sequence` starts from |
| `current_state` | puzzle | a state id | Where it is now; falls back to `initial_state`. You assert the new state after a move |
| `solve_state` | puzzle | a state id | A winning state (single). For several, use the relation below |
| `leads_to` | move | a state id | Where the move goes |
| `requires_item` | move | an item id | The move is open only if the item is available — see `player_has` and `player` |
| `player` | puzzle | a player id | Whose inventory the puzzle may draw on: with this set, the player's `has_item` satisfies `requires_item` |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `move` | state → move | A move available from that state |
| `solve_state` | puzzle → state | A winning state; any number of these |
| `player_has` | puzzle → item | The item is available to this puzzle directly, without going through a player |
| `has_item` | player → item | The `inventory` battery's shape; read when the puzzle names its `player` |

## Setup

```
# Structure
{ type="attribute", entity="chest",  attribute="initial_state", value="locked" }
{ type="attribute", entity="chest",  attribute="solve_state",   value="open" }
{ type="relation",  subject="locked", relation="move",          object="use_key" }
{ type="attribute", entity="use_key", attribute="leads_to",     value="open" }

# An item gate, satisfied through the player's inventory…
{ type="attribute", entity="use_key", attribute="requires_item", value="brass_key" }
{ type="attribute", entity="chest",   attribute="player",        value="alice" }
{ type="relation",  subject="alice",  relation="has_item",       object="brass_key" }

# …or by making the item available to the puzzle directly
{ type="relation",  subject="chest",  relation="player_has",     object="brass_key" }

# Several winning states
{ type="relation", subject="door", relation="solve_state", object="open_left" }
{ type="relation", subject="door", relation="solve_state", object="open_right" }

# Runtime: after the player makes a move, record where the puzzle is
{ type="attribute", entity="chest", attribute="current_state", value="open" }
```

## Querying

```
# What can the player do here?
can_transition(chest, Move, Next)
   Move = use_key, Next = open

# Solved?
puzzle_solved(chest)

# A solution, for a tutorial or auto-solve
valid_sequence(chest, Moves)
   Moves = [use_key]

# Stuck why?
blocked_by(chest, Reason)
   Reason = missing_item(brass_key)
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "blocked_by(chest, R)", function(r) if r[1] then explain(r[1].R) end end)
```

## Semantics worth knowing

**Two ways to hold an item.** Give the puzzle a `player` and its item gates
read that player's `has_item` — the relation `inventory` maintains, so a
pickup there opens the move here with no mirroring. Or assert `player_has` on
the puzzle for a puzzle with no particular player.

**Moves do not move.** Nothing here changes `current_state`; apply the move in
the game and assert the new state.

**`hint_for` is one move.** It commits to the first open move in fact order.
For all open moves, ask `can_transition` instead.

**`valid_sequence` uses the puzzle's items as they are now.** A path through a
gated move is found only if the item is already available; it will not plan
"get the key, then use it".

## Blocked Reasons

| Reason | Meaning |
|---|---|
| `already_solved` | Current state is a solve state |
| `missing_item(Item)` | An outgoing move needs an item the puzzle does not have |
| `no_moves` | The current state has no `move` at all |

## Composing with Other Modules

`quests` for solving as an objective; `fsm` for reachability and cycle analysis
over the same state graph; `inventory` for the `has_item` a `player` puzzle
reads.

## Changes

**1.0.1** — a puzzle with a `player` attribute reads that player's `has_item`
for its item gates; before, only `player_has` on the puzzle itself counted and
`inventory` was never consulted. The unused `requires_state` check on moves
was removed: it could only ever repeat the state a move already hangs off.
