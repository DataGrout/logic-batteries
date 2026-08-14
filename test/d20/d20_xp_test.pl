:- use_module(library(plunit)).

:- consult('../../modules/d20/d20-xp/d20_xp').
:- consult('../../modules/d20/d20-monsters/d20_monsters').

%% Snapshot pattern — see d20_monsters_test.pl for rationale.
:- findall(attribute(E, A, V),
           ( attribute(E, srd, true), attribute(E, A, V) ),
           Facts),
   assertz(d20_xp_snapshot(Facts)).

restore_xp_monsters :-
    clear_facts,
    d20_xp_snapshot(Facts),
    forall(member(F, Facts), assertz(F)).

:- begin_tests(d20_xp).

%% ── XP-by-CR table ───────────────────────────────────────────────────────────

test(xp_cr_0)        :- xp_for_cr(0, 10).
test(xp_cr_eighth)   :- xp_for_cr('1/8', 25).
test(xp_cr_half)     :- xp_for_cr('1/2', 100).
test(xp_cr_5)        :- xp_for_cr(5, 1800).
test(xp_cr_20)       :- xp_for_cr(20, 25000).
test(xp_cr_30)       :- xp_for_cr(30, 155000).

%% ── action-economy multiplier bands ──────────────────────────────────────────

test(mult_1, [nondet])   :- xp_multiplier(1, 1.0).
test(mult_2, [nondet])   :- xp_multiplier(2, 1.5).
test(mult_4, [nondet])   :- xp_multiplier(4, 2.0).
test(mult_8, [nondet])   :- xp_multiplier(8, 2.5).
test(mult_12, [nondet])  :- xp_multiplier(12, 3.0).
test(mult_15)  :- xp_multiplier(15, 4.0).

test(adjusted_xp_four_goblins, [nondet]) :-
    %% 4 × 50 = 200, ×2.0 = 400
    adjusted_xp([50, 50, 50, 50], 400, 2.0).

%% ── encounter difficulty ─────────────────────────────────────────────────────

test(four_goblins_easy_for_level_3_party, [nondet]) :-
    %% adjusted 400 / 4 players = 100/player; L3: easy 75 ≤ 100 < medium 150
    encounter_difficulty(3, 4, [50, 50, 50, 50], easy).

test(ogre_deadly_for_level_1_party, [nondet]) :-
    %% 450 / 4 = 112.5/player; L1 deadly threshold = 100
    encounter_difficulty(1, 4, [450], deadly).

test(two_cr1_hard_for_level_2_party, [nondet]) :-
    %% 2 × 200 = 400, ×1.5 = 600 / 4 = 150/player; L2 hard threshold = 150
    encounter_difficulty(2, 4, [200, 200], hard).

test(goblin_trivial_for_level_20_party, [nondet]) :-
    encounter_difficulty(20, 4, [50], trivial).

%% ── name-based difficulty (requires d20-monsters) ────────────────────────────

test(named_encounter_difficulty, [setup(restore_xp_monsters), nondet]) :-
    party_encounter_difficulty(3, 4, [goblin, goblin, goblin, goblin], easy).

test(named_boss_encounter, [setup(restore_xp_monsters), nondet]) :-
    party_encounter_difficulty(1, 4, [ogre], deadly).

:- end_tests(d20_xp).
