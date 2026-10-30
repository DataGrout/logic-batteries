# Module: fsm v1.1.0

General-purpose finite state machine reasoning library for DataGrout Logic Cells. Assert machine structure once; query reachability, structural issues, runtime status, and paths at zero token cost.

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["fsm"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("fsm", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

### State Queries
| Predicate | Description |
|---|---|
| `fsm_state(Machine, State)` | State belongs to Machine |
| `fsm_current_state(Machine, State)` | Machine's live current state |
| `fsm_initial_state(Machine, State)` | State is the initial state |
| `fsm_terminal_state(Machine, State)` | State is a terminal (accepting) state |

### Transition Queries
| Predicate | Description |
|---|---|
| `fsm_transition(Machine, From, Event, To)` | Edge From→To fires on Event |

### Reachability
| Predicate | Description |
|---|---|
| `fsm_reachable(Machine, From, To)` | To is reachable from From (transitive) |
| `fsm_reachable_states(Machine, States)` | All states reachable from initial state |

### Structural Analysis
| Predicate | Description |
|---|---|
| `fsm_deterministic(Machine)` | No state is provably ambiguous (see below) |
| `fsm_nondeterministic_state(Machine, State, Event)` | State has more exits than events; Event is the one event, or `unspecified` |
| `fsm_dead_state(Machine, State)` | State has no exits and is not terminal |
| `fsm_unreachable_state(Machine, State)` | State cannot be reached from initial state |

### Runtime Status
| Predicate | Description |
|---|---|
| `fsm_complete(Machine)` | Current state is terminal |
| `fsm_stuck(Machine)` | Not terminal, no outgoing transitions |
| `fsm_stuck_at(Machine, State)` | Machine is stuck at State |
| `fsm_visited(Machine, State)` | Machine has visited State |

### Trace Analysis
| Predicate | Description |
|---|---|
| `fsm_trace(Machine, From, Event, To)` | Recorded trace step |
| `fsm_trace_length(Machine, N)` | Number of recorded steps |

### Path Finding
| Predicate | Description |
|---|---|
| `fsm_cycle(Machine, State)` | State is part of a cycle |
| `fsm_shortest_path(Machine, From, To, Path)` | A shortest state sequence From→To by edge count (breadth-first; one answer) |
| `fsm_all_paths(Machine, From, To, Paths)` | All acyclic paths From→To |

### Inventory & Validation
| Predicate | Description |
|---|---|
| `fsm_machines(Machines)` | All FSM entities in the namespace |
| `fsm_validate(Machine, Issues)` | Structural issues: dead states, unreachable states, non-determinism |

## Setup

```prolog
%% Assert machine structure (do this once)
relation("lap_fsm", "has_state",       "idle").
relation("lap_fsm", "has_state",       "running").
relation("lap_fsm", "has_state",       "complete").
attribute("idle",    "state_type",     "initial").
attribute("complete","state_type",     "terminal").
attribute("lap_fsm", "machine_type",   "fsm").

relation("idle",    "transitions_to",  "running").
attribute("idle",   "on",              "start_lap").
relation("running", "transitions_to",  "complete").
attribute("running","on",              "stop_lap").

%% Assert runtime state as the machine runs
attribute("lap_fsm", "current_state",  "running").
relation("lap_fsm",  "visited",        "idle").
```

## Usage

```prolog
%% Is "complete" reachable from "idle"?
?- fsm_reachable("lap_fsm", "idle", "complete").   %% true

%% Any structural problems?
?- fsm_validate("lap_fsm", Issues).
%% Issues = [] (clean machine)

%% Has the machine finished?
?- fsm_complete("lap_fsm").   %% fails — current state is "running"

%% Shortest path from idle to complete
?- fsm_shortest_path("lap_fsm", "idle", "complete", Path).
%% Path = ["idle", "running", "complete"]
```

## Semantics worth knowing

**Events belong to states, not edges.** `attribute(State, on, Event)` says
State's exits fire on Event; nothing says which event takes which exit. So
`fsm_nondeterministic_state/3` reports only what the facts prove: a state with
more distinct exits than distinct events must fire two exits on one event.
Event is that event when the state has exactly one, and `unspecified` when it
has none or several (some one is shared, the facts do not say which). A state
with at least as many events as exits — `review` on `approve` and `reject`,
leaving for `approved` and `rejected` — is not flagged: a one-to-one reading
exists, though the facts cannot confirm it. Each ambiguous state is reported
once. `fsm_deterministic/1` is the absence of any such state.

**Shortest means fewest edges.** `fsm_shortest_path/4` searches breadth-first
with a visited set, so it terminates on cycles and fails when To is
unreachable. Ties go to the path found first in fact order.

## Use Cases

- **Agent plan tracking** — model a multi-step plan as an FSM, query `fsm_complete` to know when done
- **Workflow approval flows** — states: `draft → review → approved/rejected`; query stuck states to detect stalled approvals  
- **Game puzzles** — model puzzle states and transitions; `fsm_validate` catches broken puzzle definitions
- **Protocol state** — track connection or session lifecycle; `fsm_reachable` verifies all exit paths exist
