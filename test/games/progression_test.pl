:- use_module(library(plunit)).

:- consult('../../modules/games/progression/progression').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

%% Default linear curve: level 2 = 100xp, level 3 = 250xp, level 4 = 450xp, ...

setup_custom_curve :-
    assertz(attribute(xp_curve, type, custom)),
    assertz(attribute(level_2, xp_required, 100)),
    assertz(attribute(level_3, xp_required, 300)),
    assertz(attribute(level_4, xp_required, 700)).

setup_exponential_curve :-
    assertz(attribute(xp_curve, type, exponential)),
    assertz(attribute(xp_curve, base_xp, 100)),
    assertz(attribute(xp_curve, multiplier, 2)).

setup_linear_override :-
    assertz(attribute(xp_curve, base_xp, 200)),
    assertz(attribute(xp_curve, increment, 100)).

setup_max_level_5 :-
    assertz(attribute(xp_curve, max_level, 5)).

setup_alice_xp(XP) :-
    assertz(attribute(alice, xp, XP)).

setup_alice_level(Level) :-
    assertz(attribute(alice, level, Level)).

setup_hp_linear :-
    assertz(attribute(hp, base_value, 100)),
    assertz(attribute(hp, per_level, 10)).

setup_hp_exponential :-
    assertz(attribute(hp, scale, exponential)),
    assertz(attribute(hp, base_value, 100)),
    assertz(attribute(hp, multiplier, 2)).

setup_hp_with_override :-
    setup_hp_linear,
    assertz(attribute(hp, level_5, 200)).

setup_fireball_unlock :-
    assertz(attribute(fireball, unlock_at_level, 10)).

setup_fireball_mage_only :-
    setup_fireball_unlock,
    assertz(attribute(fireball, unlock_requires_class, mage)).

setup_alice_mage_level10 :-
    setup_alice_level(10),
    assertz(attribute(alice, class, mage)).

setup_alice_warrior_level10 :-
    setup_alice_level(10),
    assertz(attribute(alice, class, warrior)).

setup_prestige_max_level5 :-
    setup_max_level_5,
    assertz(attribute(prestige, requires_max_level, true)).

setup_prestige_level50 :-
    assertz(attribute(prestige, requires_level, 50)).

setup_prestige_with_quest :-
    assertz(attribute(prestige, requires_max_level, true)),
    assertz(attribute(xp_curve, max_level, 5)),
    assertz(attribute(prestige, requires_quest, slay_dragon)).

setup_alice_prestige_ready :-
    setup_prestige_max_level5,
    setup_alice_level(5).

setup_alice_prestige_with_quest :-
    setup_prestige_with_quest,
    setup_alice_level(5),
    assertz(relation(alice, completed_quest, slay_dragon)).

%% ── level_for_xp — default linear curve ──────────────────────────────────────
%% Default: base_xp=100, increment=50
%% Thresholds: level 1=0, level 2=100, level 3=250, level 4=450

:- begin_tests(progression_level_for_xp_linear).

