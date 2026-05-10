:- use_module(library(plunit)).

:- consult('../../modules/games/puzzle-fsm/puzzle_fsm').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_simple_puzzle :-
    assertz(attribute(chest, initial_state, locked)),
    assertz(attribute(chest, solve_state, open)),
    assertz(relation(locked, move, use_key)),
    assertz(attribute(use_key, leads_to, open)).

setup_puzzle_at_open :-
    setup_simple_puzzle,
    assertz(attribute(chest, current_state, open)).

setup_puzzle_at_locked :-
    setup_simple_puzzle,
    assertz(attribute(chest, current_state, locked)).

setup_item_puzzle :-
    assertz(attribute(chest, initial_state, locked)),
    assertz(attribute(chest, solve_state, open)),
    assertz(relation(locked, move, use_key)),
    assertz(attribute(use_key, leads_to, open)),
    assertz(attribute(use_key, requires_item, brass_key)).

setup_item_puzzle_with_key :-
    setup_item_puzzle,
    assertz(relation(chest, player_has, brass_key)).

setup_two_step_puzzle :-
    assertz(attribute(gate, initial_state, sealed)),
    assertz(attribute(gate, solve_state, through)),
    assertz(relation(sealed, move, lift_bar)),
    assertz(attribute(lift_bar, leads_to, unlocked)),
    assertz(relation(unlocked, move, push_open)),
    assertz(attribute(push_open, leads_to, through)).

setup_multi_solve_puzzle :-
    assertz(attribute(door, initial_state, closed)),
    assertz(relation(door, solve_state, open_left)),
    assertz(relation(door, solve_state, open_right)),
    assertz(relation(closed, move, pull_left)),
    assertz(attribute(pull_left, leads_to, open_left)),
    assertz(relation(closed, move, pull_right)),
    assertz(attribute(pull_right, leads_to, open_right)).

setup_no_moves_puzzle :-
    assertz(attribute(vault, initial_state, sealed)),
    assertz(attribute(vault, solve_state, open)).

setup_missing_item_puzzle :-
    assertz(attribute(safe, initial_state, locked)),
    assertz(attribute(safe, solve_state, open)),
    assertz(relation(locked, move, dial_combo)),
    assertz(attribute(dial_combo, leads_to, open)),
    assertz(attribute(dial_combo, requires_item, combination_note)).

setup_missing_item_puzzle_with_note :-
    setup_missing_item_puzzle,
    assertz(relation(safe, player_has, combination_note)).

setup_multi_solve_puzzle_at_left :-
    setup_multi_solve_puzzle,
    assertz(attribute(door, current_state, open_left)).

setup_multi_solve_puzzle_at_right :-
    setup_multi_solve_puzzle,
    assertz(attribute(door, current_state, open_right)).

%% ── can_transition/3 ─────────────────────────────────────────────────────────

:- begin_tests(puzzle_can_transition).

