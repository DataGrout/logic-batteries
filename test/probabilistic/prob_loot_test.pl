:- use_module(library(plunit)).

:- consult('../../modules/games/loot-tables/loot_tables').
:- consult('../../modules/probabilistic/prob-loot/prob_loot').

%% (clear_facts/0 is in test/support/test_helpers.pl)
%%
%% NOTE: The annotated drop_occurs/2 rules (0.90::drop_occurs(...) :- ...) are
%% compiled into probabilistic clauses only within the DataGrout LC runtime.
%% Standalone tests cover the deterministic exports: drop_probability/3,
%% expected_drops/4, and guaranteed_drop/2 (drop_chance >= 100).
%% Noisy-OR probability queries are exercised in problog_battery_test.exs.

setup_loot_table :-
    assertz(relation(goblin, can_drop, gold_coin)),
    assertz(attribute(gold_coin, rarity, common)),
    assertz(relation(dragon, can_drop, dragon_scale)),
    assertz(attribute(dragon_scale, rarity, legendary)),
    assertz(relation(chest, can_drop, iron_key)),
    assertz(attribute(iron_key, rarity, uncommon)).

setup_custom_chance :-
    assertz(relation(boss, can_drop, trophy)),
    assertz(attribute(trophy, drop_chance, 50)).

setup_guaranteed_drop :-
    assertz(relation(quest_chest, can_drop, quest_item)),
    assertz(attribute(quest_item, drop_chance, 100)).

setup_high_chance_drop :-
    assertz(relation(barrel, can_drop, apple)),
    assertz(attribute(apple, drop_chance, 150)).

%% ── drop_probability/3 ───────────────────────────────────────────────────────

:- begin_tests(prob_loot_drop_probability).

test(common_rarity_probability, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    drop_probability(goblin, gold_coin, P),
    assertion(P =:= 70 / 100).

test(legendary_rarity_probability, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    drop_probability(dragon, dragon_scale, P),
    assertion(P =:= 1 / 100).

test(uncommon_rarity_probability, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    drop_probability(chest, iron_key, P),
    assertion(P =:= 30 / 100).

test(explicit_drop_chance_overrides_rarity, [setup(setup_custom_chance), cleanup(clear_facts)]) :-
    drop_probability(boss, trophy, P),
    assertion(P =:= 50 / 100).

:- end_tests(prob_loot_drop_probability).

%% ── expected_drops/4 ─────────────────────────────────────────────────────────

:- begin_tests(prob_loot_expected_drops).

test(expected_drops_common, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    expected_drops(goblin, gold_coin, 10, Expected),
    assertion(Expected =:= 7.0).

test(expected_drops_legendary, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    expected_drops(dragon, dragon_scale, 100, Expected),
    assertion(Expected =:= 1.0).

test(expected_drops_fractional, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    expected_drops(chest, iron_key, 1, Expected),
    assertion(Expected =:= 0.3).

:- end_tests(prob_loot_expected_drops).

%% ── guaranteed_drop/2 (deterministic predicate, separate from drop_occurs/2) ─
%% Use guaranteed_drop/2 for items with drop_chance >= 100. Kept separate from
%% drop_occurs/2 because ProbLog mis-evaluates unannotated co-clauses, inflating
%% noisy-OR results for legendary/rare items that should not be guaranteed.

:- begin_tests(prob_loot_guaranteed_drop).

test(guaranteed_drop_at_100pct, [setup(setup_guaranteed_drop), cleanup(clear_facts)]) :-
    assertion(guaranteed_drop(quest_chest, quest_item)).

test(guaranteed_drop_above_100pct, [setup(setup_high_chance_drop), cleanup(clear_facts)]) :-
    assertion(guaranteed_drop(barrel, apple)).

test(non_guaranteed_chance_below_100_does_not_fire, [setup(setup_custom_chance), cleanup(clear_facts)]) :-
    %% 50% drop_chance < 100: guaranteed_drop fails (use drop_probability/3 instead).
    assertion(\+ guaranteed_drop(boss, trophy)).

test(no_drop_chance_attribute_does_not_fire, [setup(setup_loot_table), cleanup(clear_facts)]) :-
    %% Items with only rarity_tier (no drop_chance) are not guaranteed drops.
    assertion(\+ guaranteed_drop(dragon, dragon_scale)),
    assertion(\+ guaranteed_drop(goblin, gold_coin)).

:- end_tests(prob_loot_guaranteed_drop).