test(xp_0_is_level_1, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(0, L), assertion(L == 1).

test(xp_99_is_level_1, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(99, L), assertion(L == 1).

test(xp_100_is_level_2, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(100, L), assertion(L == 2).

test(xp_249_is_level_2, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(249, L), assertion(L == 2).

test(xp_250_is_level_3, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(250, L), assertion(L == 3).

test(xp_449_is_level_3, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(449, L), assertion(L == 3).

test(xp_450_is_level_4, [setup(true), cleanup(clear_facts)]) :-
    level_for_xp(450, L), assertion(L == 4).

test(linear_override_base_and_increment, [setup(setup_linear_override),
                                           cleanup(clear_facts)]) :-
    %% base=200, increment=100: level 2=200, level 3=500
    level_for_xp(200, L2), assertion(L2 == 2),
    level_for_xp(499, L2b), assertion(L2b == 2),
    level_for_xp(500, L3), assertion(L3 == 3).

:- end_tests(progression_level_for_xp_linear).

%% ── level_for_xp — custom breakpoints ────────────────────────────────────────
%% level_2=100, level_3=300, level_4=700

:- begin_tests(progression_level_for_xp_custom).

test(custom_xp_99_level_1, [setup(setup_custom_curve), cleanup(clear_facts)]) :-
    level_for_xp(99, L), assertion(L == 1).

test(custom_xp_100_level_2, [setup(setup_custom_curve), cleanup(clear_facts)]) :-
    level_for_xp(100, L), assertion(L == 2).

test(custom_xp_299_level_2, [setup(setup_custom_curve), cleanup(clear_facts)]) :-
    level_for_xp(299, L), assertion(L == 2).

test(custom_xp_300_level_3, [setup(setup_custom_curve), cleanup(clear_facts)]) :-
    level_for_xp(300, L), assertion(L == 3).

test(custom_xp_700_level_4, [setup(setup_custom_curve), cleanup(clear_facts)]) :-
    level_for_xp(700, L), assertion(L == 4).

:- end_tests(progression_level_for_xp_custom).

%% ── level_for_xp — exponential curve ─────────────────────────────────────────
%% base=100, multiplier=2: level 2=100, level 3=300, level 4=700

:- begin_tests(progression_level_for_xp_exponential).

test(exp_xp_0_level_1, [setup(setup_exponential_curve), cleanup(clear_facts)]) :-
    level_for_xp(0, L), assertion(L == 1).

test(exp_xp_100_level_2, [setup(setup_exponential_curve), cleanup(clear_facts)]) :-
    level_for_xp(100, L), assertion(L == 2).

test(exp_xp_299_level_2, [setup(setup_exponential_curve), cleanup(clear_facts)]) :-
    level_for_xp(299, L), assertion(L == 2).

test(exp_xp_300_level_3, [setup(setup_exponential_curve), cleanup(clear_facts)]) :-
    level_for_xp(300, L), assertion(L == 3).

:- end_tests(progression_level_for_xp_exponential).

%% ── level_for_xp — max level cap ─────────────────────────────────────────────

:- begin_tests(progression_max_level).

test(xp_beyond_max_capped, [setup(setup_max_level_5), cleanup(clear_facts)]) :-
    level_for_xp(999999, L), assertion(L == 5).

test(xp_to_next_fails_at_max, [setup((setup_max_level_5, setup_alice_level(5))),
                                 cleanup(clear_facts)]) :-
    assertion(\+ xp_to_next_level(alice, _)).

:- end_tests(progression_max_level).

%% ── xp_to_next_level ─────────────────────────────────────────────────────────

:- begin_tests(progression_xp_to_next).

test(xp_to_next_from_xp_value, [setup(setup_alice_xp(50)), cleanup(clear_facts)]) :-
    %% alice at 50 XP = level 1; level 2 threshold = 100; needs 50 more
    xp_to_next_level(alice, N), assertion(N == 50).

test(xp_to_next_partway_through_level, [setup(setup_alice_xp(175)), cleanup(clear_facts)]) :-
    %% alice at 175 XP = level 2; level 3 threshold = 250; needs 75 more
    xp_to_next_level(alice, N), assertion(N == 75).

test(xp_to_next_from_explicit_level, [setup(setup_alice_level(1)), cleanup(clear_facts)]) :-
    %% alice at level 1 (no XP asserted); step cost to level 2 = 100
    xp_to_next_level(alice, N), assertion(N == 100).

test(xp_to_next_level2_step_cost, [setup(setup_alice_level(2)), cleanup(clear_facts)]) :-
    %% alice at level 2; step cost to level 3 = 150
    xp_to_next_level(alice, N), assertion(N == 150).

:- end_tests(progression_xp_to_next).

%% ── stat_at_level — linear ────────────────────────────────────────────────────

:- begin_tests(progression_stat_linear).

test(stat_level1_base_value, [setup(setup_hp_linear), cleanup(clear_facts)]) :-
    stat_at_level(hp, 1, V), assertion(V == 100).

test(stat_level5_linear, [setup(setup_hp_linear), cleanup(clear_facts)]) :-
    %% 100 + (5-1)*10 = 140
    stat_at_level(hp, 5, V), assertion(V == 140).

test(stat_level10_linear, [setup(setup_hp_linear), cleanup(clear_facts)]) :-
    %% 100 + 9*10 = 190
    stat_at_level(hp, 10, V), assertion(V == 190).

test(stat_default_zero_when_unconfigured, [setup(true), cleanup(clear_facts)]) :-
    stat_at_level(mp, 5, V), assertion(V == 0).

:- end_tests(progression_stat_linear).

%% ── stat_at_level — exponential ───────────────────────────────────────────────

:- begin_tests(progression_stat_exponential).

test(stat_exp_level1, [setup(setup_hp_exponential), cleanup(clear_facts)]) :-
    stat_at_level(hp, 1, V), assertion(V == 100).

test(stat_exp_level2, [setup(setup_hp_exponential), cleanup(clear_facts)]) :-
    %% round(100 * 2^1) = 200
    stat_at_level(hp, 2, V), assertion(V == 200).

test(stat_exp_level3, [setup(setup_hp_exponential), cleanup(clear_facts)]) :-
    %% round(100 * 2^2) = 400
    stat_at_level(hp, 3, V), assertion(V == 400).

:- end_tests(progression_stat_exponential).

%% ── stat_at_level — per-level override ───────────────────────────────────────

:- begin_tests(progression_stat_override).

test(stat_normal_level, [setup(setup_hp_with_override), cleanup(clear_facts)]) :-
    %% level 4: linear = 100 + 3*10 = 130
    stat_at_level(hp, 4, V), assertion(V == 130).

test(stat_override_at_level5, [setup(setup_hp_with_override), cleanup(clear_facts)]) :-
    %% override wins: 200 instead of 140
    stat_at_level(hp, 5, V), assertion(V == 200).

test(stat_normal_above_override, [setup(setup_hp_with_override), cleanup(clear_facts)]) :-
    %% level 6: no override, linear = 100 + 5*10 = 150
    stat_at_level(hp, 6, V), assertion(V == 150).

:- end_tests(progression_stat_override).

%% ── unlock_available ─────────────────────────────────────────────────────────

:- begin_tests(progression_unlocks).

test(unlock_at_exact_level, [
        setup((setup_fireball_unlock, setup_alice_level(10))),
        cleanup(clear_facts)]) :-
    assertion(unlock_available(alice, fireball)).

test(unlock_above_required_level, [
        setup((setup_fireball_unlock, setup_alice_level(15))),
        cleanup(clear_facts)]) :-
    assertion(unlock_available(alice, fireball)).

test(no_unlock_below_level, [
        setup((setup_fireball_unlock, setup_alice_level(9))),
        cleanup(clear_facts)]) :-
    assertion(\+ unlock_available(alice, fireball)).

test(unlock_class_gate_met, [
        setup((setup_fireball_mage_only, setup_alice_mage_level10)),
        cleanup(clear_facts)]) :-
    assertion(unlock_available(alice, fireball)).

test(unlock_class_gate_unmet, [
        setup((setup_fireball_mage_only, setup_alice_warrior_level10)),
        cleanup(clear_facts)]) :-
    assertion(\+ unlock_available(alice, fireball)).

test(unlock_derived_from_xp, [
        setup((setup_fireball_unlock, setup_alice_xp(250))),
        cleanup(clear_facts)]) :-
    %% 250 XP = level 3, but fireball requires level 10
    assertion(\+ unlock_available(alice, fireball)).

:- end_tests(progression_unlocks).

%% ── can_prestige ─────────────────────────────────────────────────────────────

:- begin_tests(progression_prestige).

test(prestige_at_max_level, [setup(setup_alice_prestige_ready), cleanup(clear_facts)]) :-
    assertion(can_prestige(alice)).

test(no_prestige_below_max, [
        setup((setup_prestige_max_level5, setup_alice_level(4))),
        cleanup(clear_facts)]) :-
    assertion(\+ can_prestige(alice)).

test(prestige_specific_level_met, [
        setup((setup_prestige_level50, setup_alice_level(50))),
        cleanup(clear_facts)]) :-
    assertion(can_prestige(alice)).

test(prestige_specific_level_above, [
        setup((setup_prestige_level50, setup_alice_level(75))),
        cleanup(clear_facts)]) :-
    assertion(can_prestige(alice)).

test(no_prestige_specific_level_unmet, [
        setup((setup_prestige_level50, setup_alice_level(49))),
        cleanup(clear_facts)]) :-
    assertion(\+ can_prestige(alice)).

test(no_prestige_unconfigured, [
        setup(setup_alice_level(100)),
        cleanup(clear_facts)]) :-
    assertion(\+ can_prestige(alice)).

test(prestige_with_quest_met, [setup(setup_alice_prestige_with_quest),
                                 cleanup(clear_facts)]) :-
    assertion(can_prestige(alice)).

test(no_prestige_missing_quest, [
        setup((setup_prestige_with_quest, setup_alice_level(5))),
        %% alice at max level but no completed_quest asserted
        cleanup(clear_facts)]) :-
    assertion(\+ can_prestige(alice)).

:- end_tests(progression_prestige).