test(valid_transition_from_initial, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    assertion(can_transition(chest, use_key, open)).

test(transition_binds_next_state, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    can_transition(chest, use_key, Next),
    assertion(Next == open).

test(invalid_move_fails, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ can_transition(chest, smash_lock, _)).

test(transition_uses_current_state, [setup(setup_puzzle_at_locked), cleanup(clear_facts)]) :-
    assertion(can_transition(chest, use_key, open)).

test(no_transition_when_at_terminal, [setup(setup_puzzle_at_open), cleanup(clear_facts)]) :-
    assertion(\+ can_transition(chest, _, _)).

test(item_required_without_item_fails, [setup(setup_item_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ can_transition(chest, use_key, _)).

test(item_required_with_item_succeeds, [setup(setup_item_puzzle_with_key), cleanup(clear_facts)]) :-
    assertion(can_transition(chest, use_key, open)).

test(two_step_first_move, [setup(setup_two_step_puzzle), cleanup(clear_facts)]) :-
    assertion(can_transition(gate, lift_bar, unlocked)).

:- end_tests(puzzle_can_transition).

%% ── puzzle_solved/1 ──────────────────────────────────────────────────────────

:- begin_tests(puzzle_solved).

test(not_solved_at_initial, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ puzzle_solved(chest)).

test(solved_when_current_matches_solve_state, [setup(setup_puzzle_at_open), cleanup(clear_facts)]) :-
    assertion(puzzle_solved(chest)).

test(solved_via_relation_solve_state, [
        setup(setup_multi_solve_puzzle_at_left),
        cleanup(clear_facts)]) :-
    assertion(puzzle_solved(door)).

test(other_solve_state_also_wins, [
        setup(setup_multi_solve_puzzle_at_right),
        cleanup(clear_facts)]) :-
    assertion(puzzle_solved(door)).

test(intermediate_state_not_solved, [setup(setup_two_step_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ puzzle_solved(gate)).

:- end_tests(puzzle_solved).

%% ── valid_sequence/2 ─────────────────────────────────────────────────────────

:- begin_tests(puzzle_valid_sequence).

test(single_move_solution, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    valid_sequence(chest, Moves),
    assertion(Moves == [use_key]).

test(two_move_solution, [setup(setup_two_step_puzzle), cleanup(clear_facts)]) :-
    valid_sequence(gate, Moves),
    assertion(Moves == [lift_bar, push_open]).

test(no_solution_when_no_moves, [setup(setup_no_moves_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ valid_sequence(vault, _)).

test(no_solution_when_item_missing, [setup(setup_missing_item_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ valid_sequence(safe, _)).

test(solution_with_item_present, [setup(setup_missing_item_puzzle_with_note), cleanup(clear_facts)]) :-
    valid_sequence(safe, Moves),
    assertion(Moves == [dial_combo]).

test(multi_solve_state_finds_a_path, [setup(setup_multi_solve_puzzle), cleanup(clear_facts)]) :-
    valid_sequence(door, Moves),
    assertion(Moves \= []).

test(multi_solve_state_path_is_length_one, [setup(setup_multi_solve_puzzle), cleanup(clear_facts)]) :-
    valid_sequence(door, Moves),
    assertion(length(Moves, 1)).

:- end_tests(puzzle_valid_sequence).

%% ── hint_for/2 ───────────────────────────────────────────────────────────────

:- begin_tests(puzzle_hint_for).

test(hint_returns_valid_move, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    hint_for(chest, Move),
    assertion(Move == use_key).

test(no_hint_when_solved, [setup(setup_puzzle_at_open), cleanup(clear_facts)]) :-
    assertion(\+ hint_for(chest, _)).

test(no_hint_when_item_missing, [setup(setup_item_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ hint_for(chest, _)).

test(hint_available_with_item, [setup(setup_item_puzzle_with_key), cleanup(clear_facts)]) :-
    assertion(hint_for(chest, use_key)).

test(no_hint_when_no_moves, [setup(setup_no_moves_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ hint_for(vault, _)).

test(two_step_hint_is_first_move, [setup(setup_two_step_puzzle), cleanup(clear_facts)]) :-
    hint_for(gate, Move),
    assertion(Move == lift_bar).

:- end_tests(puzzle_hint_for).

%% ── blocked_by/2 ─────────────────────────────────────────────────────────────

:- begin_tests(puzzle_blocked_by).

test(blocked_already_solved, [setup(setup_puzzle_at_open), cleanup(clear_facts)]) :-
    blocked_by(chest, Reason),
    assertion(Reason == already_solved).

test(blocked_missing_item, [setup(setup_item_puzzle), cleanup(clear_facts)]) :-
    blocked_by(chest, Reason),
    assertion(Reason == missing_item(brass_key)).

test(blocked_no_moves, [setup(setup_no_moves_puzzle), cleanup(clear_facts)]) :-
    blocked_by(vault, Reason),
    assertion(Reason == no_moves).

test(not_blocked_when_solvable, [setup(setup_simple_puzzle), cleanup(clear_facts)]) :-
    assertion(\+ blocked_by(chest, _)).

test(not_blocked_when_item_present, [setup(setup_item_puzzle_with_key), cleanup(clear_facts)]) :-
    assertion(\+ blocked_by(chest, _)).

test(missing_item_blocked_not_no_moves, [setup(setup_missing_item_puzzle), cleanup(clear_facts)]) :-
    blocked_by(safe, Reason),
    assertion(Reason == missing_item(combination_note)).

:- end_tests(puzzle_blocked_by).
