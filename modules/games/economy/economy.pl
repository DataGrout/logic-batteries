%% Battery: economy v1.0.0
%% Exports: can_craft/2, craft_cost/2, buy_price/2, sell_price/2, missing_materials/3

battery_module(economy, '1.0.1', auto).

battery_export(economy, 'can_craft/2',          'can_craft(Player, Item) — Player has all materials to craft Item').
battery_export(economy, 'craft_cost/2',         'craft_cost(Item, Cost) — Cost is the total gold value of materials to craft Item').
battery_export(economy, 'buy_price/2',          'buy_price(Item, Price) — Price to buy Item from a vendor').
battery_export(economy, 'sell_price/2',         'sell_price(Item, Price) — Price a vendor pays for Item').
battery_export(economy, 'missing_materials/3',  'missing_materials(Player, Item, Missing) — Missing is a list of {material, need, have} maps for shortfalls').

%% Input contract (CONTRIBUTING, "Input contract"). Quantities are
%% <material>_qty attributes, whose names vary with the material, so they
%% cannot be listed here: on an item it is how many of that material the
%% recipe needs (default 1), on a player how many it holds (when absent, one
%% per has_material fact).
battery_input(economy, item, attribute(base_price), number, key,
    'Vendor price before supply and demand; an item without one has no buy or sell price.').
battery_input(economy, item, relation(requires), ref(item), key,
    'A material in the item''s recipe; quantity in <material>_qty, default 1.').
battery_input(economy, item, attribute(supply_factor), number, default(1.0),
    'Multiplier on base_price for supply; below 1 when the item is abundant.').
battery_input(economy, item, attribute(demand_factor), number, default(1.0),
    'Multiplier on base_price for demand; above 1 when the item is sought after.').
battery_input(economy, item, attribute(recipe_gold_cost), number, optional,
    'A flat craft cost that replaces the sum of the material prices.').
battery_input(economy, player, relation(has_material), ref(item), key,
    'One unit of a material the player holds; a <material>_qty attribute on the player overrides the count.').
battery_input(economy, fixed(economy), attribute(sell_ratio), number, default(0.5),
    'Fraction of the buy price a vendor pays.').

%% ── Crafting Recipes ─────────────────────────────────────────────────────────
%%
%% Assert one relation per ingredient:
%%   relation(iron_sword, requires, iron_ingot)
%%   attribute(iron_sword, iron_ingot_qty, 3)   %% quantity required (default: 1)
%%
%% Or a flat recipe cost (bypasses individual ingredients):
%%   attribute(iron_sword, recipe_gold_cost, 50)

recipe_ingredient(Item, Material, Qty) :-
    relation(Item, requires, Material),
    ( attribute(Item, Attr, Qty),
      atom_concat(Material, '_qty', Attr) -> true ; Qty = 1 ).

%% can_craft(+Player, +Item): Player holds sufficient quantities of all materials
can_craft(Player, Item) :-
    relation(Item, requires, _),   %% at least one ingredient exists
    \+ (
        recipe_ingredient(Item, Material, Need),
        player_material_count(Player, Material, Have),
        Have < Need
    ).

%% Quantity held: a `<material>_qty` attribute on the player when present —
%% the same suffix a recipe uses for quantity needed — otherwise one unit per
%% has_material relation fact. The attribute is the reliable form: counting
%% relation facts depends on the store keeping duplicates.
player_material_count(Player, Material, Count) :-
    atom_concat(Material, '_qty', QtyAttr),
    attribute(Player, QtyAttr, Count), !.
player_material_count(Player, Material, Count) :-
    findall(_, relation(Player, has_material, Material), Xs),
    length(Xs, Count).

%% missing_materials(+Player, +Item, -Missing)
%% Missing is a list of material-need-have triples for shortfalls only.
missing_materials(Player, Item, Missing) :-
    findall(
        material(Material, Need, Have),
        ( recipe_ingredient(Item, Material, Need),
          player_material_count(Player, Material, Have),
          Have < Need ),
        Missing ).

%% craft_cost(+Item, -Cost): total gold value of all recipe ingredients
craft_cost(Item, Cost) :-
    attribute(Item, recipe_gold_cost, Cost), !.
craft_cost(Item, Cost) :-
    findall(LineTotal,
        ( recipe_ingredient(Item, Material, Qty),
          buy_price(Material, UnitPrice),
          LineTotal is Qty * UnitPrice ),
        LineTotals),
    sumlist(LineTotals, Cost).

%% ── Pricing ──────────────────────────────────────────────────────────────────
%%
%% Base prices:
%%   attribute(iron_sword, base_price, 100)
%%
%% Supply/demand modifier (default 1.0 = neutral):
%%   attribute(iron_sword, supply_factor, 0.8)   %% abundant → cheaper to buy
%%   attribute(iron_sword, demand_factor, 1.5)   %% high demand → pricier
%%
%% Sell ratio (fraction of buy price, default 0.5):
%%   attribute(economy, sell_ratio, 0.6)

buy_price(Item, Price) :-
    attribute(Item, base_price, Base),
    ( attribute(Item, supply_factor, Supply) -> true ; Supply = 1.0 ),
    ( attribute(Item, demand_factor, Demand) -> true ; Demand = 1.0 ),
    Price is round(Base * Supply * Demand).

sell_price(Item, Price) :-
    buy_price(Item, BuyP),
    ( attribute(economy, sell_ratio, Ratio) -> true ; Ratio = 0.5 ),
    Price is round(BuyP * Ratio).
