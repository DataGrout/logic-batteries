%% ============================================================================
%% FSM — Typed Finite State Machine Reasoning Library
%%
%% General-purpose FSM primitives for agents. Agents assert machine structure
%% and state transitions as LC facts; these rules derive reachability,
%% determinism, dead states, and trace analysis at zero token cost.
%%
%% Standard predicates (agents assert these via logic.assert):
%%
%%   Structural (assert once when defining the machine):
%%     relation(Machine, "has_state", State)     - machine owns this state
%%     relation(State,   "transitions_to", Next) - edge from State to Next
%%     attribute(State,  "on", Event)            - edge fires on Event
%%     attribute(State,  "state_type", "initial")   - initial state marker
%%     attribute(State,  "state_type", "terminal")  - terminal state marker
%%     attribute(Machine, "machine_type", "fsm")    - marks entity as an FSM
%%
%%   Runtime (assert as the machine runs):
%%     attribute(Machine, "current_state", State)   - machine's live state
%%     relation(Machine,  "visited", State)         - states visited so far
%%     relation(Machine,  "trace_step", StepId)     - ordered trace entries
%%     attribute(StepId,  "from_state", From)       - trace: prior state
%%     attribute(StepId,  "to_state",   To)         - trace: next state
%%     attribute(StepId,  "event",      Event)      - trace: triggering event
%%     attribute(StepId,  "step_index", N)          - trace: sequence number
%%
%% Usage:
%%   Agent asserts structural facts into a namespace (e.g. "bench", "_plan_fsm"),
%%   then queries using these rules via logic.query with prolog: "...".
%%
%% Example — Lumen benchmark lap lifecycle:
%%
%%   relation("lap_fsm", "has_state", "idle").
%%   relation("lap_fsm", "has_state", "running").
%%   relation("lap_fsm", "has_state", "complete").
%%   relation("lap_fsm", "has_state", "compared").
%%   attribute("idle",     "state_type", "initial").
%%   attribute("compared", "state_type", "terminal").
%%   relation("idle",     "transitions_to", "running").
%%   attribute("idle",    "on", "start_lap").
%%   relation("running",  "transitions_to", "complete").
%%   attribute("running", "on", "stop_lap").
%%   relation("complete", "transitions_to", "compared").
%%   attribute("complete","on", "compare").
%%   attribute("lap_fsm", "current_state", "running").
%%
%%   ?- fsm_reachable("lap_fsm", "idle", "compared").   % true
%%   ?- fsm_dead_state("lap_fsm", S).                   % false (all states have exits or are terminal)
%%   ?- fsm_deterministic("lap_fsm").                   % true (one event per state)
%% ============================================================================

:- module(fsm, [
    fsm_state/2,
    fsm_current_state/2,
    fsm_initial_state/2,
    fsm_terminal_state/2,
    fsm_transition/4,
    fsm_reachable/3,
    fsm_reachable_states/2,
    fsm_deterministic/1,
    fsm_nondeterministic_state/3,
    fsm_dead_state/2,
    fsm_unreachable_state/2,
    fsm_complete/1,
    fsm_stuck/1,
    fsm_stuck_at/2,
    fsm_visited/2,
    fsm_trace/4,
    fsm_trace_length/2,
    fsm_cycle/2,
    fsm_shortest_path/4,
    fsm_all_paths/4,
    fsm_machines/1,
    fsm_validate/2
]).

:- use_module(logic_cell, [relation/3, attribute/3, lc_flex_match/2]).

%% Manifest (version tracked here, in the registry, and in the README).
battery_module('fsm', '1.0.1', auto).

%% ── Bridge Predicates ────────────────────────────────────────────────────────
%%
%% Agents may assert raw Prolog or structured JSON facts. Both are handled.

fsm_has_state(Machine, State) :-
    relation(Machine, "has_state", State).
fsm_has_state(Machine, State) :-
    raw_fsm_2(has_state, Machine, State).

fsm_edge(From, To) :-
    relation(From, "transitions_to", To).
fsm_edge(From, To) :-
    raw_fsm_2(transitions_to, From, To).

fsm_edge_event(State, Event) :-
    attribute(State, "on", Event).
fsm_edge_event(State, Event) :-
    raw_fsm_attr(on, State, Event).

fsm_state_type(State, Type) :-
    attribute(State, "state_type", Type).
fsm_state_type(State, Type) :-
    raw_fsm_attr(state_type, State, Type).

fsm_current_attr(Machine, State) :-
    attribute(Machine, "current_state", State).
fsm_current_attr(Machine, State) :-
    raw_fsm_attr(current_state, Machine, State).

fsm_visited_attr(Machine, State) :-
    relation(Machine, "visited", State).
fsm_visited_attr(Machine, State) :-
    raw_fsm_2(visited, Machine, State).

