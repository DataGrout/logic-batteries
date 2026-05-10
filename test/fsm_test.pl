:- use_module(library(plunit)).
:- use_module('../modules/fsm/fsm').

%% (clear_facts/0 is in test/support/test_helpers.pl)
%%
%% All assertz calls use logic_cell: prefix because fsm.pl imports relation/3
%% and attribute/3 from the logic_cell module via use_module(logic_cell, [...]).

%% ── Base machine setups ───────────────────────────────────────────────────────

%% Linear machine: idle → running → complete
setup_linear :-
    clear_facts,
    assertz(logic_cell:relation("m", "has_state", "idle")),
    assertz(logic_cell:relation("m", "has_state", "running")),
    assertz(logic_cell:relation("m", "has_state", "complete")),
    assertz(logic_cell:attribute("idle",    "state_type", "initial")),
    assertz(logic_cell:attribute("complete","state_type", "terminal")),
    assertz(logic_cell:attribute("m",       "machine_type", "fsm")),
    assertz(logic_cell:relation("idle",    "transitions_to", "running")),
    assertz(logic_cell:attribute("idle",   "on", "start_lap")),
    assertz(logic_cell:relation("running", "transitions_to", "complete")),
    assertz(logic_cell:attribute("running","on", "stop_lap")).

%% Branching machine: draft → review → approved | rejected
setup_branching :-
    clear_facts,
    assertz(logic_cell:relation("wf", "has_state", "draft")),
    assertz(logic_cell:relation("wf", "has_state", "review")),
    assertz(logic_cell:relation("wf", "has_state", "approved")),
    assertz(logic_cell:relation("wf", "has_state", "rejected")),
    assertz(logic_cell:attribute("draft",    "state_type", "initial")),
    assertz(logic_cell:attribute("approved", "state_type", "terminal")),
    assertz(logic_cell:attribute("rejected", "state_type", "terminal")),
    assertz(logic_cell:attribute("wf",       "machine_type", "fsm")),
    assertz(logic_cell:relation("draft",  "transitions_to", "review")),
    assertz(logic_cell:attribute("draft", "on", "submit")),
    assertz(logic_cell:relation("review", "transitions_to", "approved")),
    assertz(logic_cell:attribute("review","on", "approve")),
    assertz(logic_cell:relation("review", "transitions_to", "rejected")),
    assertz(logic_cell:attribute("review","on", "reject")).

%% Machine with structural defects: s3 is dead, s4 is unreachable
setup_defective :-
    clear_facts,
    assertz(logic_cell:relation("bad", "has_state", "s1")),
    assertz(logic_cell:relation("bad", "has_state", "s2")),
    assertz(logic_cell:relation("bad", "has_state", "s3")),
    assertz(logic_cell:relation("bad", "has_state", "s4")),
    assertz(logic_cell:attribute("s1", "state_type", "initial")),
    assertz(logic_cell:attribute("s2", "state_type", "terminal")),
    assertz(logic_cell:relation("s1", "transitions_to", "s2")).

%% Non-deterministic: s1 has two unlabelled outgoing edges
setup_nondeterministic :-
    clear_facts,
    assertz(logic_cell:relation("nd", "has_state", "s1")),
    assertz(logic_cell:relation("nd", "has_state", "s2")),
    assertz(logic_cell:relation("nd", "has_state", "s3")),
    assertz(logic_cell:attribute("s1", "state_type", "initial")),
    assertz(logic_cell:attribute("s2", "state_type", "terminal")),
    assertz(logic_cell:attribute("s3", "state_type", "terminal")),
    assertz(logic_cell:relation("s1", "transitions_to", "s2")),
    assertz(logic_cell:relation("s1", "transitions_to", "s3")).

%% Cyclic: a → b → a
setup_cyclic :-
    clear_facts,
    assertz(logic_cell:relation("cyc", "has_state", "a")),
    assertz(logic_cell:relation("cyc", "has_state", "b")),
    assertz(logic_cell:attribute("a", "state_type", "initial")),
    assertz(logic_cell:relation("a", "transitions_to", "b")),
    assertz(logic_cell:relation("b", "transitions_to", "a")).

%% Minimal machine with no event labels
setup_eventless_machine :-
    clear_facts,
    assertz(logic_cell:relation("m", "has_state", "s1")),
    assertz(logic_cell:relation("m", "has_state", "s2")),
    assertz(logic_cell:attribute("s1", "state_type", "initial")),
    assertz(logic_cell:attribute("s2", "state_type", "terminal")),
    assertz(logic_cell:relation("s1", "transitions_to", "s2")).

%% Machine with no initial state (for validation tests)
setup_no_initial :-
    clear_facts,
    assertz(logic_cell:relation("x", "has_state", "s1")),
    assertz(logic_cell:attribute("s1", "state_type", "terminal")).

