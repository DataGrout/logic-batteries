%% Tether Module: loot-tables v1.0.0
%% Exports: drops/2, drops_at/3, eligible_loot/2, rarity_tier/2,
%%          condition_met/2, loot_chance/3

tether_module('loot-tables', '1.0.0', auto).

tether_export('loot-tables', 'drops/2',          'drops(Source, Item) — Item can drop from Source under any conditions').
tether_export('loot-tables', 'drops_at/3',        'drops_at(Source, Item, Conditions) — Item drops from Source when Conditions are met').
tether_export('loot-tables', 'eligible_loot/2',   'eligible_loot(Source, Item) — Item is eligible to drop right now given current world state').
tether_export('loot-tables', 'rarity_tier/2',     'rarity_tier(Item, Tier) — Tier is common/uncommon/rare/epic/legendary').
tether_export('loot-tables', 'condition_met/2',   'condition_met(Condition, Context) — Condition is satisfied in Context').
tether_export('loot-tables', 'loot_chance/3',     'loot_chance(Source, Item, Pct) — Pct is drop chance 0-100').

%% ── Rarity tiers ─────────────────────────────────────────────────────────────
%% Set by asserting: { type:"attribute", entity:"rare_gem", attribute:"rarity", value:"rare" }

rarity_tier(Item, Tier) :-
    attribute(Item, rarity, Tier), !.
rarity_tier(_, common).

%% ── Condition evaluation ─────────────────────────────────────────────────────
%% Conditions are facts asserted into the world namespace:
%%   { type:"attribute", entity:"world", attribute:"time_of_day", value:"night" }
%%   { type:"attribute", entity:"world", attribute:"weather", value:"rain" }
%%   { type:"attribute", entity:"world", attribute:"moon_phase", value:"full" }

condition_met(time(T), _) :-
    attribute(world, time_of_day, T).
condition_met(weather(W), _) :-
    attribute(world, weather, W).
condition_met(moon(M), _) :-
    attribute(world, moon_phase, M).
condition_met(player_level_gte(L), Context) :-
    attribute(Context, level, PlayerL),
    PlayerL >= L.
condition_met(player_has(Item), Context) :-
    relation(Context, has_item, Item).
condition_met(always, _).

%% All conditions in a list must be met
all_conditions_met([], _).
all_conditions_met([C|Rest], Context) :-
    condition_met(C, Context),
    all_conditions_met(Rest, Context).

%% ── Drop table ───────────────────────────────────────────────────────────────
%% Assert loot entries:
%%   { type:"relation", subject:"cave_chest", relation:"can_drop", object:"gold_coin" }
%%
%% Conditional drops use a loot_condition fact:
%%   { type:"attribute", entity:"rare_fish", attribute:"loot_conditions",
%%     value:"[time(night), weather(rain)]" }

drops(Source, Item) :-
    relation(Source, can_drop, Item).

drops_at(Source, Item, Conditions) :-
    drops(Source, Item),
    attribute(Item, loot_conditions, Conditions).

%% eligible_loot/2 — items that can drop right now
eligible_loot(Source, Item) :-
    drops(Source, Item),
    (   attribute(Item, loot_conditions, Conditions)
    ->  all_conditions_met(Conditions, world)
    ;   true   %% no conditions = always eligible
    ).

%% loot_chance/3 — drop chance by rarity tier
loot_chance(_, Item, Chance) :-
    attribute(Item, drop_chance, Chance), !.
loot_chance(_, Item, Chance) :-
    rarity_tier(Item, Tier),
    tier_chance(Tier, Chance).

tier_chance(common,    70).
tier_chance(uncommon,  30).
tier_chance(rare,      10).
tier_chance(epic,       3).
tier_chance(legendary,  1).
