:- use_module(library(plunit)).

:- consult('../../modules/d20/d20-core/d20_core').
:- consult('../../modules/d20/d20-conditions/d20_conditions').
:- consult('../../modules/d20/d20-combat/d20_combat').
:- consult('../../modules/d20/d20-monsters/d20_monsters').

%% Other suites' clear_facts wipes the monster stat-block facts loaded above,
%% and plunit runs suites long after all files load. Snapshot every SRD
%% monster fact at load time; each test restores from the snapshot.

:- findall(attribute(E, A, V),
           ( attribute(E, srd, true), attribute(E, A, V) ),
           Facts),
   assertz(d20_srd_snapshot(Facts)).

restore_monsters :-
    clear_facts,
    d20_srd_snapshot(Facts),
    forall(member(F, Facts), assertz(F)).

:- begin_tests(d20_monsters).

test(snapshot_is_populated) :-
    d20_srd_snapshot(Facts),
    length(Facts, N),
    N > 100.

test(goblin_stat_block, [setup(restore_monsters)]) :-
    srd_monster(goblin),
    monster_cr(goblin, '1/4'),
    monster_xp(goblin, 50),
    monster_type(goblin, humanoid),
    entity_ac(goblin, 15).

test(cr_table_spot_checks, [setup(restore_monsters)]) :-
    monster_cr(commoner, 0),
    monster_cr(ogre, 2),
    monster_cr(troll, 5),
    monster_cr(vampire, 13),
    monster_xp(troll, 1800),
    monster_xp(vampire, 10000).

%% ── stat blocks compose with d20-combat ──────────────────────────────────────

test(skeleton_vulnerable_to_bludgeoning, [setup(restore_monsters)]) :-
    d20_resistance(skeleton, bludgeoning, 2.0).

test(shadow_resists_physical_via_category, [setup(restore_monsters)]) :-
    d20_resistance(shadow, slashing, 0.5),
    d20_resistance(shadow, cold, 0).          %% immune_cold

test(stone_golem_immune_to_physical, [setup(restore_monsters)]) :-
    d20_resistance(stone_golem, slashing, 0),
    d20_resistance(stone_golem, piercing, 0),
    d20_resistance(stone_golem, bludgeoning, 0).

test(troll_vulnerable_to_fire, [setup(restore_monsters)]) :-
    d20_resistance(troll, fire, 2.0).

%% ── stat blocks compose with d20-core ────────────────────────────────────────

test(goblin_passive_perception, [setup(restore_monsters)]) :-
    %% WIS 8 (-1), no proficiency → 10 - 1 = 9
    passive_perception(goblin, 9).

test(orc_melee_attack_bonus, [setup(restore_monsters), nondet]) :-
    %% explicit SRD attack profile (+5 greataxe) overrides derived STR math
    attack_bonus(orc, melee, 5).

test(goblin_stealth_override, [setup(restore_monsters), nondet]) :-
    %% SRD stat-block Stealth +6 beats the derived DEX+PB value
    skill_modifier(goblin, stealth, 6).

test(monster_attack_profile, [setup(restore_monsters), nondet]) :-
    d20_monster_attack(goblin, 4, '1d6', 2, slashing),
    d20_monster_attack(stone_golem, 10, '3d8', 6, bludgeoning).

:- end_tests(d20_monsters).
