%% Tether Module: prob-loot v1.0.0
%% Requires: loot-tables
%% Exports: drop_occurs/2, drop_probability/3, expected_drops/4

tether_module('prob-loot', '1.0.0', auto).

tether_export('prob-loot', 'drop_occurs/2',
    'drop_occurs(Source, Item) — probabilistic: Item drops from Source based on rarity tier').
tether_export('prob-loot', 'drop_probability/3',
    'drop_probability(Source, Item, P) — P is probability 0.0–1.0 that Item drops from Source').
tether_export('prob-loot', 'expected_drops/4',
    'expected_drops(Source, Item, N, Expected) — Expected number of Item drops from N kills of Source').

%% ── Probabilistic drop rules ───────────────────────────────────────────────
%% Install loot-tables in the same namespace first.
%% Rarity tiers map to default drop probabilities.
%% Override per-item with: { type:"attribute", entity:"sword", attribute:"drop_chance", value:15 }

0.90::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, common).
0.65::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, uncommon).
0.35::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, rare).
0.10::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, epic).
0.15::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, legendary).

%% Explicit drop_chance attribute overrides rarity-based probability.
%% Assert: { type:"attribute", entity:"boss_key", attribute:"drop_chance", value:25 }
drop_occurs(Source, Item) :-
    drops(Source, Item),
    attribute(Item, drop_chance, Pct),
    number(Pct), Pct >= 100.

%% ── Deterministic probability accessor ─────────────────────────────────────
%% Returns the stored base probability without running ProbLog inference.
%% Uses loot_chance/3 from loot-tables (0–100) normalised to 0.0–1.0.

drop_probability(Source, Item, P) :-
    loot_chance(Source, Item, Pct),
    P is Pct / 100.

%% ── Expected drops ─────────────────────────────────────────────────────────

expected_drops(Source, Item, N, Expected) :-
    drop_probability(Source, Item, P),
    Expected is N * P.
