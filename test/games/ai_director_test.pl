:- use_module(library(plunit)).

:- consult('../../modules/games/ai_director/ai_director').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_zone_threat_90 :-
    assertz(attribute(forest_zone, threat, 90)).

setup_zone_threat_60 :-
    assertz(attribute(forest_zone, threat, 60)).

setup_zone_threat_30 :-
    assertz(attribute(forest_zone, threat, 30)).

setup_zone_threat_3 :-
    assertz(attribute(forest_zone, threat, 3)).

setup_zone_threat_7 :-
    assertz(attribute(forest_zone, threat, 7)).

setup_zone_threat_0 :-
    assertz(attribute(forest_zone, threat, 0)).

setup_goblin_rules :-
    assertz(attribute(goblin, spawn_zone, forest_zone)),
    assertz(attribute(goblin, min_threat, 10)),
    assertz(attribute(goblin, max_threat, 60)).

setup_dragon_rules :-
    assertz(attribute(dragon, min_threat, 70)).

setup_boss_event :-
    assertz(attribute(director, peak_event, boss_spawn)).

setup_recovery_event :-
    assertz(attribute(director, recovery_event, treasure_chest)).

setup_goblin_threat_40 :-
    setup_goblin_rules,
    assertz(attribute(forest_zone, threat, 40)).

setup_goblin_threat_10 :-
    setup_goblin_rules,
    assertz(attribute(forest_zone, threat, 10)).

setup_goblin_threat_80 :-
    setup_goblin_rules,
    assertz(attribute(forest_zone, threat, 80)).

setup_goblin_recovery :-
    setup_goblin_rules,
    assertz(attribute(forest_zone, threat, 3)).

%% ── threat_level/2 ───────────────────────────────────────────────────────────

:- begin_tests(ai_director_threat).

test(threat_from_attribute, [setup(setup_zone_threat_60), cleanup(clear_facts)]) :-
    threat_level(forest_zone, L), assertion(L == 60).

test(threat_defaults_zero, [cleanup(clear_facts)]) :-
    threat_level(unknown_zone, L), assertion(L == 0).

:- end_tests(ai_director_threat).

%% ── pacing_state/2 ───────────────────────────────────────────────────────────

:- begin_tests(ai_director_pacing).

test(peak_at_90, [setup(setup_zone_threat_90), cleanup(clear_facts)]) :-
    pacing_state(forest_zone, S), assertion(S == peak).

test(tense_at_60, [setup(setup_zone_threat_60), cleanup(clear_facts)]) :-
    pacing_state(forest_zone, S), assertion(S == tense).

test(building_at_30, [setup(setup_zone_threat_30), cleanup(clear_facts)]) :-
    pacing_state(forest_zone, S), assertion(S == building).

test(recovery_at_3, [setup(setup_zone_threat_3), cleanup(clear_facts)]) :-
    pacing_state(forest_zone, S), assertion(S == recovery).

test(calm_at_7, [setup(setup_zone_threat_7), cleanup(clear_facts)]) :-
    pacing_state(forest_zone, S), assertion(S == calm).

test(recovery_at_zero, [setup(setup_zone_threat_0), cleanup(clear_facts)]) :-
    pacing_state(forest_zone, S), assertion(S == recovery).

:- end_tests(ai_director_pacing).

%% ── difficulty_modifier/2 ────────────────────────────────────────────────────

:- begin_tests(ai_director_difficulty).

test(peak_modifier, [setup(setup_zone_threat_90), cleanup(clear_facts)]) :-
    difficulty_modifier(forest_zone, M), assertion(M == 1.6).

test(tense_modifier, [setup(setup_zone_threat_60), cleanup(clear_facts)]) :-
    difficulty_modifier(forest_zone, M), assertion(M == 1.3).

test(calm_modifier, [setup(setup_zone_threat_7), cleanup(clear_facts)]) :-
    difficulty_modifier(forest_zone, M), assertion(M == 0.7).

test(recovery_modifier, [setup(setup_zone_threat_3), cleanup(clear_facts)]) :-
    difficulty_modifier(forest_zone, M), assertion(M == 0.5).

:- end_tests(ai_director_difficulty).

%% ── spawn_eligible/2 ─────────────────────────────────────────────────────────

:- begin_tests(ai_director_spawn).

test(goblin_eligible_at_40, [setup(setup_goblin_threat_40), cleanup(clear_facts)]) :-
    assertion(spawn_eligible(goblin, forest_zone)).

test(goblin_eligible_at_min_threat, [setup(setup_goblin_threat_10), cleanup(clear_facts)]) :-
    assertion(spawn_eligible(goblin, forest_zone)).

test(goblin_blocked_above_max_threat, [setup(setup_goblin_threat_80), cleanup(clear_facts)]) :-
    assertion(\+ spawn_eligible(goblin, forest_zone)).

test(goblin_blocked_in_recovery, [setup(setup_goblin_recovery), cleanup(clear_facts)]) :-
    assertion(\+ spawn_eligible(goblin, forest_zone)).

test(dragon_eligible_at_high_threat, [setup((setup_dragon_rules, setup_zone_threat_90)), cleanup(clear_facts)]) :-
    assertion(spawn_eligible(dragon, forest_zone)).

test(dragon_blocked_at_low_threat, [setup((setup_dragon_rules, setup_zone_threat_30)), cleanup(clear_facts)]) :-
    assertion(\+ spawn_eligible(dragon, forest_zone)).

:- end_tests(ai_director_spawn).

%% ── director_event/2 ─────────────────────────────────────────────────────────

:- begin_tests(ai_director_events).

test(peak_triggers_boss, [setup((setup_zone_threat_90, setup_boss_event)), cleanup(clear_facts)]) :-
    director_event(forest_zone, E), assertion(E == boss_spawn).

test(recovery_triggers_chest, [setup((setup_zone_threat_3, setup_recovery_event)), cleanup(clear_facts)]) :-
    director_event(forest_zone, E), assertion(E == treasure_chest).

test(no_event_when_none_set, [setup(setup_zone_threat_60), cleanup(clear_facts)]) :-
    assertion(\+ director_event(forest_zone, _)).

:- end_tests(ai_director_events).
