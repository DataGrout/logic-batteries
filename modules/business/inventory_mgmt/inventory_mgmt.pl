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

%% stock_level(+Item, -Level)
stock_level(Item, stockout) :-
    attribute(Item, stock, S), S =< 0, !.
stock_level(Item, critical) :-
    attribute(Item, stock, S),
    ( attribute(Item, critical_threshold, T)
      -> true
      ; ( attribute(Item, reorder_threshold, R) -> T is R // 2 ; T = 5 ) ),
    S =< T, !.
stock_level(Item, low) :-
    attribute(Item, stock, S),
    attribute(Item, reorder_threshold, T),
    S =< T, !.
stock_level(_, adequate).

%% needs_reorder(+Item)
needs_reorder(Item) :-
    stock_level(Item, Level),
    member(Level, [stockout, critical, low]).

%% reorder_quantity(+Item, -Qty)
reorder_quantity(Item, Qty) :-
    attribute(Item, reorder_quantity, Qty), !.
reorder_quantity(Item, Qty) :-
    attribute(Item, max_stock, Max),
    attribute(Item, stock, Current),
    Qty is Max - Current, !.
reorder_quantity(_, 50).

%% preferred_supplier(+Item, -Supplier)
preferred_supplier(Item, Supplier) :-
    relation(Item, supplied_by, Supplier),
    attribute(Supplier, preferred, true), !.
preferred_supplier(Item, Supplier) :-
    relation(Item, supplied_by, Supplier), !.

%% days_of_stock(+Item, -Days)
days_of_stock(Item, Days) :-
    attribute(Item, stock, Stock),
    attribute(Item, daily_usage, Usage),
    Usage > 0,
    Days is Stock // Usage, !.
days_of_stock(_, unknown).
