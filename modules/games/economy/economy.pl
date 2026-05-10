%% Tether Module: economy v1.0.0
%% Exports: can_craft/2, craft_cost/2, buy_price/2, sell_price/2, missing_materials/3

tether_module(economy, '1.0.0', auto).

tether_export(economy, 'can_craft/2',          'can_craft(Player, Item) — Player has all materials to craft Item').
tether_export(economy, 'craft_cost/2',         'craft_cost(Item, Cost) — Cost is the total gold value of materials to craft Item').
tether_export(economy, 'buy_price/2',          'buy_price(Item, Price) — Price to buy Item from a vendor').
tether_export(economy, 'sell_price/2',         'sell_price(Item, Price) — Price a vendor pays for Item').
tether_export(economy, 'missing_materials/3',  'missing_materials(Player, Item, Missing) — Missing is a list of {material, need, have} maps for shortfalls').

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
