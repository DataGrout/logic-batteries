:- use_module(library(plunit)).

:- consult('../../modules/games/combat/combat').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_alice_attacks_goblin :-
    assertz(attribute(goblin, hp, 30)).

setup_fire_strong_against_ice :-
    assertz(relation(fire, strong_against, ice)).

setup_fire_weak_against_water :-
    assertz(relation(fire, weak_against, water)).

setup_alice_fire_attacker :-
    assertz(attribute(alice, damage_type, fire)).

setup_goblin_ice_element :-
    assertz(attribute(goblin, element, ice)).

setup_goblin_water_element :-
    assertz(attribute(goblin, element, water)).

setup_goblin_fire_resistant :-
    assertz(attribute(goblin, resist_fire, 0.5)).

setup_goblin_fire_weak :-
    assertz(attribute(goblin, weak_fire, 2.0)).

setup_goblin_fire_immune :-
    assertz(attribute(goblin, immune_fire, true)).

setup_goblin_armor15 :-
    assertz(attribute(goblin, armor, 15)).

setup_goblin_physical_armor :-
    assertz(attribute(goblin, armor, 15)),
    assertz(attribute(goblin, armor_type, physical)).

setup_alice_buff :-
    assertz(attribute(alice, buff_damage, 1.5)).

setup_alice_debuff :-
    assertz(attribute(alice, debuff_damage, 0.5)).

setup_alice_alive_goblin_alive :-
    assertz(attribute(alice, hp, 50)),
    assertz(attribute(goblin, hp, 30)).

setup_alice_defeated :-
    assertz(attribute(alice, hp, 0)),
    assertz(attribute(goblin, hp, 30)).

setup_goblin_defeated :-
    assertz(attribute(alice, hp, 50)),
    assertz(attribute(goblin, hp, 0)).

setup_alice_stunned :-
    setup_alice_alive_goblin_alive,
    assertz(attribute(alice, status, stunned)).

setup_alice_frozen :-
    setup_alice_alive_goblin_alive,
    assertz(attribute(alice, status, frozen)).

setup_alice_sleeping :-
    setup_alice_alive_goblin_alive,
    assertz(attribute(alice, status, sleeping)).

setup_alice_poisoned :-
    assertz(attribute(alice, status, poisoned)).

setup_alice_multi_status :-
    assertz(attribute(alice, status, poisoned)),
    assertz(attribute(alice, status, burning)).

setup_alice_out_of_range :-
    setup_alice_alive_goblin_alive,
    assertz(relation(alice, out_of_range, goblin)).

setup_turn_order_three :-
    assertz(attribute(alice,   speed, 12)),
    assertz(attribute(goblin,  speed, 8)),
    assertz(attribute(troll,   speed, 5)).

setup_turn_order_tie :-
    assertz(attribute(alice,  speed, 10)),
    assertz(attribute(goblin, speed, 10)).

setup_turn_order_one_no_speed :-
    assertz(attribute(alice, speed, 8)).

setup_goblin_zero_hp :-
    assertz(attribute(goblin, hp, 0)).

setup_goblin_negative_hp :-
    assertz(attribute(goblin, hp, -5)).

setup_goblin_positive_hp :-
    assertz(attribute(goblin, hp, 1)).

setup_alice_poisoned_alive :-
    setup_alice_alive_goblin_alive,
    assertz(attribute(alice, status, poisoned)).

setup_alice_speed5 :-
    assertz(attribute(alice, speed, 5)).

%% ── resistance/3 ─────────────────────────────────────────────────────────────

:- begin_tests(combat_resistance).

test(neutral_by_default, [setup(true), cleanup(clear_facts)]) :-
    resistance(goblin, fire, F), assertion(F == 1.0).

test(explicit_resist, [setup(setup_goblin_fire_resistant), cleanup(clear_facts)]) :-
    resistance(goblin, fire, F), assertion(F == 0.5).

test(explicit_weak, [setup(setup_goblin_fire_weak), cleanup(clear_facts)]) :-
    resistance(goblin, fire, F), assertion(F == 2.0).

test(immune_gives_zero, [setup(setup_goblin_fire_immune), cleanup(clear_facts)]) :-
    resistance(goblin, fire, F), assertion(F == 0).

test(type_chart_strong, [setup((setup_fire_strong_against_ice, setup_goblin_ice_element)),
                           cleanup(clear_facts)]) :-
    resistance(goblin, fire, F), assertion(F == 2.0).

test(type_chart_weak, [setup((setup_fire_weak_against_water, setup_goblin_water_element)),
                        cleanup(clear_facts)]) :-
    resistance(goblin, fire, F), assertion(F == 0.5).

test(explicit_resist_overrides_type_chart, [
        setup((setup_fire_strong_against_ice,
               setup_goblin_ice_element,
               setup_goblin_fire_resistant)),
        cleanup(clear_facts)]) :-
    %% explicit resist takes priority over type chart
    resistance(goblin, fire, F), assertion(F == 0.5).

:- end_tests(combat_resistance).

%% ── effective_damage/4 ───────────────────────────────────────────────────────

:- begin_tests(combat_damage).

