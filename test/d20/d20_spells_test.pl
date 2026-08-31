:- use_module(library(plunit)).

%% d20-spells requires d20-core (DC, save modifiers); consulting both mirrors
%% the registry `requires` chain.
:- consult('../../modules/d20/d20-core/d20_core').
:- consult('../../modules/d20/d20-spells/d20_spells').

%% ── Setup predicates ─────────────────────────────────────────────────────────

clear_spell_facts :-
    retractall(attribute(_, _, _)),
    retractall(relation(_, _, _)).

setup_spell_wizard :-
    %% level 1 wizard, INT 16 → DC 13, two first-level slots
    assertz(attribute(wiz, level, 1)),
    assertz(attribute(wiz, int, 16)),
    assertz(attribute(wiz, spellcasting_ability, int)),
    assertz(attribute(wiz, slots_l1, 2)),
    assertz(relation(wiz, knows_spell, fire_bolt)),
    assertz(relation(wiz, knows_spell, burning_hands)).

setup_spell_wizard_spent :-
    setup_spell_wizard,
    assertz(attribute(wiz, slots_l1_used, 2)).

setup_high_level_wizard :-
    assertz(attribute(wiz11, level, 11)),
    assertz(relation(wiz11, knows_spell, fire_bolt)).

setup_cleric_prepared :-
    %% clerics prepare: knowing without preparing is not enough
    assertz(attribute(cle, prepares_spells, true)),
    assertz(attribute(cle, slots_l1, 2)),
    assertz(relation(cle, knows_spell, bless)),
    assertz(relation(cle, prepared_spell, cure_wounds)).

setup_upcaster :-
    assertz(attribute(sorc, slots_l2, 1)),
    assertz(relation(sorc, knows_spell, burning_hands)).

setup_save_pair :-
    %% caster WIS 16 lvl 1 → DC 13; target DEX 14 → +2 save
    assertz(attribute(cst, level, 1)),
    assertz(attribute(cst, wis, 16)),
    assertz(attribute(cst, spellcasting_ability, wis)),
    assertz(attribute(tgt, dex, 14)).

setup_tough_concentrator :-
    assertz(attribute(conc, con, 14)).

:- begin_tests(d20_spells, [setup(clear_spell_facts), cleanup(clear_spell_facts)]).

%% ── The grimoire ─────────────────────────────────────────────────────────────

test(grimoire_levels) :-
    d20_spell(fire_bolt, 0, evocation),
    d20_spell(hold_person, 2, enchantment).

test(cast_actions) :-
    spell_cast_action(healing_word, bonus_action),
    spell_cast_action(fire_bolt, action).

test(save_spells_declare_on_success) :-
    spell_save(burning_hands, dex, half),
    spell_save(hold_person, wis, none),
    \+ spell_save(fire_bolt, _, _).

%% ── Knowing, preparing, slots ────────────────────────────────────────────────

test(known_caster_casts_cantrip_freely, [setup(setup_spell_wizard), cleanup(clear_spell_facts)]) :-
    d20_can_cast(wiz, fire_bolt, 0).

test(levelled_spell_needs_slot, [setup(setup_spell_wizard), cleanup(clear_spell_facts)]) :-
    d20_can_cast(wiz, burning_hands, 1).

test(spent_slots_close_the_gate, [setup(setup_spell_wizard_spent), cleanup(clear_spell_facts)]) :-
    \+ d20_can_cast(wiz, burning_hands, 1),
    d20_can_cast(wiz, fire_bolt, 0).  %% cantrips never spend

test(prepared_caster_needs_preparation, [setup(setup_cleric_prepared), cleanup(clear_spell_facts)]) :-
    d20_can_cast(cle, cure_wounds, 1),
    \+ d20_can_cast(cle, bless, 1).  %% known but unprepared

test(slot_accounting, [setup(setup_spell_wizard_spent), cleanup(clear_spell_facts)]) :-
    spell_slots_total(wiz, 1, 2),
    spell_slots_expended(wiz, 1, 2),
    \+ spell_slot_available(wiz, 1).

test(expended_defaults_to_zero, [setup(setup_spell_wizard), cleanup(clear_spell_facts)]) :-
    spell_slots_expended(wiz, 1, 0),
    spell_slot_available(wiz, 1).

test(castable_summary, [setup(setup_spell_wizard_spent), cleanup(clear_spell_facts)]) :-
    spell_castable(wiz, fire_bolt),
    \+ spell_castable(wiz, burning_hands).

%% ── Scaling ──────────────────────────────────────────────────────────────────

test(cantrip_scales_with_caster_level, [setup(setup_high_level_wizard), cleanup(clear_spell_facts)]) :-
    spell_effective_dice(fire_bolt, 1, 0, 1, 10),
    spell_effective_dice(fire_bolt, 5, 0, 2, 10),
    spell_effective_dice(fire_bolt, 11, 0, 3, 10),
    spell_effective_dice(fire_bolt, 17, 0, 4, 10).

test(upcast_adds_dice, [setup(setup_upcaster), cleanup(clear_spell_facts)]) :-
    spell_effective_dice(burning_hands, 1, 1, 3, 6),
    spell_effective_dice(burning_hands, 1, 2, 4, 6).

test(upcasting_uses_higher_slot, [setup(setup_upcaster), cleanup(clear_spell_facts)]) :-
    d20_can_cast(sorc, burning_hands, 2),
    \+ d20_can_cast(sorc, burning_hands, 1).  %% no level-1 slot at all

test(heals_upcast_too) :-
    spell_heal_profile(cure_wounds, 1, 1, 8),
    spell_heal_profile(cure_wounds, 3, 3, 8).

%% ── Save resolution ──────────────────────────────────────────────────────────

test(save_success_meets_dc, [setup(setup_save_pair), cleanup(clear_spell_facts)]) :-
    %% DC 13, target +2: a roll of 11 makes exactly 13 — success
    d20_spell_save(cst, tgt, web, 11, save_success).

test(save_failure_under_dc, [setup(setup_save_pair), cleanup(clear_spell_facts)]) :-
    d20_spell_save(cst, tgt, web, 10, save_failure).

%% ── Concentration ────────────────────────────────────────────────────────────

test(concentration_dc_floor_ten) :-
    d20_concentration_dc(6, 10),
    d20_concentration_dc(20, 10),
    d20_concentration_dc(30, 15).

test(concentration_check_outcomes, [setup(setup_tough_concentrator), cleanup(clear_spell_facts)]) :-
    %% CON 14 → +2: DC 10 needs an 8
    d20_concentration_check(conc, 8, 8, holds),
    d20_concentration_check(conc, 8, 7, broken).

:- end_tests(d20_spells).
