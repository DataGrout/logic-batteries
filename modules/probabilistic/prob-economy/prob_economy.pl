%% Battery: prob-economy v1.0.0
%% Requires: economy
%% Exports: supply_disruption/2, demand_spike/2, price_range/4,
%%          market_volatility/3, expected_price/2

battery_module('prob-economy', '1.0.0', auto).

battery_export('prob-economy', 'supply_disruption/2',
    'supply_disruption(Item, P) — P is probability (0.0–1.0) supply is disrupted based on world state').
battery_export('prob-economy', 'demand_spike/2',
    'demand_spike(Item, P) — P is probability demand is elevated based on world events').
battery_export('prob-economy', 'price_range/4',
    'price_range(Item, Base, Low, High) — Low and High are the probable price bounds given supply/demand uncertainty').
battery_export('prob-economy', 'market_volatility/3',
    'market_volatility(Item, Ps, Pd) — Ps is supply disruption probability, Pd is demand spike probability').
battery_export('prob-economy', 'expected_price/2',
    'expected_price(Item, Price) — expected buy price factoring in probable supply/demand shifts').

%% ── Probabilistic supply disruption rules ─────────────────────────────────
%% Assert world state to drive market uncertainty:
%%   attribute(world, weather, storm)
%%   attribute(world, season, winter)
%%   attribute(world, recent_conflict, true)
%%   attribute(world, threat_rising, true)
%%   attribute(world, trade_route_blocked, true)
%%
%% Assert item traits:
%%   attribute(iron_ingot, import_dependent, true)
%%   attribute(grain, perishable, true)
%%   attribute(iron_ingot, category, materials)

0.65::supply_disruption(Item) :-
    attribute(Item, import_dependent, true),
    attribute(world, weather, storm).

0.50::supply_disruption(Item) :-
    attribute(Item, import_dependent, true),
    attribute(world, trade_route_blocked, true).

0.25::supply_disruption(Item) :-
    attribute(Item, import_dependent, true),
    attribute(world, season, winter).

0.40::supply_disruption(Item) :-
    attribute(Item, perishable, true),
    attribute(world, weather, storm).

0.30::supply_disruption(Item) :-
    attribute(Item, perishable, true),
    attribute(world, season, summer).

%% ── Probabilistic demand spike rules ────────────────────────────────────
0.75::demand_spike(Item) :-
    attribute(Item, category, healing),
    attribute(world, recent_conflict, true).

0.55::demand_spike(Item) :-
    attribute(Item, category, healing),
    attribute(world, threat_rising, true).

0.45::demand_spike(Item) :-
    attribute(Item, category, weapons),
    attribute(world, threat_rising, true).

0.60::demand_spike(Item) :-
    attribute(Item, category, weapons),
    attribute(world, recent_conflict, true).

0.35::demand_spike(Item) :-
    attribute(Item, category, food),
    attribute(world, season, winter).

0.50::demand_spike(Item) :-
    attribute(Item, category, tools),
    attribute(world, trade_route_blocked, true).

%% ── Deterministic probability accessors ─────────────────────────────────
%% Returns numeric probabilities without requiring ProbLog inference.
%% Uses the highest-probability matching rule as a conservative estimate.

supply_disruption(Item, Ps) :-
    findall(P, supply_disruption_prob(Item, P), Probs),
    ( Probs = [] -> Ps = 0.0 ; max_list(Probs, Ps) ).

supply_disruption_prob(Item, 0.65) :-
    attribute(Item, import_dependent, true),
    attribute(world, weather, storm).
supply_disruption_prob(Item, 0.50) :-
    attribute(Item, import_dependent, true),
    attribute(world, trade_route_blocked, true).
supply_disruption_prob(Item, 0.25) :-
    attribute(Item, import_dependent, true),
    attribute(world, season, winter).
supply_disruption_prob(Item, 0.40) :-
    attribute(Item, perishable, true),
    attribute(world, weather, storm).
supply_disruption_prob(Item, 0.30) :-
    attribute(Item, perishable, true),
    attribute(world, season, summer).

demand_spike(Item, Pd) :-
    findall(P, demand_spike_prob(Item, P), Probs),
    ( Probs = [] -> Pd = 0.0 ; max_list(Probs, Pd) ).

demand_spike_prob(Item, 0.75) :-
    attribute(Item, category, healing),
    attribute(world, recent_conflict, true).
demand_spike_prob(Item, 0.55) :-
    attribute(Item, category, healing),
    attribute(world, threat_rising, true).
demand_spike_prob(Item, 0.45) :-
    attribute(Item, category, weapons),
    attribute(world, threat_rising, true).
demand_spike_prob(Item, 0.60) :-
    attribute(Item, category, weapons),
    attribute(world, recent_conflict, true).
demand_spike_prob(Item, 0.35) :-
    attribute(Item, category, food),
    attribute(world, season, winter).
demand_spike_prob(Item, 0.50) :-
    attribute(Item, category, tools),
    attribute(world, trade_route_blocked, true).

%% ── Market analysis predicates ────────────────────────────────────────────

market_volatility(Item, Ps, Pd) :-
    supply_disruption(Item, Ps),
    demand_spike(Item, Pd).

%% price_range(+Item, -Base, -Low, -High)
%% Low = base reduced by supply disruption pressure
%% High = base increased by demand spike pressure

price_range(Item, Base, Low, High) :-
    buy_price(Item, Base),
    supply_disruption(Item, Ps),
    demand_spike(Item, Pd),
    Low  is round(Base * (1.0 - Ps * 0.35)),
    High is round(Base * (1.0 + Pd * 0.55)).

%% expected_price(+Item, -Price)
%% Weighted expected price under current world conditions.

expected_price(Item, Price) :-
    buy_price(Item, Base),
    supply_disruption(Item, Ps),
    demand_spike(Item, Pd),
    Price is round(Base * (1.0 - Ps * 0.2 + Pd * 0.3)).
