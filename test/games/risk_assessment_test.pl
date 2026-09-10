:- use_module(library(plunit)).

%% Loaded on its own, without combat: the battery declares no dependency and
%% these tests are what hold it to that.
:- consult('../../modules/games/risk-assessment/risk_assessment').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_player :-
    assertz(attribute(player, hp, 80)),
    assertz(attribute(player, base_damage, 15)).

setup_goblin :-
    assertz(attribute(goblin, hp, 30)),
    assertz(attribute(goblin, base_damage, 10)).

setup_boss :-
    assertz(attribute(warden_boss, hp, 200)),
    assertz(attribute(warden_boss, base_damage, 45)).

setup_player_vs_goblin :-
    setup_player, setup_goblin.

setup_player_vs_boss :-
    setup_player, setup_boss.

setup_harmless_enemy :-
    setup_player,
    assertz(attribute(dummy, hp, 10)),
    assertz(attribute(dummy, base_damage, 0)).

%% ── survival_probability/4 ───────────────────────────────────────────────────

:- begin_tests(risk_survival).

test(easy_fight, [nondet, setup(setup_player_vs_goblin), cleanup(clear_facts)]) :-
    %% 2 turns to kill, 20 damage taken: 1 − (20/80) × 0.5 = 0.875, 60 hp left
    survival_probability(player, goblin, HP, P),
    assertion(HP == 60),
    assertion(abs(P - 0.875) < 0.0001).

test(lethal_fight_floors_at_0_05, [nondet, setup(setup_player_vs_boss), cleanup(clear_facts)]) :-
    %% 14 turns, 630 damage: far past 80 hp, so the floor
    survival_probability(player, warden_boss, HP, P),
    assertion(HP == 0),
    assertion(P =:= 0.05).

test(no_hp_fact_means_no_answer, [nondet, setup(setup_goblin), cleanup(clear_facts)]) :-
    assertion(\+ survival_probability(player, goblin, _, _)).

:- end_tests(risk_survival).

%% ── recommended_action/3 ─────────────────────────────────────────────────────

:- begin_tests(risk_recommendation).

test(fight_when_odds_good, [nondet, setup(setup_player_vs_goblin), cleanup(clear_facts)]) :-
    recommended_action(player, goblin, A), assertion(A == fight).

test(flee_when_odds_bad, [nondet, setup(setup_player_vs_boss), cleanup(clear_facts)]) :-
    recommended_action(player, warden_boss, A), assertion(A == flee).

:- end_tests(risk_recommendation).

%% ── kills_to_exhaust/4 ───────────────────────────────────────────────────────

:- begin_tests(risk_kills).

test(kills_from_full_health, [nondet, setup(setup_player_vs_goblin), cleanup(clear_facts)]) :-
    %% 20 damage per goblin: floor(80 / 20) = 4
    kills_to_exhaust(player, goblin, 80, N), assertion(N == 4).

test(kills_uses_passed_hp_not_fact, [nondet, setup(setup_player_vs_goblin), cleanup(clear_facts)]) :-
    kills_to_exhaust(player, goblin, 45, N), assertion(N == 2).

test(at_least_one_kill, [nondet, setup(setup_player_vs_boss), cleanup(clear_facts)]) :-
    kills_to_exhaust(player, warden_boss, 80, N), assertion(N == 1).

:- end_tests(risk_kills).

%% ── fight_outcome_summary/5 ──────────────────────────────────────────────────

:- begin_tests(risk_summary).

test(summary_breakdown, [nondet, setup(setup_player_vs_boss), cleanup(clear_facts)]) :-
    fight_outcome_summary(player, warden_boss, Turns, Damage, P),
    assertion(Turns == 14),
    assertion(Damage == 630),
    assertion(P =:= 0.05).

test(zero_damage_enemy_still_computes_summary, [nondet, setup(setup_harmless_enemy), cleanup(clear_facts)]) :-
    %% the enemy's damage may be 0; only the player's must be > 0
    fight_outcome_summary(player, dummy, Turns, Damage, P),
    assertion(Turns == 1),
    assertion(Damage == 0),
    assertion(P =:= 0.99).

test(zero_player_damage_fails, [nondet, setup((setup_goblin, assertz(attribute(pacifist, hp, 50)), assertz(attribute(pacifist, base_damage, 0)))), cleanup(clear_facts)]) :-
    assertion(\+ fight_outcome_summary(pacifist, goblin, _, _, _)).

:- end_tests(risk_summary).
