:- use_module(library(plunit)).

%% d20-combat requires d20-core and d20-conditions in the same namespace;
%% consulting all three mirrors the registry `requires` chain.
:- consult('../../modules/d20/d20-core/d20_core').
:- consult('../../modules/d20/d20-conditions/d20_conditions').
:- consult('../../modules/d20/d20-combat/d20_combat').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_alice_str16 :-
    assertz(attribute(alice, str, 16)),
    assertz(attribute(alice, level, 1)),
    assertz(attribute(alice, hp, 20)),
    assertz(attribute(alice, damage_type, slashing)).

setup_goblin_ac15_hp7 :-
    assertz(attribute(goblin, ac, 15)),
    assertz(attribute(goblin, hp, 7)).

setup_goblin_resists_slashing :-
    assertz(attribute(goblin, resist_slashing, true)).

setup_goblin_immune_slashing :-
    assertz(attribute(goblin, immune_slashing, true)).

setup_goblin_vulnerable_slashing :-
    assertz(attribute(goblin, vulnerable_slashing, true)).

setup_shade_resist_physical :-
    assertz(attribute(shade, resist_physical, true)).

setup_derived_ac_rogue :-
    assertz(attribute(rgue, dex, 16)),
    assertz(attribute(rgue, armor_base_ac, 12)).

setup_derived_ac_paladin :-
    assertz(attribute(pal, dex, 14)),
    assertz(attribute(pal, armor_base_ac, 18)),
    assertz(attribute(pal, no_dex_to_ac, true)),
    assertz(attribute(pal, shield, true)).

setup_unarmored_monk :-
    assertz(attribute(monk, dex, 16)).

setup_initiative_trio :-
    assertz(attribute(a, initiative, 3)),
    assertz(attribute(b, initiative, 17)),
    assertz(attribute(c, initiative, 11)).

setup_paralyzed_alice :-
    setup_alice_str16,
    setup_goblin_ac15_hp7,
    assertz(attribute(alice, condition, paralyzed)).

setup_combatants :-
    setup_alice_str16,
    setup_goblin_ac15_hp7.

%% plunit runs inline setup goals in the unit's module, so assertz there
%% would land outside `user` where the battery rules look — all fact
%% assertions must live in named predicates defined at file level.

setup_defeated_z :-
    assertz(attribute(z, hp, 0)).

setup_out_of_range :-
    setup_combatants,
    assertz(relation(alice, out_of_range, goblin)).

setup_dex_pair :-
    assertz(attribute(d, dex, 18)),
    assertz(attribute(e, dex, 8)).

setup_invisible_attacker :-
    assertz(attribute(a1, condition, invisible)).

setup_prone_adjacent :-
    assertz(attribute(t1, condition, prone)),
    assertz(relation(a1, adjacent_to, t1)).

setup_prone_only :-
    assertz(attribute(t1, condition, prone)).

setup_frightened_only :-
    assertz(attribute(a1, condition, frightened)).

setup_frightened_visible :-
    assertz(attribute(a1, condition, frightened)),
    assertz(relation(a1, can_see, t1)).

setup_cover :-
    assertz(relation(a1, has_cover_vs, t1)).

setup_high_ground :-
    assertz(relation(a1, has_high_ground_vs, t1)).

setup_invisible_and_poisoned :-
    assertz(attribute(a1, condition, invisible)),
    assertz(attribute(a1, condition, poisoned)).

setup_hp_max_7 :-
    assertz(attribute(g2, hp_max, 7)).

:- begin_tests(d20_combat).

%% ── armor class derivation ───────────────────────────────────────────────────

test(ac_direct, [setup((clear_facts, setup_goblin_ac15_hp7))]) :-
    entity_ac(goblin, 15).

test(ac_light_armor_adds_dex, [setup((clear_facts, setup_derived_ac_rogue))]) :-
    %% leather 12 + DEX (+3) = 15
    entity_ac(rgue, 15).

test(ac_heavy_armor_shield_no_dex, [setup((clear_facts, setup_derived_ac_paladin))]) :-
    %% plate 18 + shield 2, DEX suppressed = 20
    entity_ac(pal, 20).

test(ac_unarmored, [setup((clear_facts, setup_unarmored_monk))]) :-
    %% 10 + DEX (+3) = 13
    entity_ac(monk, 13).

%% ── hit resolution ───────────────────────────────────────────────────────────

test(nat_1_always_misses, [setup((clear_facts, setup_combatants)), fail]) :-
    hits_ac(alice, goblin, 1).

test(nat_20_always_hits, [setup(clear_facts)]) :-
    %% even with no facts asserted at all
    hits_ac(nobody, nothing, 20).

test(hit_on_boundary, [setup((clear_facts, setup_combatants)), nondet]) :-
    %% STR +3, no proficiency: 12 + 3 = 15 >= AC 15
    hits_ac(alice, goblin, 12).

test(miss_below_boundary, [setup((clear_facts, setup_combatants)), fail]) :-
    hits_ac(alice, goblin, 11).

%% ── d20_resistance ladder ────────────────────────────────────────────────────────

test(resistance_default, [setup((clear_facts, setup_combatants))]) :-
    d20_resistance(goblin, slashing, 1.0).

test(resist_halves, [setup((clear_facts, setup_goblin_resists_slashing))]) :-
    d20_resistance(goblin, slashing, 0.5).

test(immune_zeroes, [setup((clear_facts, setup_goblin_immune_slashing))]) :-
    d20_resistance(goblin, slashing, 0).

