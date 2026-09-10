:- use_module(library(plunit)).

:- consult('../../modules/games/dungeon/dungeon').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_linear_dungeon :-
    assertz(relation(entrance, connects_to, corridor_a)),
    assertz(relation(corridor_a, connects_to, boss_room)),
    assertz(relation(catacombs, has_room, entrance)),
    assertz(relation(catacombs, has_room, corridor_a)),
    assertz(relation(catacombs, has_room, boss_room)).

setup_locked_boss_room :-
    setup_linear_dungeon,
    assertz(attribute(boss_room, requires_key, iron_key)).

setup_alice_has_key :-
    assertz(relation(alice, has_item, iron_key)).

setup_alice_cleared_all :-
    assertz(relation(alice_dungeon, cleared, entrance)),
    assertz(relation(alice_dungeon, cleared, corridor_a)),
    assertz(relation(alice_dungeon, cleared, boss_room)).

setup_alice_cleared_partial :-
    assertz(relation(alice_dungeon, cleared, entrance)),
    assertz(relation(alice_dungeon, cleared, corridor_a)).

setup_complete_check :-
    setup_linear_dungeon,
    setup_alice_cleared_all.

setup_incomplete_check :-
    setup_linear_dungeon,
    setup_alice_cleared_partial.

%% ── room_connected/2 ─────────────────────────────────────────────────────────

:- begin_tests(dungeon_connected).

test(rooms_connected, [setup(setup_linear_dungeon), cleanup(clear_facts)]) :-
    assertion(room_connected(entrance, corridor_a)).

test(rooms_not_connected_reverse, [setup(setup_linear_dungeon), cleanup(clear_facts)]) :-
    %% connections are directed — no reverse declared
    assertion(\+ room_connected(corridor_a, entrance)).

test(not_connected_unrelated, [setup(setup_linear_dungeon), cleanup(clear_facts)]) :-
    assertion(\+ room_connected(entrance, boss_room)).

:- end_tests(dungeon_connected).

%% ── room_accessible/2 ────────────────────────────────────────────────────────

:- begin_tests(dungeon_accessible).

test(unlocked_room_accessible, [setup(setup_linear_dungeon), cleanup(clear_facts)]) :-
    assertion(room_accessible(alice, entrance)).

test(locked_room_accessible_with_key, [setup((setup_locked_boss_room, setup_alice_has_key)), cleanup(clear_facts)]) :-
    assertion(room_accessible(alice, boss_room)).

test(locked_room_inaccessible_without_key, [setup(setup_locked_boss_room), cleanup(clear_facts)]) :-
    assertion(\+ room_accessible(alice, boss_room)).

:- end_tests(dungeon_accessible).

%% ── room_cleared/2 ───────────────────────────────────────────────────────────

:- begin_tests(dungeon_cleared).

test(room_cleared_via_key, [setup(setup_alice_cleared_all), cleanup(clear_facts)]) :-
    assertion(room_cleared(alice, entrance)).

test(room_not_cleared_when_unset, [setup(setup_alice_cleared_partial), cleanup(clear_facts)]) :-
    assertion(\+ room_cleared(alice, boss_room)).

:- end_tests(dungeon_cleared).

%% ── dungeon_complete/2 ───────────────────────────────────────────────────────

:- begin_tests(dungeon_complete).

test(complete_when_all_cleared, [setup(setup_complete_check), cleanup(clear_facts)]) :-
    assertion(dungeon_complete(alice, catacombs)).

test(incomplete_when_some_remain, [setup(setup_incomplete_check), cleanup(clear_facts)]) :-
    assertion(\+ dungeon_complete(alice, catacombs)).

:- end_tests(dungeon_complete).

%% ── maximal paths and per-dungeon clearance (v1.0.1) ─────────────────────────

setup_dun_fix_branching :-
    assertz(relation(e1, connects_to, c1)),
    assertz(relation(c1, connects_to, b1)),
    assertz(relation(c1, connects_to, side1)).

setup_dun_fix_shared_room_name :-
    assertz(relation(crypt, has_room, hall)),
    assertz(relation(tower, has_room, hall)),
    assertz(relation(alice_crypt, cleared, hall)).

setup_dun_fix_cleared_room_shape :-
    assertz(relation(crypt, has_room, hall)),
    assertz(relation(alice, cleared_room, hall)).

:- begin_tests(dungeon_paths_and_clearance).

test(paths_are_maximal_not_prefixes, [setup(setup_dun_fix_branching), cleanup(clear_facts)]) :-
    findall(P, dungeon_path(alice, e1, P), Ps),
    %% the trivial [e1] and the prefix [e1, c1] used to be solutions too
    assertion(\+ member([e1], Ps)),
    assertion(\+ member([e1, c1], Ps)),
    assertion(member([e1, c1, b1], Ps)),
    assertion(member([e1, c1, side1], Ps)).

test(clearance_is_per_dungeon, [setup(setup_dun_fix_shared_room_name), cleanup(clear_facts)]) :-
    assertion(room_cleared(alice, crypt, hall)),
    assertion(\+ room_cleared(alice, tower, hall)),
    assertion(dungeon_complete(alice, crypt)),
    assertion(\+ dungeon_complete(alice, tower)).

test(cleared_room_relation_completes_a_dungeon, [setup(setup_dun_fix_cleared_room_shape), cleanup(clear_facts)]) :-
    assertion(dungeon_complete(alice, crypt)).

:- end_tests(dungeon_paths_and_clearance).
