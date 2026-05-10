# Module: puzzle-fsm v1.0.0

State-based puzzle logic: transitions, win condition detection, hint generation, sequence validation, and blocked-state diagnosis.

## Install

```lua
dg:batteries().install("puzzle-fsm", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```

> Lua examples use [Tether](https://github.com/datagrout/tether), the Lua client for DataGrout.

## Exported Predicates

| Predicate | Description |
|---|---|
| `can_transition(Puzzle, Move, NextState)` | Move is valid from current state; NextState is where it leads |
| `puzzle_solved(Puzzle)` | Puzzle is in a winning state |
| `valid_sequence(Puzzle, Moves)` | Moves is a sequence that leads from the initial state to a solved state |
| `hint_for(Puzzle, Move)` | Move is a valid next step toward solving Puzzle |
| `blocked_by(Puzzle, Reason)` | Reason explains why Puzzle cannot be progressed |

## Setup

### States and transitions

```lua
-- Define puzzle structure: initial state, solve state, transitions
dg:assert("my-game", { type="attribute", entity="chest", attribute="initial_state", value="locked" })
dg:assert("my-game", { type="attribute", entity="chest", attribute="solve_state",   value="open"   })

dg:assert("my-game", { type="relation",  subject="locked",  relation="move",     object="use_key" })
dg:assert("my-game", { type="attribute", entity="use_key",  attribute="leads_to", value="open"    })
```

### Runtime state

```lua
-- Track the puzzle's current state at runtime
-- (defaults to initial_state if not set)
dg:assert("my-game", { type="attribute", entity="chest", attribute="current_state", value="locked" })
```

### Item-gated transitions

```lua
-- Move only available if player is carrying the required item
dg:assert("my-game", { type="attribute", entity="use_key", attribute="requires_item", value="brass_key" })
dg:assert("my-game", { type="relation",  subject="chest",  relation="player_has",     object="brass_key" })
```

### Multiple solve states

```lua
-- Either state counts as a win
dg:assert("my-game", { type="relation", subject="door", relation="solve_state", object="open_left"  })
dg:assert("my-game", { type="relation", subject="door", relation="solve_state", object="open_right" })
```

## Usage

```lua
-- What moves are available right now?
dg:query("my-game", "can_transition(chest, Move, NextState)", function(results)
  for _, r in ipairs(results) do
    showMoveOption(r.Move, r.NextState)
  end
end)

-- Is this puzzle solved?
dg:query("my-game", "puzzle_solved(chest)", function(results)
  if #results > 0 then triggerPuzzleComplete() end
end)

-- What should the player do next? (hint system)
dg:query("my-game", "hint_for(chest, Move)", function(results)
  if results[1] then showHint(results[1].Move) end
end)

-- Why can't the player progress?
dg:query("my-game", "blocked_by(chest, Reason)", function(results)
  if results[1] then
    local r = results[1].Reason
    if r == "no_moves" then
      showMessage("No moves available from this state.")
    elseif r == "already_solved" then
      showMessage("Already solved!")
    else
      -- missing_item(ItemName)
      showMessage("You need: " .. tostring(r))
    end
  end
end)

-- Find the full solution path (useful for tutorial or auto-solve)
dg:query("my-game", "valid_sequence(chest, Moves)", function(results)
  if results[1] then playSolutionSequence(results[1].Moves) end
end)

-- Apply a move: advance current state
local function applyMove(puzzle, move, nextState)
  dg:assert("my-game", {
    type="attribute", entity=puzzle, attribute="current_state", value=nextState
  })
end
```

## Blocked Reasons

| Reason | Meaning |
|---|---|
| `already_solved` | Puzzle is in a solve state — no further moves needed |
| `missing_item(Item)` | A move exists but requires Item the player doesn't have |
| `no_moves` | Current state has no outgoing transitions at all |

## Composing with Other Modules

Works naturally with `inventory` (player item checks for `requires_item`), `quests` (puzzle completion as a quest objective), and `fsm` (for puzzles that need full reachability analysis or cycle detection).