test(vulnerable_doubles, [setup((clear_facts, setup_goblin_vulnerable_slashing))]) :-
    d20_resistance(goblin, slashing, 2.0).

test(immune_beats_vulnerable,
     [setup((clear_facts, setup_goblin_immune_slashing,
             setup_goblin_vulnerable_slashing))]) :-
    d20_resistance(goblin, slashing, 0).

test(physical_category_catches_subtypes,
     [setup((clear_facts, setup_shade_resist_physical))]) :-
    d20_resistance(shade, slashing, 0.5),
    d20_resistance(shade, piercing, 0.5),
    d20_resistance(shade, bludgeoning, 0.5),
    d20_resistance(shade, fire, 1.0).

%% ── damage: modifier, d20_resistance, SRD round-down ─────────────────────────────

test(damage_adds_str_mod, [setup((clear_facts, setup_combatants))]) :-
    %% dice 6 + STR (+3) = 9
    d20_damage(alice, goblin, 6, 9).

test(resisted_damage_rounds_down,
     [setup((clear_facts, setup_alice_str16, setup_goblin_ac15_hp7,
             setup_goblin_resists_slashing))]) :-
    %% (6 + 3) * 0.5 = 4.5 → SRD rounds down → 4
    d20_damage(alice, goblin, 6, 4).

test(immune_damage_is_zero,
     [setup((clear_facts, setup_alice_str16, setup_goblin_immune_slashing))]) :-
    d20_damage(alice, goblin, 6, 0).

test(vulnerable_damage_doubles,
     [setup((clear_facts, setup_alice_str16, setup_goblin_vulnerable_slashing))]) :-
    %% (4 + 3) * 2 = 14
    d20_damage(alice, goblin, 4, 14).

test(crit_doubles_dice_not_mod, [setup((clear_facts, setup_combatants))]) :-
    %% dice 6 doubled = 12, + STR (+3) = 15
    d20_crit_damage(alice, goblin, 6, 15).

%% ── defeat and gating ────────────────────────────────────────────────────────

test(defeated_at_zero, [setup((clear_facts, setup_defeated_z))]) :-
    d20_is_defeated(z).

test(d20_can_attack, [setup((clear_facts, setup_combatants))]) :-
    d20_can_attack(alice, goblin).

test(paralyzed_cannot_attack,
     [setup((clear_facts, setup_paralyzed_alice)), fail]) :-
    d20_can_attack(alice, goblin).

test(out_of_range_cannot_attack,
     [setup((clear_facts, setup_out_of_range)), fail]) :-
    d20_can_attack(alice, goblin).

%% ── initiative ───────────────────────────────────────────────────────────────

test(initiative_descending, [setup((clear_facts, setup_initiative_trio))]) :-
    d20_initiative_order([a, b, c], [b, c, a]).

test(initiative_dex_fallback, [setup((clear_facts, setup_dex_pair))]) :-
    d20_initiative_order([e, d], [d, e]).

%% ── advantage / disadvantage matrix ──────────────────────────────────────────

test(invisible_attacker_advantage,
     [setup((clear_facts, setup_invisible_attacker))]) :-
    advantage_on_attack(a1, t1).

test(prone_target_advantage_when_adjacent,
     [setup((clear_facts, setup_prone_adjacent))]) :-
    advantage_on_attack(a1, t1).

test(prone_target_disadvantage_at_range,
     [setup((clear_facts, setup_prone_only))]) :-
    disadvantage_on_attack(a1, t1).

test(frightened_disadvantage_needs_visibility,
     [setup((clear_facts, setup_frightened_only)), fail]) :-
    disadvantage_on_attack(a1, t1).

test(frightened_disadvantage_when_source_visible,
     [setup((clear_facts, setup_frightened_visible))]) :-
    disadvantage_on_attack(a1, t1).

test(cover_imposes_disadvantage, [setup((clear_facts, setup_cover))]) :-
    disadvantage_on_attack(a1, t1).

test(high_ground_grants_advantage, [setup((clear_facts, setup_high_ground))]) :-
    advantage_on_attack(a1, t1).

%% ── net roll mode (RAW cancellation) ─────────────────────────────────────────

test(roll_mode_advantage,
     [setup((clear_facts, setup_invisible_attacker))]) :-
    d20_attack_roll_mode(a1, t1, advantage).

test(roll_mode_disadvantage,
     [setup((clear_facts, setup_cover))]) :-
    d20_attack_roll_mode(a1, t1, disadvantage).

test(roll_mode_cancels_to_normal,
     [setup((clear_facts, setup_invisible_and_poisoned))]) :-
    %% invisible grants advantage, poisoned imposes disadvantage → cancel
    d20_attack_roll_mode(a1, t1, normal).

test(roll_mode_normal_by_default, [setup(clear_facts)]) :-
    d20_attack_roll_mode(a1, t1, normal).

%% ── death saves ──────────────────────────────────────────────────────────────

test(death_save_nat_1)  :- d20_death_save(1, critical_failure).
test(death_save_low)    :- d20_death_save(7, failure).
test(death_save_ten)    :- d20_death_save(10, success).
test(death_save_high)   :- d20_death_save(19, success).
test(death_save_nat_20) :- d20_death_save(20, critical_success).

%% ── instant death ────────────────────────────────────────────────────────────

test(instant_death_at_max, [setup((clear_facts, setup_hp_max_7))]) :-
    d20_instant_death(g2, 7).

test(no_instant_death_below_max,
     [setup((clear_facts, setup_hp_max_7)), fail]) :-
    d20_instant_death(g2, 6).

:- end_tests(d20_combat).
