:- use_module(library(plunit)).

%% The Goblin Ambush — the shipping-line test. Two rounds of RAW martial
%% combat run end-to-end across all five batteries: if this suite passes,
%% a client can run a complete combat using only cell queries + its own dice.

:- consult('../../modules/d20/d20-core/d20_core').
:- consult('../../modules/d20/d20-conditions/d20_conditions').
:- consult('../../modules/d20/d20-combat/d20_combat').
:- consult('../../modules/d20/d20-monsters/d20_monsters').
:- consult('../../modules/d20/d20-xp/d20_xp').

:- findall(attribute(E, A, V),
           ( attribute(E, srd, true), attribute(E, A, V) ),
           Facts),
   assertz(d20_ambush_snapshot(Facts)).

setup_ambush :-
    clear_facts,
    d20_ambush_snapshot(Facts),
    forall(member(F, Facts), assertz(F)),
    %% Brakka, a level-3 fighter: chain mail + shield, warhammer, rolled 12 initiative
    assertz(attribute(brakka, str, 16)),
    assertz(attribute(brakka, dex, 14)),
    assertz(attribute(brakka, con, 14)),
    assertz(attribute(brakka, wis, 10)),
    assertz(attribute(brakka, level, 3)),
    assertz(attribute(brakka, armor_base_ac, 16)),
    assertz(attribute(brakka, no_dex_to_ac, true)),
    assertz(attribute(brakka, shield, true)),
    assertz(attribute(brakka, attack_ability, str)),
    assertz(attribute(brakka, proficient_attack, true)),
    assertz(attribute(brakka, damage_type, bludgeoning)),
    assertz(attribute(brakka, hp, 28)),
    assertz(attribute(brakka, hp_max, 28)),
    assertz(attribute(brakka, initiative, 12)).

setup_poisoned_goblin :-
    setup_ambush,
    assertz(attribute(goblin, condition, poisoned)).

:- begin_tests(d20_ambush).

test(the_ambush_is_an_easy_encounter, [setup(setup_ambush), nondet]) :-
    %% 2 goblins + 1 skeleton vs a party of four 3rd-level characters:
    %% 150 XP × 2.0 = 300, 75/player = exactly the L3 easy threshold
    party_encounter_difficulty(3, 4, [goblin, goblin, skeleton], easy).

test(goblin_wins_the_stealth_contest, [setup(setup_ambush), nondet]) :-
    %% stat-block Stealth +6 (override) vs Brakka's flat perception
    d20_contest(goblin, stealth, 12, brakka, perception, 15, a_wins).

test(initiative_rolled_beats_unrolled, [setup(setup_ambush), nondet]) :-
    %% Brakka rolled 12; the goblin falls back to DEX (+2)
    d20_initiative_order([goblin, brakka], [brakka, goblin]).

test(goblin_attacks_with_srd_numbers, [setup(setup_ambush), nondet]) :-
    %% scimitar +4 vs chain mail + shield (AC 18): 14 hits on the nose, 13 misses
    d20_monster_attack(goblin, 4, '1d6', 2, slashing),
    hits_ac(goblin, brakka, 14),
    \+ hits_ac(goblin, brakka, 13).

test(goblin_damage_uses_flat_bonus, [setup(setup_ambush), nondet]) :-
    %% client rolled 4 on 1d6; +2 flat, no resistance
    d20_damage(goblin, brakka, 4, 6).

test(warhammer_ruins_skeletons, [setup(setup_ambush), nondet]) :-
    %% (5 + STR 3) × 2.0 bludgeoning vulnerability = 16
    d20_damage(brakka, skeleton, 5, 16).

test(shadow_shrugs_off_the_warhammer, [setup(setup_ambush), nondet]) :-
    %% (5 + 3) × 0.5 physical resistance, rounded down = 4
    d20_damage(brakka, shadow, 5, 4).

test(poisoned_goblin_attacks_at_disadvantage,
     [setup(setup_poisoned_goblin), nondet]) :-
    d20_attack_roll_mode(goblin, brakka, disadvantage).

test(ogre_crit_is_scary_but_not_lethal, [setup(setup_ambush), nondet]) :-
    %% 9 on 2d8 doubled = 18, +4 flat = 22; short of instant death at 28
    d20_crit_damage(ogre, brakka, 9, 22),
    \+ d20_instant_death(brakka, 22),
    d20_instant_death(brakka, 28).

test(downed_fighter_rolls_death_saves, [setup(setup_ambush)]) :-
    d20_death_save(9, failure),
    d20_death_save(20, critical_success).

:- end_tests(d20_ambush).