raw_fsm_2(Functor, A, B) :-
    Goal =.. [Functor, RA, RB],
    catch(logic_cell:Goal, _, fail),
    lc_flex_match(RA, A),
    lc_flex_match(RB, B).

raw_fsm_attr(Functor, Entity, Value) :-
    Goal =.. [Functor, RE, RV],
    catch(logic_cell:Goal, _, fail),
    lc_flex_match(RE, Entity),
    lc_flex_match(RV, Value).

%% ── Core State Queries ───────────────────────────────────────────────────────

%% fsm_state(+Machine, ?State)
%% True if State belongs to Machine.
fsm_state(Machine, State) :-
    fsm_has_state(Machine, State).

%% fsm_current_state(+Machine, ?State)
%% The live current state of Machine.
fsm_current_state(Machine, State) :-
    fsm_current_attr(Machine, State).

%% fsm_initial_state(+Machine, ?State)
%% State is marked as the initial state for Machine.
fsm_initial_state(Machine, State) :-
    fsm_has_state(Machine, State),
    fsm_state_type(State, "initial").

%% fsm_terminal_state(+Machine, ?State)
%% State is marked as a terminal (accepting) state.
fsm_terminal_state(Machine, State) :-
    fsm_has_state(Machine, State),
    fsm_state_type(State, "terminal").

%% ── Transition Queries ───────────────────────────────────────────────────────

%% fsm_transition(+Machine, ?From, ?Event, ?To)
%% There is an edge From → To that fires on Event in Machine.
%% Event is unbound if none was asserted.
fsm_transition(Machine, From, Event, To) :-
    fsm_has_state(Machine, From),
    fsm_edge(From, To),
    fsm_has_state(Machine, To),
    ( fsm_edge_event(From, E) -> Event = E ; Event = unspecified ).

%% ── Reachability ─────────────────────────────────────────────────────────────

%% fsm_reachable(+Machine, +From, ?To)
%% To is reachable from From in Machine (transitive closure, >= 1 step;
%% fsm_reachable(M, S, S) holds iff S lies on a cycle).
%%
%% Computed as a bottom-up BFS fixpoint over the edge relation — the pure-ISO
%% equivalent of what `:- table` gave the old recursive definition. The
%% recursive version was only cycle-safe UNDER tabling, and tabling never
%% reached logic cells (the installer strips directives on both engines) and
%% does not exist on Scryer — so any machine with a cycle longer than a
%% self-loop hung reachability queries until the watchdog. The fixpoint
%% derives each reachable state exactly once and always terminates.
fsm_reachable(Machine, From, To) :-
    fsm_has_state(Machine, From),
    findall(N, ( fsm_edge(From, N), fsm_has_state(Machine, N) ), Succ0),
    sort(Succ0, Frontier),
    Frontier \== [],
    fsm_reach_closure(Machine, Frontier, Frontier, Set),
    member(To, Set).

%% Internal: expand the frontier until no new states appear.
fsm_reach_closure(Machine, Frontier, Acc, Set) :-
    findall(Next,
            ( member(S, Frontier),
              fsm_edge(S, Next),
              fsm_has_state(Machine, Next),
              \+ member(Next, Acc) ),
            New0),
    sort(New0, New),
    (   New == []
    ->  Set = Acc
    ;   append(Acc, New, Acc1),
        fsm_reach_closure(Machine, New, Acc1, Set)
    ).

%% fsm_reachable_states(+Machine, -States)
%% All states reachable from the initial state.
fsm_reachable_states(Machine, States) :-
    fsm_initial_state(Machine, Init),
    findall(S, (fsm_reachable(Machine, Init, S) ; S = Init), Raw),
    sort(Raw, States).

%% ── Structural Analysis ──────────────────────────────────────────────────────

%% fsm_deterministic(+Machine)
%% True if no state has two outgoing transitions on the same event.
fsm_deterministic(Machine) :-
    \+ fsm_nondeterministic_state(Machine, _, _).

%% fsm_nondeterministic_state(+Machine, ?State, ?Event)
%% State has more than one outgoing transition on Event (ambiguous).
fsm_nondeterministic_state(Machine, State, Event) :-
    fsm_has_state(Machine, State),
    fsm_edge(State, To1),
    fsm_edge(State, To2),
    To1 \== To2,
    fsm_edge_event(State, Event),
    % Both edges fire on the same event — this is the ND condition.
    fsm_edge_event(To1, Event),
    fsm_edge_event(To2, Event).
fsm_nondeterministic_state(Machine, State, unspecified) :-
    fsm_has_state(Machine, State),
    \+ fsm_terminal_state(Machine, State),
    fsm_edge(State, To1),
    fsm_edge(State, To2),
    To1 \== To2,
    \+ fsm_edge_event(State, _).

%% fsm_dead_state(+Machine, ?State)
%% State has no outgoing transitions and is not marked terminal.
%% Dead states indicate incomplete machine definitions.
fsm_dead_state(Machine, State) :-
    fsm_has_state(Machine, State),
    \+ fsm_terminal_state(Machine, State),
    \+ fsm_edge(State, _).