%% Machine with no terminal state (for validation tests)
setup_no_terminal :-
    clear_facts,
    assertz(logic_cell:relation("x", "has_state", "s1")),
    assertz(logic_cell:attribute("s1", "state_type", "initial")),
    assertz(logic_cell:relation("s1", "transitions_to", "s1")).

%% ── Composite setups (linear + runtime state) ─────────────────────────────────

setup_linear_at(State) :-
    setup_linear,
    assertz(logic_cell:attribute("m", "current_state", State)).

setup_linear_running :- setup_linear_at("running").
setup_linear_complete :- setup_linear_at("complete").

setup_defective_stuck :-
    setup_defective,
    assertz(logic_cell:attribute("bad", "current_state", "s3")).

setup_linear_visited :-
    setup_linear,
    assertz(logic_cell:relation("m", "visited", "idle")).

setup_two_machines :-
    setup_linear,
    assertz(logic_cell:attribute("m2", "machine_type", "fsm")).

%% ── Trace setup ───────────────────────────────────────────────────────────────

setup_trace :-
    setup_linear,
    assertz(logic_cell:relation("m", "trace_step", "step1")),
    assertz(logic_cell:attribute("step1", "from_state", "idle")),
    assertz(logic_cell:attribute("step1", "to_state",   "running")),
    assertz(logic_cell:attribute("step1", "event",      "start_lap")),
    assertz(logic_cell:attribute("step1", "step_index", 1)),
    assertz(logic_cell:relation("m", "trace_step", "step2")),
    assertz(logic_cell:attribute("step2", "from_state", "running")),
    assertz(logic_cell:attribute("step2", "to_state",   "complete")),
    assertz(logic_cell:attribute("step2", "event",      "stop_lap")),
    assertz(logic_cell:attribute("step2", "step_index", 2)).

%% ── State queries ─────────────────────────────────────────────────────────────

:- begin_tests(fsm_state_queries).

