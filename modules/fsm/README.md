# Module: fsm v1.0.0

General-purpose finite state machine reasoning library for DataGrout Logic Cells. Assert machine structure once; query reachability, structural issues, runtime status, and paths at zero token cost.

## Install

```json
{ "tool": "lc.packages.install", "module": "fsm", "namespace": "my-namespace" }
```

For Lua / Roblox access, use [Tether](https://github.com/datagrout/tether).

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
| `fsm_deterministic(Machine)` | No state has two outgoing transitions on the same event |
| `fsm_nondeterministic_state(Machine, State, Event)` | State is ambiguous on Event |
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
| `fsm_shortest_path(Machine, From, To, Path)` | Shortest state sequence From→To |
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

## Use Cases

- **Agent plan tracking** — model a multi-step plan as an FSM, query `fsm_complete` to know when done
- **Workflow approval flows** — states: `draft → review → approved/rejected`; query stuck states to detect stalled approvals  
- **Game puzzles** — model puzzle states and transitions; `fsm_validate` catches broken puzzle definitions
- **Protocol state** — track connection or session lifecycle; `fsm_reachable` verifies all exit paths exist