test(base_damage_no_modifiers, [setup(true), cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 100, D), assertion(D == 100).

test(fire_vs_ice_doubles, [
        setup((setup_alice_fire_attacker,
               setup_fire_strong_against_ice,
               setup_goblin_ice_element)),
        cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 50, D), assertion(D == 100).

test(fire_vs_resistant_halves, [
        setup((setup_alice_fire_attacker, setup_goblin_fire_resistant)),
        cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 100, D), assertion(D == 50).

test(immune_gives_zero_damage, [
        setup((setup_alice_fire_attacker, setup_goblin_fire_immune)),
        cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 100, D), assertion(D == 0).

test(armor_reduces_damage, [setup(setup_goblin_armor15), cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 50, D), assertion(D == 35).

test(armor_cannot_go_negative, [setup(setup_goblin_armor15), cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 10, D), assertion(D == 0).

test(physical_armor_blocks_physical, [
        setup(setup_goblin_physical_armor),
        cleanup(clear_facts)]) :-
    %% default damage type = physical
    effective_damage(alice, goblin, 50, D), assertion(D == 35).

test(physical_armor_does_not_block_fire, [
        setup((setup_alice_fire_attacker, setup_goblin_physical_armor)),
        cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 50, D), assertion(D == 50).

test(buff_increases_damage, [setup(setup_alice_buff), cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 100, D), assertion(D == 150).

test(debuff_reduces_damage, [setup(setup_alice_debuff), cleanup(clear_facts)]) :-
    effective_damage(alice, goblin, 100, D), assertion(D == 50).

test(buff_and_resist_combined, [
        setup((setup_alice_buff, setup_alice_fire_attacker, setup_goblin_fire_resistant)),
        cleanup(clear_facts)]) :-
    %% 100 * 1.5 (buff) * 0.5 (resist) = 75
    effective_damage(alice, goblin, 100, D), assertion(D == 75).

:- end_tests(combat_damage).

%% ── is_defeated/1 ────────────────────────────────────────────────────────────

:- begin_tests(combat_defeated).

test(zero_hp_is_defeated, [setup(setup_goblin_zero_hp), cleanup(clear_facts)]) :-
    assertion(is_defeated(goblin)).

test(negative_hp_is_defeated, [setup(setup_goblin_negative_hp), cleanup(clear_facts)]) :-
    assertion(is_defeated(goblin)).

test(positive_hp_not_defeated, [setup(setup_goblin_positive_hp), cleanup(clear_facts)]) :-
    assertion(\+ is_defeated(goblin)).

:- end_tests(combat_defeated).

%% ── status_effect_active/2 ───────────────────────────────────────────────────

:- begin_tests(combat_status).

test(status_present, [setup(setup_alice_poisoned), cleanup(clear_facts)]) :-
    assertion(status_effect_active(alice, poisoned)).

test(status_absent, [setup(true), cleanup(clear_facts)]) :-
    assertion(\+ status_effect_active(alice, poisoned)).

test(multiple_statuses, [setup(setup_alice_multi_status), cleanup(clear_facts)]) :-
    assertion(status_effect_active(alice, poisoned)),
    assertion(status_effect_active(alice, burning)),
    assertion(\+ status_effect_active(alice, stunned)).

:- end_tests(combat_status).

%% ── can_attack/2 ─────────────────────────────────────────────────────────────

:- begin_tests(combat_can_attack).

test(can_attack_normally, [setup(setup_alice_alive_goblin_alive), cleanup(clear_facts)]) :-
    assertion(can_attack(alice, goblin)).

test(cannot_attack_if_defeated, [setup(setup_alice_defeated), cleanup(clear_facts)]) :-
    assertion(\+ can_attack(alice, goblin)).

test(cannot_attack_defeated_target, [setup(setup_goblin_defeated), cleanup(clear_facts)]) :-
    assertion(\+ can_attack(alice, goblin)).

test(stunned_cannot_attack, [setup(setup_alice_stunned), cleanup(clear_facts)]) :-
    assertion(\+ can_attack(alice, goblin)).

test(frozen_cannot_attack, [setup(setup_alice_frozen), cleanup(clear_facts)]) :-
    assertion(\+ can_attack(alice, goblin)).

test(sleeping_cannot_attack, [setup(setup_alice_sleeping), cleanup(clear_facts)]) :-
    assertion(\+ can_attack(alice, goblin)).

test(poisoned_can_still_attack, [setup(setup_alice_poisoned_alive), cleanup(clear_facts)]) :-
    assertion(can_attack(alice, goblin)).

test(out_of_range_cannot_attack, [setup(setup_alice_out_of_range), cleanup(clear_facts)]) :-
    assertion(\+ can_attack(alice, goblin)).

:- end_tests(combat_can_attack).

%% ── turn_order/2 ─────────────────────────────────────────────────────────────

:- begin_tests(combat_turn_order).

test(order_by_speed_desc, [setup(setup_turn_order_three), cleanup(clear_facts)]) :-
    turn_order([alice, goblin, troll], Ordered),
    assertion(Ordered == [alice, goblin, troll]).

test(order_input_order_irrelevant, [setup(setup_turn_order_three), cleanup(clear_facts)]) :-
    turn_order([troll, alice, goblin], Ordered),
    assertion(Ordered == [alice, goblin, troll]).

test(tie_broken_by_name_asc, [setup(setup_turn_order_tie), cleanup(clear_facts)]) :-
    %% both speed 10 — alphabetical tiebreak: alice < goblin
    turn_order([goblin, alice], Ordered),
    assertion(Ordered == [alice, goblin]).

test(no_speed_goes_last, [setup(setup_turn_order_one_no_speed), cleanup(clear_facts)]) :-
    %% alice speed=8, troll has no speed attr (defaults to 0)
    turn_order([troll, alice], Ordered),
    assertion(Ordered == [alice, troll]).

test(single_combatant, [setup(setup_alice_speed5), cleanup(clear_facts)]) :-
    turn_order([alice], Ordered),
    assertion(Ordered == [alice]).

:- end_tests(combat_turn_order).
