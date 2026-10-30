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

%% ── spawn_zone is enforced (v1.0.1) ──────────────────────────────────────────

setup_ai_fix_zoned_goblin :-
    assertz(attribute(goblin, spawn_zone, forest_zone)),
    assertz(attribute(goblin, min_threat, 10)),
    assertz(attribute(forest_zone, threat, 40)),
    assertz(attribute(cave_zone, threat, 40)).

setup_ai_fix_free_roamer :-
    assertz(attribute(rat, min_threat, 0)),
    assertz(attribute(cave_zone, threat, 40)).

:- begin_tests(ai_director_spawn_zone).

test(zoned_enemy_spawns_in_its_zone, [setup(setup_ai_fix_zoned_goblin), cleanup(clear_facts)]) :-
    assertion(spawn_eligible(goblin, forest_zone)).

test(zoned_enemy_does_not_spawn_elsewhere, [setup(setup_ai_fix_zoned_goblin), cleanup(clear_facts)]) :-
    %% same threat, wrong zone — the clause used to succeed either way
    assertion(\+ spawn_eligible(goblin, cave_zone)).

test(unzoned_enemy_spawns_anywhere, [setup(setup_ai_fix_free_roamer), cleanup(clear_facts)]) :-
    assertion(spawn_eligible(rat, cave_zone)).

:- end_tests(ai_director_spawn_zone).

%% ── Unbound Enemy / Zone: spawn_eligible and the zone listers enumerate ──────

setup_ai_unbound :-
    assertz(attribute(forest_zone, threat, 40)),
    assertz(attribute(cave_zone, threat, 90)),
    assertz(attribute(camp_zone, threat, 3)),
    assertz(attribute(goblin, spawn_zone, forest_zone)),
    assertz(attribute(goblin, spawn_zone, cave_zone)),
    assertz(attribute(goblin, max_threat, 60)),
    assertz(attribute(dragon, min_threat, 70)),
    assertz(attribute(rat, max_threat, 100)),
    assertz(attribute(director, peak_event, boss_spawn)).

:- begin_tests(ai_director_unbound).

test(threat_level_lists_every_zone, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    findall(Z-L, threat_level(Z, L), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [camp_zone-3, cave_zone-90, forest_zone-40]).

test(threat_level_bound_level_is_the_zone_threat, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    %% 0 is only the default for a zone with no threat fact
    assertion(\+ threat_level(forest_zone, 0)).

test(pacing_state_lists_every_zone, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    findall(Z-S, pacing_state(Z, S), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [camp_zone-recovery, cave_zone-peak, forest_zone-building]).

test(pacing_state_bound_state_is_the_computed_one, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    %% calm is the fall-through, not an answer for every zone
    assertion(\+ pacing_state(cave_zone, calm)),
    findall(Z, pacing_state(Z, peak), Peak),
    assertion(Peak == [cave_zone]).

test(director_event_lists_zones, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    findall(Z-E, director_event(Z, E), Pairs),
    assertion(Pairs == [cave_zone-boss_spawn]).

test(spawn_eligible_lists_zones_for_enemy, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    findall(Z, spawn_eligible(goblin, Z), Zones),
    assertion(Zones == [forest_zone]),
    findall(Z, spawn_eligible(rat, Z), RatZones0),
    msort(RatZones0, RatZones),
    assertion(RatZones == [cave_zone, forest_zone]).

test(spawn_eligible_lists_enemies_for_zone, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    findall(E, spawn_eligible(E, cave_zone), Enemies0),
    msort(Enemies0, Enemies),
    assertion(Enemies == [dragon, rat]).

test(spawn_eligible_lists_pairs, [setup(setup_ai_unbound), cleanup(clear_facts)]) :-
    findall(E-Z, spawn_eligible(E, Z), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [dragon-cave_zone, goblin-forest_zone,
                        rat-cave_zone, rat-forest_zone]).

:- end_tests(ai_director_unbound).
