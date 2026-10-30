%% Battery: inventory_mgmt v1.0.0
%% Exports: needs_reorder/1, reorder_quantity/2, stock_level/2,
%%          preferred_supplier/2, days_of_stock/2

battery_module(inventory_mgmt, '1.0.0', auto).

battery_export(inventory_mgmt, 'needs_reorder/1',     'needs_reorder(Item) — Item is at or below its reorder threshold').
battery_export(inventory_mgmt, 'reorder_quantity/2',  'reorder_quantity(Item, Qty) — Qty is the recommended order quantity').
battery_export(inventory_mgmt, 'stock_level/2',       'stock_level(Item, Level) — Level is adequate/low/critical/stockout').
battery_export(inventory_mgmt, 'preferred_supplier/2','preferred_supplier(Item, Supplier) — Supplier is the preferred source for Item').
battery_export(inventory_mgmt, 'days_of_stock/2',     'days_of_stock(Item, Days) — estimated days until Item runs out at current usage rate').

%% ── Inventory Management Data Model ──────────────────────────────────────────
%%
%% Stock levels:
%%   attribute(coffee_beans, stock,             80)     %% current units
%%   attribute(coffee_beans, reorder_threshold, 20)     %% reorder when at/below this
%%   attribute(coffee_beans, reorder_quantity,  100)    %% default order size
%%   attribute(coffee_beans, max_stock,         200)    %% shelf capacity
%%   attribute(coffee_beans, daily_usage,       15)     %% units consumed per day
%%
%% Stockout override:
%%   attribute(coffee_beans, stock, 0)
%%
%% Suppliers:
%%   relation(coffee_beans, supplied_by, acme_roasters)
%%   attribute(acme_roasters, preferred, true)
%%   attribute(acme_roasters, lead_time_days, 3)
%%
%% Critical threshold (default: half of reorder_threshold):
%%   attribute(coffee_beans, critical_threshold, 10)

%% stock_level(?Item, ?Level)
%% Unbound, Item ranges over every item with a `stock` fact. The first matching
%% tier wins per item, and Level is computed before it is compared, so a bound
%% Level asks "is this the item's level" (critical is not also low).
stock_level(Item, Level) :-
    ( var(Item) -> inventory_stocked_item(Item) ; true ),
    inventory_stock_level(Item, Level0),
    Level = Level0.

inventory_stocked_item(Item) :-
    setof(I, S^attribute(I, stock, S), Items),
    member(Item, Items).

%% Default critical threshold is half the reorder threshold (`/`, not `//`, so
%% a decimal threshold works; for whole-number stock the two agree).
inventory_stock_level(Item, stockout) :-
    attribute(Item, stock, S), S =< 0, !.
inventory_stock_level(Item, critical) :-
    attribute(Item, stock, S),
    ( attribute(Item, critical_threshold, T)
      -> true
      ; ( attribute(Item, reorder_threshold, R) -> T is R / 2 ; T = 5 ) ),
    S =< T, !.
inventory_stock_level(Item, low) :-
    attribute(Item, stock, S),
    attribute(Item, reorder_threshold, T),
    S =< T, !.
inventory_stock_level(_, adequate).

%% needs_reorder(?Item)
needs_reorder(Item) :-
    stock_level(Item, Level),
    member(Level, [stockout, critical, low]).

%% reorder_quantity(?Item, ?Qty)
%% Unbound, Item ranges over every item with a `stock` fact. The first source
%% wins per item and Qty is computed before it is compared.
reorder_quantity(Item, Qty) :-
    ( var(Item) -> inventory_stocked_item(Item) ; true ),
    inventory_reorder_quantity(Item, Qty0),
    Qty = Qty0.

inventory_reorder_quantity(Item, Qty) :-
    attribute(Item, reorder_quantity, Qty), !.
inventory_reorder_quantity(Item, Qty) :-
    attribute(Item, max_stock, Max),
    attribute(Item, stock, Current),
    Qty is Max - Current, !.
inventory_reorder_quantity(_, 50).

%% preferred_supplier(?Item, ?Supplier)
%% Unbound, Item ranges over every item with a `supplied_by` relation. One
%% supplier per item, a preferred one first; a bound Supplier asks whether it is
%% that one.
preferred_supplier(Item, Supplier) :-
    ( var(Item) -> inventory_supplied_item(Item) ; true ),
    inventory_preferred_supplier(Item, Supplier0),
    Supplier = Supplier0.

inventory_supplied_item(Item) :-
    setof(I, S^relation(I, supplied_by, S), Items),
    member(Item, Items).

inventory_preferred_supplier(Item, Supplier) :-
    relation(Item, supplied_by, Supplier),
    attribute(Supplier, preferred, true), !.
inventory_preferred_supplier(Item, Supplier) :-
    relation(Item, supplied_by, Supplier), !.

%% days_of_stock(?Item, ?Days)
%% Days is a whole number, rounded down: floor(stock / daily_usage), never below
%% 0. Stock and usage may be decimals (QuickBooks QtyOnHand often is).
%% Unbound, Item ranges over every item with a `stock` fact; Days is computed
%% before it is compared, so a bound `unknown` is false for an item with usage.
days_of_stock(Item, Days) :-
    ( var(Item) -> inventory_stocked_item(Item) ; true ),
    inventory_days_of_stock(Item, Days0),
    Days = Days0.

inventory_days_of_stock(Item, Days) :-
    attribute(Item, stock, Stock),
    attribute(Item, daily_usage, Usage),
    Usage > 0,
    Days is max(0, floor(Stock / Usage)), !.
inventory_days_of_stock(_, unknown).