%% fsm_unreachable_state(+Machine, ?State)
%% State cannot be reached from any initial state.
fsm_unreachable_state(Machine, State) :-
    fsm_has_state(Machine, State),
    \+ fsm_initial_state(Machine, State),
    fsm_initial_state(Machine, Init),
    \+ fsm_reachable(Machine, Init, State).

%% ── Runtime Status ───────────────────────────────────────────────────────────

%% fsm_complete(+Machine)
%% Machine's current state is a terminal state.
fsm_complete(Machine) :-
    fsm_current_state(Machine, State),
    fsm_terminal_state(Machine, State).

%% fsm_stuck(+Machine)
%% Machine is not in a terminal state and has no outgoing transitions.
fsm_stuck(Machine) :-
    fsm_current_state(Machine, State),
    \+ fsm_terminal_state(Machine, State),
    \+ fsm_edge(State, _).

%% fsm_stuck_at(+Machine, ?State)
%% Machine is stuck at a specific non-terminal, non-exiting state.
fsm_stuck_at(Machine, State) :-
    fsm_stuck(Machine),
    fsm_current_state(Machine, State).

%% fsm_visited(+Machine, ?State)
%% Machine has visited State at some point in its execution.
fsm_visited(Machine, State) :-
    fsm_visited_attr(Machine, State).

%% ── Trace Analysis ───────────────────────────────────────────────────────────

%% fsm_trace(+Machine, ?From, ?Event, ?To)
%% A recorded trace step: Machine moved from From to To on Event.
fsm_trace(Machine, From, Event, To) :-
    relation(Machine, "trace_step", StepId),
    attribute(StepId, "from_state", From),
    attribute(StepId, "to_state", To),
    ( attribute(StepId, "event", E) -> Event = E ; Event = unspecified ).

%% fsm_trace_length(+Machine, ?N)
%% Number of recorded trace steps for Machine.
fsm_trace_length(Machine, N) :-
    findall(_, fsm_trace(Machine, _, _, _), Steps),
    length(Steps, N).

%% ── Cycle Detection ──────────────────────────────────────────────────────────

%% fsm_cycle(+Machine, ?State)
%% State is part of a cycle (can reach itself).
fsm_cycle(Machine, State) :-
    fsm_has_state(Machine, State),
    fsm_reachable(Machine, State, State).

%% ── Path Finding ─────────────────────────────────────────────────────────────

%% fsm_shortest_path(+Machine, +From, +To, -Path)
%% Shortest sequence of states from From to To (BFS via iterative deepening).
fsm_shortest_path(Machine, From, To, Path) :-
    fsm_path_dl(Machine, From, To, [From], Path).

fsm_path_dl(_, To, To, Visited, Path) :-
    reverse(Visited, Path).
fsm_path_dl(Machine, From, To, Visited, Path) :-
    fsm_edge(From, Next),
    fsm_has_state(Machine, Next),
    \+ member(Next, Visited),
    fsm_path_dl(Machine, Next, To, [Next|Visited], Path).

%% fsm_all_paths(+Machine, +From, +To, -Paths)
%% All acyclic paths from From to To (bounded by visited set).
fsm_all_paths(Machine, From, To, Paths) :-
    findall(Path, fsm_path_dl(Machine, From, To, [From], Path), Paths).

%% ── Machine Inventory ────────────────────────────────────────────────────────

%% fsm_machines(-Machines)
%% All entities in the LC that are known FSMs.
fsm_machines(Machines) :-
    findall(M, (
        attribute(M, "machine_type", T),
        lc_flex_match(T, "fsm")
    ), Raw),
    sort(Raw, Machines).

%% ── Validation ───────────────────────────────────────────────────────────────

%% fsm_validate(+Machine, -Issues)
%% Returns a list of structural issues with the machine definition.
%% Issues: dead_state(S), unreachable_state(S), nondeterministic(S, Event),
%%         no_initial_state, no_terminal_state, cycle(S).
fsm_validate(Machine, Issues) :-
    findall(Issue, fsm_issue(Machine, Issue), Raw),
    sort(Raw, Issues).

fsm_issue(Machine, no_initial_state) :-
    \+ fsm_initial_state(Machine, _).
fsm_issue(Machine, no_terminal_state) :-
    \+ fsm_terminal_state(Machine, _).
fsm_issue(Machine, dead_state(S)) :-
    fsm_dead_state(Machine, S).
fsm_issue(Machine, unreachable_state(S)) :-
    fsm_unreachable_state(Machine, S).
fsm_issue(Machine, nondeterministic(S, Event)) :-
    fsm_nondeterministic_state(Machine, S, Event).
fsm_issue(Machine, cycle(S)) :-
    fsm_cycle(Machine, S).
