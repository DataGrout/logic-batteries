%% Battery: prob-loot v1.0.1
%% Requires: loot-tables
%% Exports: drop_occurs/2, guaranteed_drop/2, drop_probability/3, expected_drops/4

battery_module('prob-loot', '1.0.1', auto).

battery_export('prob-loot', 'drop_occurs/2',
    'drop_occurs(Source, Item) — probabilistic: Item drops from Source based on rarity tier').
battery_export('prob-loot', 'guaranteed_drop/2',
    'guaranteed_drop(Source, Item) — deterministic: Item is guaranteed to drop (drop_chance attribute >= 100)').
battery_export('prob-loot', 'drop_probability/3',
    'drop_probability(Source, Item, P) — P is probability 0.0–1.0 that Item drops from Source').
battery_export('prob-loot', 'expected_drops/4',
    'expected_drops(Source, Item, N, Expected) — Expected number of Item drops from N kills of Source').

%% ── Probabilistic drop rules ───────────────────────────────────────────────
%% Install loot-tables in the same namespace first.
%% Rarity tiers map to default drop probabilities. ProbLog interprets each
%% annotated clause as an independent probabilistic event; results combine
%% via noisy-OR across clauses whose bodies succeed for the same (Source, Item).
%%
%% Note: prior versions co-located an unannotated guaranteed-drop clause here.
%% ProbLog treated the unannotated clause as P=1.0 with unreliable body
%% evaluation, inflating noisy-OR results (e.g., 0.915 instead of 0.15 for a
%% legendary item). The guaranteed-drop logic now lives in guaranteed_drop/2
%% below so drop_occurs/2 is purely probabilistic.

0.90::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, common).
0.65::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, uncommon).
0.35::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, rare).
0.10::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, epic).
0.15::drop_occurs(Source, Item) :- drops(Source, Item), rarity_tier(Item, legendary).

%% ── Guaranteed drops (deterministic, separate from ProbLog inference) ──────
%% Items with drop_chance >= 100 always drop. Query as a regular predicate;
%% does not interfere with probability(drop_occurs(...), P).
%% Assert: { type:"attribute", entity:"boss_key", attribute:"drop_chance", value:100 }

guaranteed_drop(Source, Item) :-
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