test(state_membership, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(fsm_state("m", "idle")),
    assertion(fsm_state("m", "running")),
    assertion(fsm_state("m", "complete")),
    assertion(\+ fsm_state("m", "nonexistent")).

test(initial_state, [setup(setup_linear), cleanup(clear_facts)]) :-
    fsm_initial_state("m", S),
    assertion(S == "idle").

test(terminal_state, [setup(setup_linear), cleanup(clear_facts)]) :-
    fsm_terminal_state("m", S),
    assertion(S == "complete").

test(multiple_terminals, [setup(setup_branching), cleanup(clear_facts)]) :-
    findall(S, fsm_terminal_state("wf", S), Ts),
    sort(Ts, Sorted),
    assertion(Sorted == ["approved", "rejected"]).

test(current_state, [setup(setup_linear_running), cleanup(clear_facts)]) :-
    fsm_current_state("m", S),
    assertion(S == "running").

:- end_tests(fsm_state_queries).

%% ── Transition queries ────────────────────────────────────────────────────────

:- begin_tests(fsm_transitions).

test(transition_with_event, [setup(setup_linear), cleanup(clear_facts)]) :-
    fsm_transition("m", "idle", Event, "running"),
    assertion(Event == "start_lap").

test(transition_without_event, [setup(setup_eventless_machine), cleanup(clear_facts)]) :-
    fsm_transition("m", "s1", Event, "s2"),
    assertion(Event == unspecified).

test(all_transitions_found, [setup(setup_branching), cleanup(clear_facts)]) :-
    findall(To, fsm_transition("wf", "review", _, To), Tos),
    sort(Tos, Sorted),
    assertion(Sorted == ["approved", "rejected"]).

:- end_tests(fsm_transitions).

%% ── Reachability ─────────────────────────────────────────────────────────────

:- begin_tests(fsm_reachability).

test(direct_reachable, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(fsm_reachable("m", "idle", "running")).

test(transitive_reachable, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(fsm_reachable("m", "idle", "complete")).

test(not_reachable_backwards, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(\+ fsm_reachable("m", "complete", "idle")).

test(reachable_states_from_initial, [setup(setup_linear), cleanup(clear_facts)]) :-
    fsm_reachable_states("m", States),
    sort(States, Sorted),
    assertion(Sorted == ["complete", "idle", "running"]).

test(branching_all_reachable, [setup(setup_branching), cleanup(clear_facts)]) :-
    fsm_reachable_states("wf", States),
    sort(States, Sorted),
    assertion(Sorted == ["approved", "draft", "rejected", "review"]).

:- end_tests(fsm_reachability).

%% ── Structural analysis ───────────────────────────────────────────────────────

:- begin_tests(fsm_structural).

test(deterministic_linear, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(fsm_deterministic("m")).

test(nondeterministic_detected, [setup(setup_nondeterministic), cleanup(clear_facts)]) :-
    assertion(\+ fsm_deterministic("nd")),
    fsm_nondeterministic_state("nd", State, _Event),
    assertion(State == "s1").

test(dead_state_detected, [setup(setup_defective), cleanup(clear_facts)]) :-
    fsm_dead_state("bad", Dead),
    assertion(Dead == "s3").

test(no_dead_states_in_clean_machine, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(\+ fsm_dead_state("m", _)).

test(unreachable_state_detected, [setup(setup_defective), cleanup(clear_facts)]) :-
    findall(S, fsm_unreachable_state("bad", S), Us),
    sort(Us, Sorted),
    assertion(Sorted == ["s3", "s4"]).

test(no_unreachable_in_linear, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(\+ fsm_unreachable_state("m", _)).

:- end_tests(fsm_structural).

%% ── Runtime status ───────────────────────────────────────────────────────────

:- begin_tests(fsm_runtime).

test(complete_when_at_terminal, [setup(setup_linear_complete), cleanup(clear_facts)]) :-
    assertion(fsm_complete("m")).

test(not_complete_mid_run, [setup(setup_linear_running), cleanup(clear_facts)]) :-
    assertion(\+ fsm_complete("m")).

test(stuck_at_dead_end, [setup(setup_defective_stuck), cleanup(clear_facts)]) :-
    assertion(fsm_stuck("bad")),
    fsm_stuck_at("bad", S),
    assertion(S == "s3").

test(not_stuck_at_terminal, [setup(setup_linear_complete), cleanup(clear_facts)]) :-
    assertion(\+ fsm_stuck("m")).

test(visited_state, [setup(setup_linear_visited), cleanup(clear_facts)]) :-
    assertion(fsm_visited("m", "idle")),
    assertion(\+ fsm_visited("m", "running")).

:- end_tests(fsm_runtime).

%% ── Trace analysis ───────────────────────────────────────────────────────────

:- begin_tests(fsm_trace).

test(trace_step_recorded, [setup(setup_trace), cleanup(clear_facts)]) :-
    assertion(fsm_trace("m", "idle", "start_lap", "running")),
    assertion(fsm_trace("m", "running", "stop_lap", "complete")).

test(trace_length, [setup(setup_trace), cleanup(clear_facts)]) :-
    fsm_trace_length("m", N),
    assertion(N == 2).

:- end_tests(fsm_trace).

%% ── Cycle detection and path finding ─────────────────────────────────────────

:- begin_tests(fsm_paths).

test(cycle_detected, [setup(setup_cyclic), cleanup(clear_facts)]) :-
    assertion(fsm_cycle("cyc", "a")),
    assertion(fsm_cycle("cyc", "b")).

test(no_cycle_in_linear, [setup(setup_linear), cleanup(clear_facts)]) :-
    assertion(\+ fsm_cycle("m", _)).

test(shortest_path, [setup(setup_linear), cleanup(clear_facts)]) :-
    fsm_shortest_path("m", "idle", "complete", Path),
    assertion(Path == ["idle", "running", "complete"]).

test(all_paths_branching, [setup(setup_branching), cleanup(clear_facts)]) :-
    fsm_all_paths("wf", "draft", "approved", Paths),
    assertion(Paths == [["draft", "review", "approved"]]).

test(multiple_paths_to_terminals, [setup(setup_branching), cleanup(clear_facts)]) :-
    findall(P, (member(T, ["approved","rejected"]),
                fsm_shortest_path("wf", "draft", T, P)), Paths),
    assertion(length(Paths, 2)).

:- end_tests(fsm_paths).

%% ── Machine inventory ─────────────────────────────────────────────────────────

:- begin_tests(fsm_inventory).

test(machines_list, [setup(setup_two_machines), cleanup(clear_facts)]) :-
    fsm_machines(Ms),
    sort(Ms, Sorted),
    assertion(Sorted == ["m", "m2"]).

:- end_tests(fsm_inventory).

%% ── Validation ───────────────────────────────────────────────────────────────

:- begin_tests(fsm_validate).

test(clean_machine_no_issues, [setup(setup_linear), cleanup(clear_facts)]) :-
    fsm_validate("m", Issues),
    assertion(Issues == []).

test(validate_finds_dead_state, [setup(setup_defective), cleanup(clear_facts)]) :-
    fsm_validate("bad", Issues),
    assertion(member(dead_state("s3"), Issues)).

test(validate_finds_unreachable, [setup(setup_defective), cleanup(clear_facts)]) :-
    fsm_validate("bad", Issues),
    assertion(member(unreachable_state("s4"), Issues)).

test(validate_no_initial_state, [setup(setup_no_initial), cleanup(clear_facts)]) :-
    fsm_validate("x", Issues),
    assertion(member(no_initial_state, Issues)).

test(validate_no_terminal_state, [setup(setup_no_terminal), cleanup(clear_facts)]) :-
    fsm_validate("x", Issues),
    assertion(member(no_terminal_state, Issues)).

test(validate_nondeterministic, [setup(setup_nondeterministic), cleanup(clear_facts)]) :-
    fsm_validate("nd", Issues),
    assertion(member(nondeterministic("s1", _), Issues)).

:- end_tests(fsm_validate).
