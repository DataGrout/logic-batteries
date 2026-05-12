:- use_module(library(plunit)).

:- consult('../../modules/games/combat/combat').
:- consult('../../modules/probabilistic/prob-detection/prob_detection').

%% (clear_facts/0 is in test/support/test_helpers.pl)
%%
%% NOTE: Annotated detected/2 rules fire probabilistically in the LC runtime.
%% Standalone tests cover: detection_probability/3 (numeric accessor),
%% environmental_detection_factor/2, stealth_factor/2, and stealth_success/2.

setup_active_high_perception_guard :-
    assertz(attribute(guard_elite, perception, 9)),
    assertz(attribute(guard_elite, alert_state, active)).

setup_passive_low_perception_guard :-
    assertz(attribute(guard_rookie, perception, 3)).

setup_stealth_player :-
    assertz(attribute(thief, stealth_bonus, 7)).

setup_dark_world :-
    assertz(attribute(world, light_level, dark)).

setup_loud_world :-
    assertz(attribute(world, noise_level, loud)).

setup_rain_fog_world :-
    assertz(attribute(world, weather, rain)),
    assertz(attribute(world, weather, fog)).

setup_no_perc_active :-
    assertz(attribute(no_perc_guard, alert_state, active)).

setup_max_stealth :-
    assertz(attribute(ghost, stealth_bonus, 20)).

setup_blind_guard :-
    assertz(attribute(blind_guard, perception, 1)).

%% ── base_detection_probability/3 ─────────────────────────────────────────────

:- begin_tests(prob_detection_base).

test(active_high_perception, [nondet, setup(setup_active_high_perception_guard), cleanup(clear_facts)]) :-
    base_detection_probability(guard_elite, player, Base),
    %% perception 9, active: min(0.95, 9/10 * 1.3) = min(0.95, 1.17) = 0.95
    assertion(Base =:= 0.95).

test(passive_low_perception, [nondet, setup(setup_passive_low_perception_guard), cleanup(clear_facts)]) :-
    base_detection_probability(guard_rookie, player, Base),
    %% perception 3, no alert: 3/10 * 1.0 = 0.3
    assertion(Base =:= 0.3).

test(no_perception_passive_default, [nondet, cleanup(clear_facts)]) :-
    %% guard with no perception attribute and no active state
    base_detection_probability(unknown_guard, player, Base),
    assertion(Base =:= 0.3).

test(no_perception_active_default, [setup(setup_no_perc_active), cleanup(clear_facts)]) :-
    base_detection_probability(no_perc_guard, player, Base),
    assertion(Base =:= 0.5).

:- end_tests(prob_detection_base).

%% ── environmental_detection_factor/2 ─────────────────────────────────────────

:- begin_tests(prob_detection_environment).

test(no_environment_factor_one, [cleanup(clear_facts)]) :-
    environmental_detection_factor(world, F),
    assertion(F =:= 1.0).

test(dark_halves_detection, [setup(setup_dark_world), cleanup(clear_facts)]) :-
    environmental_detection_factor(world, F),
    assertion(F =:= 0.5).

test(loud_noise_increases_detection, [setup(setup_loud_world), cleanup(clear_facts)]) :-
    environmental_detection_factor(world, F),
    assertion(F =:= 1.3).

test(rain_and_fog_compound, [setup(setup_rain_fog_world), cleanup(clear_facts)]) :-
    environmental_detection_factor(world, F),
    %% rain factor 0.8 * fog factor 0.85 = 0.68
    assertion(abs(F - 0.68) < 0.001).

:- end_tests(prob_detection_environment).

%% ── stealth_factor/2 ─────────────────────────────────────────────────────────

:- begin_tests(prob_detection_stealth).

test(no_stealth_bonus_is_one, [cleanup(clear_facts)]) :-
    stealth_factor(plain_player, F),
    assertion(F =:= 1.0).

test(stealth_bonus_reduces_factor, [nondet, setup(setup_stealth_player), cleanup(clear_facts)]) :-
    stealth_factor(thief, F),
    %% bonus 7: max(0.1, 1.0 - 7 * 0.07) = max(0.1, 0.51) = 0.51
    assertion(abs(F - 0.51) < 0.001).

test(stealth_factor_clamped_at_0_1, [nondet, setup(setup_max_stealth), cleanup(clear_facts)]) :-
    stealth_factor(ghost, F),
    assertion(F =:= 0.1).

:- end_tests(prob_detection_stealth).

%% ── detection_probability/3 ──────────────────────────────────────────────────

:- begin_tests(prob_detection_probability).

test(high_perception_active_without_stealth, [nondet, setup(setup_active_high_perception_guard), cleanup(clear_facts)]) :-
    detection_probability(guard_elite, player, P),
    %% base = 0.95, env = 1.0, stealth = 1.0 → min(0.99, max(0.01, 0.95))
    assertion(abs(P - 0.95) < 0.001).

test(dark_world_reduces_detection, [nondet, setup((
        setup_active_high_perception_guard,
        setup_dark_world
    )), cleanup(clear_facts)]) :-
    detection_probability(guard_elite, player, P),
    detection_probability(guard_elite, player, P),
    %% base 0.95 * dark 0.5 = 0.475
    assertion(abs(P - 0.475) < 0.001).

test(stealth_reduces_detection, [nondet, setup((
        setup_active_high_perception_guard,
        setup_stealth_player
    )), cleanup(clear_facts)]) :-
    detection_probability(guard_elite, thief, P),
    %% base 0.95 * stealth 0.51 ≈ 0.4845
    assertion(P < 0.95).

test(probability_clamped_to_0_01_min, [nondet, setup(setup_blind_guard), cleanup(clear_facts)]) :-
    detection_probability(blind_guard, player, P),
    assertion(P >= 0.01).

:- end_tests(prob_detection_probability).

%% ── stealth_success/2 ────────────────────────────────────────────────────────

:- begin_tests(prob_detection_stealth_success).

test(stealth_success_when_detection_low, [setup((
        setup_passive_low_perception_guard,
        setup_dark_world,
        setup_stealth_player
    )), cleanup(clear_facts)]) :-
    %% base 0.3 * dark 0.5 * stealth 0.51 ≈ 0.0765 → < 0.5, stealth succeeds
    assertion(stealth_success(guard_rookie, thief)).

test(no_stealth_success_against_elite_guard, [setup(setup_active_high_perception_guard), cleanup(clear_facts)]) :-
    assertion(\+ stealth_success(guard_elite, player)).

:- end_tests(prob_detection_stealth_success).
