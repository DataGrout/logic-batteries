:- use_module(library(plunit)).

:- consult('../../modules/d20/d20-core/d20_core').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_rogue :-
    assertz(attribute(rogue, dex, 16)),
    assertz(attribute(rogue, level, 5)),
    assertz(attribute(rogue, expertise_stealth, true)),
    assertz(attribute(rogue, proficient_perception, true)).

setup_fighter :-
    assertz(attribute(fighter, str, 18)),
    assertz(attribute(fighter, dex, 14)),
    assertz(attribute(fighter, con, 16)),
    assertz(attribute(fighter, level, 5)),
    assertz(attribute(fighter, save_con, true)),
    assertz(attribute(fighter, attack_ability, str)),
    assertz(attribute(fighter, proficient_attack, true)).

setup_wizard :-
    assertz(attribute(wizard, int, 17)),
    assertz(attribute(wizard, level, 5)),
    assertz(attribute(wizard, spellcasting_ability, int)).

setup_finesse_rogue :-
    assertz(attribute(finn, str, 10)),
    assertz(attribute(finn, dex, 18)),
    assertz(attribute(finn, level, 5)),
    assertz(attribute(finn, finesse_attack, true)),
    assertz(attribute(finn, proficient_attack, true)).

:- begin_tests(d20_core).

%% ── ability_modifier: even and odd scores, above and below 10 ────────────────

test(mod_18) :- ability_modifier(18, 4).
test(mod_10) :- ability_modifier(10, 0).
test(mod_20) :- ability_modifier(20, 5).
test(mod_8)  :- ability_modifier(8, -1).

%% Floored division, not truncation: odd scores below 10 round DOWN.
test(mod_7_floors_down)  :- ability_modifier(7, -2).
test(mod_3_floors_down)  :- ability_modifier(3, -4).
test(mod_1_floors_down)  :- ability_modifier(1, -5).

%% ── proficiency_bonus by level ───────────────────────────────────────────────

test(pb_1)  :- proficiency_bonus(1, 2).
test(pb_4)  :- proficiency_bonus(4, 2).
test(pb_5)  :- proficiency_bonus(5, 3).
test(pb_9)  :- proficiency_bonus(9, 4).
test(pb_13) :- proficiency_bonus(13, 5).
test(pb_17) :- proficiency_bonus(17, 6).
test(pb_20) :- proficiency_bonus(20, 6).

%% ── skills: proficiency and expertise ────────────────────────────────────────

test(skill_expertise_doubles_pb, [setup((clear_facts, setup_rogue))]) :-
    %% DEX 16 (+3) + expertise (2 * PB 3) = +9
    skill_modifier(rogue, stealth, 9).

test(skill_proficient, [setup((clear_facts, setup_rogue))]) :-
    %% WIS unset (+0) + PB 3 = +3
    skill_modifier(rogue, perception, 3).

test(skill_unproficient, [setup((clear_facts, setup_rogue))]) :-
    %% DEX 16 (+3), no proficiency in acrobatics
    skill_modifier(rogue, acrobatics, 3).

test(passive_perception, [setup((clear_facts, setup_rogue))]) :-
    %% 10 + perception modifier (+3)
    passive_perception(rogue, 13).

%% ── saving throws ────────────────────────────────────────────────────────────

test(save_proficient, [setup((clear_facts, setup_fighter))]) :-
    %% CON 16 (+3) + PB 3 = +6
    saving_throw_modifier(fighter, con, 6).

test(save_unproficient, [setup((clear_facts, setup_fighter))]) :-
    %% DEX 14 (+2), no save proficiency
    saving_throw_modifier(fighter, dex, 2).

%% ── spell save DC ────────────────────────────────────────────────────────────

test(spell_save_dc, [setup((clear_facts, setup_wizard))]) :-
    %% 8 + PB 3 + INT mod 3 = 14
    spell_save_dc(wizard, 14).

%% ── attack bonus ─────────────────────────────────────────────────────────────

test(melee_attack_bonus, [setup((clear_facts, setup_fighter)), nondet]) :-
    %% STR 18 (+4) + PB 3 = +7
    attack_bonus(fighter, melee, 7).

test(finesse_uses_best_of_str_dex, [setup((clear_facts, setup_finesse_rogue)), nondet]) :-
    %% max(STR +0, DEX +4) + PB 3 = +7
    attack_bonus(finn, melee, 7).

test(spell_attack_bonus, [setup((clear_facts, setup_wizard))]) :-
    %% INT mod 3 + PB 3 = +6
    attack_bonus(wizard, spell, 6).

%% ── checks and saves ─────────────────────────────────────────────────────────

test(skill_check_meets_dc, [setup((clear_facts, setup_rogue)), nondet]) :-
    %% stealth +9: 10 + 9 = 19 >= DC 19
    d20_check(rogue, stealth, 10, 19).

test(skill_check_fails_dc, [setup((clear_facts, setup_rogue)), fail]) :-
    d20_check(rogue, stealth, 10, 20).

test(save_meets_dc, [setup((clear_facts, setup_fighter)), nondet]) :-
    %% CON save +6: 10 + 6 = 16 >= DC 16
    d20_save(fighter, con, 10, 16).

test(save_fails_dc, [setup((clear_facts, setup_fighter)), fail]) :-
    d20_save(fighter, con, 10, 17).

:- end_tests(d20_core).
