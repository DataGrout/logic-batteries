:- use_module(library(plunit)).

:- consult('../../modules/games/economy/economy').
:- consult('../../modules/probabilistic/prob-economy/prob_economy').

%% (clear_facts/0 is in test/support/test_helpers.pl)
%%
%% NOTE: Annotated supply_disruption/1 and demand_spike/1 rules fire
%% probabilistically in the LC runtime. Standalone tests cover the deterministic
%% accessors: supply_disruption/2, demand_spike/2, market_volatility/3,
%% price_range/4, and expected_price/2.

setup_import_item_storm :-
    assertz(attribute(iron_ingot, import_dependent, true)),
    assertz(attribute(world, weather, storm)).

setup_perishable_summer :-
    assertz(attribute(grain, perishable, true)),
    assertz(attribute(world, season, summer)).

setup_healing_conflict :-
    assertz(attribute(potion, category, healing)),
    assertz(attribute(world, recent_conflict, true)).

setup_weapons_threat :-
    assertz(attribute(sword, category, weapons)),
    assertz(attribute(world, threat_rising, true)).

setup_food_winter :-
    assertz(attribute(bread, category, food)),
    assertz(attribute(world, season, winter)).

setup_tools_blocked :-
    assertz(attribute(hammer, category, tools)),
    assertz(attribute(world, trade_route_blocked, true)).

setup_priced_item :-
    assertz(attribute(iron_ingot, import_dependent, true)),
    assertz(attribute(iron_ingot, base_price, 100)),
    assertz(attribute(world, weather, storm)).

setup_demand_priced_item :-
    assertz(attribute(potion, category, healing)),
    assertz(attribute(potion, base_price, 50)),
    assertz(attribute(world, recent_conflict, true)).

setup_silk_storm_and_blocked :-
    assertz(attribute(silk, import_dependent, true)),
    assertz(attribute(world, weather, storm)),
    assertz(attribute(world, trade_route_blocked, true)).

setup_wartime_supply_demand :-
    assertz(attribute(arrow, import_dependent, true)),
    assertz(attribute(arrow, category, weapons)),
    assertz(attribute(world, weather, storm)),
    assertz(attribute(world, threat_rising, true)).

setup_stable_rock :-
    assertz(attribute(rock, base_price, 10)).

setup_stable_rock_price :-
    assertz(attribute(rock2, base_price, 10)).

setup_diamond_rare :-
    assertz(attribute(diamond, rarity, rare)).

setup_stone_building :-
    assertz(attribute(stone, category, building)).

%% ── supply_disruption/2 (deterministic accessor) ─────────────────────────────

:- begin_tests(prob_economy_supply_disruption).

test(import_item_in_storm, [setup(setup_import_item_storm), cleanup(clear_facts)]) :-
    supply_disruption(iron_ingot, Ps),
    assertion(Ps =:= 0.65).

test(perishable_in_summer, [setup(setup_perishable_summer), cleanup(clear_facts)]) :-
    supply_disruption(grain, Ps),
    assertion(Ps =:= 0.30).

test(no_disruption_when_conditions_absent, [setup(setup_diamond_rare), cleanup(clear_facts)]) :-
    supply_disruption(diamond, Ps),
    assertion(Ps =:= 0.0).

test(highest_probability_wins_when_multiple_match, [setup(setup_silk_storm_and_blocked), cleanup(clear_facts)]) :-
    supply_disruption(silk, Ps),
    assertion(Ps =:= 0.65).   %% storm beats trade_route_blocked (0.50)

:- end_tests(prob_economy_supply_disruption).

%% ── demand_spike/2 (deterministic accessor) ──────────────────────────────────

:- begin_tests(prob_economy_demand_spike).

test(healing_in_conflict, [setup(setup_healing_conflict), cleanup(clear_facts)]) :-
    demand_spike(potion, Pd),
    assertion(Pd =:= 0.75).

test(weapons_threat_rising, [setup(setup_weapons_threat), cleanup(clear_facts)]) :-
    demand_spike(sword, Pd),
    assertion(Pd =:= 0.45).

test(food_winter_demand, [setup(setup_food_winter), cleanup(clear_facts)]) :-
    demand_spike(bread, Pd),
    assertion(Pd =:= 0.35).

test(tools_route_blocked, [setup(setup_tools_blocked), cleanup(clear_facts)]) :-
    demand_spike(hammer, Pd),
    assertion(Pd =:= 0.50).

test(no_spike_when_no_conditions, [setup(setup_stone_building), cleanup(clear_facts)]) :-
    demand_spike(stone, Pd),
    assertion(Pd =:= 0.0).

:- end_tests(prob_economy_demand_spike).

%% ── market_volatility/3 ──────────────────────────────────────────────────────

:- begin_tests(prob_economy_volatility).

test(both_supply_and_demand, [setup(setup_wartime_supply_demand), cleanup(clear_facts)]) :-
    market_volatility(arrow, Ps, Pd),
    assertion(Ps =:= 0.65),
    assertion(Pd =:= 0.45).

test(only_supply_disruption, [setup(setup_import_item_storm), cleanup(clear_facts)]) :-
    market_volatility(iron_ingot, Ps, Pd),
    assertion(Ps > 0.0),
    assertion(Pd =:= 0.0).

:- end_tests(prob_economy_volatility).

%% ── price_range/4 ────────────────────────────────────────────────────────────

:- begin_tests(prob_economy_price_range).

test(supply_disruption_lowers_floor, [setup(setup_priced_item), cleanup(clear_facts)]) :-
    price_range(iron_ingot, Base, Low, _High),
    assertion(Base =:= 100),
    assertion(Low < Base).

test(demand_spike_raises_ceiling, [setup(setup_demand_priced_item), cleanup(clear_facts)]) :-
    price_range(potion, Base, _Low, High),
    assertion(Base =:= 50),
    assertion(High > Base).

test(stable_market_same_as_base, [setup(setup_stable_rock), cleanup(clear_facts)]) :-
    price_range(rock, Base, Low, High),
    %% no supply/demand pressure → Low = round(10 * 1.0) = 10, High = 10
    assertion(Low =:= Base),
    assertion(High =:= Base).

:- end_tests(prob_economy_price_range).

%% ── expected_price/2 ─────────────────────────────────────────────────────────

:- begin_tests(prob_economy_expected_price).

test(supply_disruption_lowers_expected_price, [setup(setup_priced_item), cleanup(clear_facts)]) :-
    expected_price(iron_ingot, Price),
    %% base 100, Ps=0.65, Pd=0: round(100 * (1.0 - 0.65*0.2 + 0*0.3)) = round(87)
    assertion(Price =:= 87).

test(demand_spike_raises_expected_price, [setup(setup_demand_priced_item), cleanup(clear_facts)]) :-
    expected_price(potion, Price),
    %% base 50, Ps=0, Pd=0.75: round(50 * (1.0 - 0 + 0.75*0.3)) = round(61.25) = 61
    assertion(Price =:= 61).

test(stable_market_price_equals_base, [setup(setup_stable_rock_price), cleanup(clear_facts)]) :-
    expected_price(rock2, Price),
    assertion(Price =:= 10).

:- end_tests(prob_economy_expected_price).
