:- use_module(library(plunit)).

:- consult('../../modules/games/economy/economy').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_sword_recipe :-
    assertz(relation(iron_sword, requires, iron_ingot)),
    assertz(attribute(iron_sword, iron_ingot_qty, 3)).

setup_sword_recipe_multi :-
    assertz(relation(iron_sword, requires, iron_ingot)),
    assertz(attribute(iron_sword, iron_ingot_qty, 3)),
    assertz(relation(iron_sword, requires, wood)),
    assertz(attribute(iron_sword, wood_qty, 1)).

setup_alice_has_3_ingots :-
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)).

setup_alice_has_2_ingots :-
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)).

setup_alice_full_recipe :-
    setup_sword_recipe_multi,
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, wood)).

setup_alice_missing_wood :-
    setup_sword_recipe_multi,
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)),
    assertz(relation(alice, has_material, iron_ingot)).

setup_iron_ingot_price :-
    assertz(attribute(iron_ingot, base_price, 10)).

setup_sword_recipe_with_prices :-
    setup_sword_recipe,
    setup_iron_ingot_price.

setup_sword_flat_cost :-
    setup_sword_recipe,
    assertz(attribute(iron_sword, recipe_gold_cost, 50)).

setup_iron_sword_price :-
    assertz(attribute(iron_sword, base_price, 100)).

setup_iron_sword_supply_cheap :-
    setup_iron_sword_price,
    assertz(attribute(iron_sword, supply_factor, 0.5)).

setup_iron_sword_demand_expensive :-
    setup_iron_sword_price,
    assertz(attribute(iron_sword, demand_factor, 2.0)).

setup_iron_sword_supply_and_demand :-
    setup_iron_sword_price,
    assertz(attribute(iron_sword, supply_factor, 0.8)),
    assertz(attribute(iron_sword, demand_factor, 1.5)).

setup_custom_sell_ratio :-
    setup_iron_sword_price,
    assertz(attribute(economy, sell_ratio, 0.7)).

%% ── can_craft/2 ──────────────────────────────────────────────────────────────

:- begin_tests(economy_can_craft).

test(can_craft_with_exact_materials, [
        setup((setup_sword_recipe, setup_alice_has_3_ingots)),
        cleanup(clear_facts)]) :-
    assertion(can_craft(alice, iron_sword)).

test(can_craft_with_surplus, [
        setup((setup_sword_recipe,
               setup_alice_has_3_ingots,
               assertz(relation(alice, has_material, iron_ingot)))),
        cleanup(clear_facts)]) :-
    assertion(can_craft(alice, iron_sword)).

test(cannot_craft_too_few_materials, [
        setup((setup_sword_recipe, setup_alice_has_2_ingots)),
        cleanup(clear_facts)]) :-
    assertion(\+ can_craft(alice, iron_sword)).

test(cannot_craft_no_materials, [
        setup(setup_sword_recipe),
        cleanup(clear_facts)]) :-
    assertion(\+ can_craft(alice, iron_sword)).

test(can_craft_all_multi_ingredients, [
        setup(setup_alice_full_recipe),
        cleanup(clear_facts)]) :-
    assertion(can_craft(alice, iron_sword)).

test(cannot_craft_missing_one_ingredient, [
        setup(setup_alice_missing_wood),
        cleanup(clear_facts)]) :-
    assertion(\+ can_craft(alice, iron_sword)).

:- end_tests(economy_can_craft).

%% ── missing_materials/3 ──────────────────────────────────────────────────────

:- begin_tests(economy_missing).

test(nothing_missing_when_stocked, [
        setup((setup_sword_recipe, setup_alice_has_3_ingots)),
        cleanup(clear_facts)]) :-
    missing_materials(alice, iron_sword, M),
    assertion(M == []).

test(missing_all_when_empty, [
        setup(setup_sword_recipe),
        cleanup(clear_facts)]) :-
    missing_materials(alice, iron_sword, M),
    assertion(M == [material(iron_ingot, 3, 0)]).

test(missing_partial, [
        setup((setup_sword_recipe, setup_alice_has_2_ingots)),
        cleanup(clear_facts)]) :-
    missing_materials(alice, iron_sword, M),
    assertion(M == [material(iron_ingot, 3, 2)]).

test(missing_one_of_two_ingredients, [
        setup(setup_alice_missing_wood),
        cleanup(clear_facts)]) :-
    missing_materials(alice, iron_sword, M),
    assertion(M == [material(wood, 1, 0)]).

:- end_tests(economy_missing).

%% ── craft_cost/2 ─────────────────────────────────────────────────────────────

:- begin_tests(economy_craft_cost).

test(craft_cost_from_ingredient_prices, [
        setup(setup_sword_recipe_with_prices),
        cleanup(clear_facts)]) :-
    %% 3 * iron_ingot(10) = 30
    craft_cost(iron_sword, C), assertion(C == 30).

test(craft_cost_flat_override, [
        setup(setup_sword_flat_cost),
        cleanup(clear_facts)]) :-
    craft_cost(iron_sword, C), assertion(C == 50).

:- end_tests(economy_craft_cost).

%% ── buy_price/2 ──────────────────────────────────────────────────────────────

:- begin_tests(economy_buy_price).

test(buy_price_base, [setup(setup_iron_sword_price), cleanup(clear_facts)]) :-
    buy_price(iron_sword, P), assertion(P == 100).

test(buy_price_supply_cheap, [setup(setup_iron_sword_supply_cheap), cleanup(clear_facts)]) :-
    buy_price(iron_sword, P), assertion(P == 50).

test(buy_price_demand_expensive, [setup(setup_iron_sword_demand_expensive), cleanup(clear_facts)]) :-
    buy_price(iron_sword, P), assertion(P == 200).

test(buy_price_supply_and_demand, [setup(setup_iron_sword_supply_and_demand), cleanup(clear_facts)]) :-
    %% round(100 * 0.8 * 1.5) = 120
    buy_price(iron_sword, P), assertion(P == 120).

:- end_tests(economy_buy_price).

%% ── sell_price/2 ─────────────────────────────────────────────────────────────

:- begin_tests(economy_sell_price).

test(sell_price_default_half, [setup(setup_iron_sword_price), cleanup(clear_facts)]) :-
    sell_price(iron_sword, P), assertion(P == 50).

test(sell_price_custom_ratio, [setup(setup_custom_sell_ratio), cleanup(clear_facts)]) :-
    %% round(100 * 0.7) = 70
    sell_price(iron_sword, P), assertion(P == 70).

test(sell_always_less_than_buy, [setup(setup_iron_sword_price), cleanup(clear_facts)]) :-
    buy_price(iron_sword, Buy),
    sell_price(iron_sword, Sell),
    assertion(Sell < Buy).

:- end_tests(economy_sell_price).
