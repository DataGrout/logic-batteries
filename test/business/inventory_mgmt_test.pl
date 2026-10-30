:- use_module(library(plunit)).

:- consult('../../modules/business/inventory_mgmt/inventory_mgmt').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_adequate_stock :-
    assertz(attribute(coffee_beans, stock,             80)),
    assertz(attribute(coffee_beans, reorder_threshold, 20)),
    assertz(attribute(coffee_beans, reorder_quantity,  100)),
    assertz(attribute(coffee_beans, max_stock,         200)),
    assertz(attribute(coffee_beans, daily_usage,        15)).

setup_low_stock :-
    assertz(attribute(coffee_beans, stock,             20)),
    assertz(attribute(coffee_beans, reorder_threshold, 20)),
    assertz(attribute(coffee_beans, reorder_quantity,  100)),
    assertz(attribute(coffee_beans, max_stock,         200)),
    assertz(attribute(coffee_beans, daily_usage,        15)).

setup_critical_stock :-
    assertz(attribute(coffee_beans, stock,             8)),
    assertz(attribute(coffee_beans, reorder_threshold, 20)),
    assertz(attribute(coffee_beans, critical_threshold, 10)),
    assertz(attribute(coffee_beans, reorder_quantity,  100)),
    assertz(attribute(coffee_beans, daily_usage,        15)).

setup_stockout :-
    assertz(attribute(coffee_beans, stock,             0)),
    assertz(attribute(coffee_beans, reorder_threshold, 20)).

setup_supplier_preferred :-
    assertz(relation(coffee_beans, supplied_by, acme_roasters)),
    assertz(attribute(acme_roasters, preferred, true)).

setup_supplier_only_one :-
    assertz(relation(coffee_beans, supplied_by, generic_supplier)).

setup_usage_known :-
    setup_adequate_stock.

setup_usage_unknown :-
    assertz(attribute(coffee_beans, stock, 80)).
    %% no daily_usage

setup_fills_to_max :-
    assertz(attribute(coffee_beans, stock,     50)),
    assertz(attribute(coffee_beans, max_stock, 200)).

%% ── stock_level/2 ────────────────────────────────────────────────────────────

:- begin_tests(inventory_stock_level).

test(adequate, [setup(setup_adequate_stock), cleanup(clear_facts)]) :-
    stock_level(coffee_beans, L), assertion(L == adequate).

test(low, [setup(setup_low_stock), cleanup(clear_facts)]) :-
    stock_level(coffee_beans, L), assertion(L == low).

test(critical, [setup(setup_critical_stock), cleanup(clear_facts)]) :-
    stock_level(coffee_beans, L), assertion(L == critical).

test(stockout, [setup(setup_stockout), cleanup(clear_facts)]) :-
    stock_level(coffee_beans, L), assertion(L == stockout).

:- end_tests(inventory_stock_level).

%% ── needs_reorder/1 ──────────────────────────────────────────────────────────

:- begin_tests(inventory_needs_reorder).

test(adequate_no_reorder, [setup(setup_adequate_stock), cleanup(clear_facts)]) :-
    assertion(\+ needs_reorder(coffee_beans)).

test(low_needs_reorder, [setup(setup_low_stock), cleanup(clear_facts)]) :-
    assertion(needs_reorder(coffee_beans)).

test(stockout_needs_reorder, [setup(setup_stockout), cleanup(clear_facts)]) :-
    assertion(needs_reorder(coffee_beans)).

:- end_tests(inventory_needs_reorder).

%% ── reorder_quantity/2 ───────────────────────────────────────────────────────

:- begin_tests(inventory_reorder_quantity).

test(quantity_from_attribute, [setup(setup_adequate_stock), cleanup(clear_facts)]) :-
    reorder_quantity(coffee_beans, Q), assertion(Q == 100).

test(quantity_fills_to_max, [setup(setup_fills_to_max), cleanup(clear_facts)]) :-
    reorder_quantity(coffee_beans, Q), assertion(Q == 150).

test(default_quantity, [cleanup(clear_facts)]) :-
    reorder_quantity(unknown_item, Q), assertion(Q == 50).

:- end_tests(inventory_reorder_quantity).

%% ── preferred_supplier/2 ─────────────────────────────────────────────────────

:- begin_tests(inventory_preferred_supplier).

test(preferred_supplier, [setup(setup_supplier_preferred), cleanup(clear_facts)]) :-
    preferred_supplier(coffee_beans, S), assertion(S == acme_roasters).

test(fallback_supplier, [setup(setup_supplier_only_one), cleanup(clear_facts)]) :-
    preferred_supplier(coffee_beans, S), assertion(S == generic_supplier).

:- end_tests(inventory_preferred_supplier).

%% ── days_of_stock/2 ──────────────────────────────────────────────────────────

:- begin_tests(inventory_days_of_stock).

test(days_computed, [setup(setup_usage_known), cleanup(clear_facts)]) :-
    %% 80 // 15 = 5
    days_of_stock(coffee_beans, D), assertion(D == 5).

test(unknown_when_no_usage, [setup(setup_usage_unknown), cleanup(clear_facts)]) :-
    days_of_stock(coffee_beans, D), assertion(D == unknown).

:- end_tests(inventory_days_of_stock).

%% ── Unbound Item: listers enumerate every item ───────────────────────────────

inv_setup_many_items :-
    assertz(attribute(beans_out,  stock, 0)),
    assertz(attribute(beans_out,  reorder_threshold, 20)),
    assertz(attribute(beans_crit, stock, 8)),
    assertz(attribute(beans_crit, reorder_threshold, 20)),
    assertz(attribute(beans_crit, critical_threshold, 10)),
    assertz(attribute(beans_low,  stock, 15)),
    assertz(attribute(beans_low,  reorder_threshold, 20)),
    assertz(attribute(beans_ok,   stock, 80)),
    assertz(attribute(beans_ok,   reorder_threshold, 20)).

inv_setup_decimal_stock :-
    assertz(attribute(milk, stock, 7.5)),
    assertz(attribute(milk, daily_usage, 2.5)),
    assertz(attribute(flour, stock, 80.5)),
    assertz(attribute(flour, daily_usage, 15)),
    assertz(attribute(sugar, stock, 10.3)),
    assertz(attribute(sugar, reorder_threshold, 21)),
    assertz(attribute(backorder, stock, -5)),
    assertz(attribute(backorder, daily_usage, 2)).

:- begin_tests(inventory_unbound_item).

test(stock_level_lists_every_item, [setup(inv_setup_many_items), cleanup(clear_facts)]) :-
    findall(I-L, stock_level(I, L), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [beans_crit-critical, beans_low-low,
                        beans_ok-adequate, beans_out-stockout]).

test(stock_level_filters_by_level, [setup(inv_setup_many_items), cleanup(clear_facts)]) :-
    findall(I, stock_level(I, low), Low),
    assertion(Low == [beans_low]),
    findall(I, stock_level(I, adequate), Ok),
    assertion(Ok == [beans_ok]).

test(stock_level_bound_level_is_the_computed_one, [setup(inv_setup_many_items), cleanup(clear_facts)]) :-
    %% critical is not also low, and a stockout is not adequate
    assertion(\+ stock_level(beans_crit, low)),
    assertion(\+ stock_level(beans_out, adequate)).

test(needs_reorder_lists_every_item, [setup(inv_setup_many_items), cleanup(clear_facts)]) :-
    findall(I, needs_reorder(I), Items0),
    msort(Items0, Items),
    assertion(Items == [beans_crit, beans_low, beans_out]).

:- end_tests(inventory_unbound_item).

:- begin_tests(inventory_decimal_stock).

test(days_of_stock_decimal_floors, [setup(inv_setup_decimal_stock), cleanup(clear_facts)]) :-
    days_of_stock(milk, D1), assertion(D1 == 3),
    days_of_stock(flour, D2), assertion(D2 == 5).

test(days_of_stock_negative_stock_is_zero, [setup(inv_setup_decimal_stock), cleanup(clear_facts)]) :-
    days_of_stock(backorder, D), assertion(D == 0).

test(critical_default_is_half_threshold, [setup(inv_setup_decimal_stock), cleanup(clear_facts)]) :-
    %% half of 21 is 10.5; 10.3 is at or below it
    stock_level(sugar, L), assertion(L == critical).

:- end_tests(inventory_decimal_stock).

%% ── Unbound Item: reorder_quantity, preferred_supplier, days_of_stock ────────

inv_setup_listers :-
    assertz(attribute(beans, stock, 20)),
    assertz(attribute(beans, reorder_quantity, 100)),
    assertz(attribute(beans, daily_usage, 5)),
    assertz(attribute(milk, stock, 50)),
    assertz(attribute(milk, max_stock, 200)),
    assertz(attribute(sugar, stock, 10)),
    assertz(relation(beans, supplied_by, generic_supplier)),
    assertz(relation(beans, supplied_by, acme_roasters)),
    assertz(attribute(acme_roasters, preferred, true)),
    assertz(relation(milk, supplied_by, dairy_co)).

:- begin_tests(inventory_unbound_listers).

test(reorder_quantity_lists_every_item, [setup(inv_setup_listers), cleanup(clear_facts)]) :-
    findall(I-Q, reorder_quantity(I, Q), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [beans-100, milk-150, sugar-50]).

test(reorder_quantity_bound_qty_is_the_computed_one, [setup(inv_setup_listers), cleanup(clear_facts)]) :-
    %% 50 is the default, not beans' configured quantity
    assertion(\+ reorder_quantity(beans, 50)).

test(preferred_supplier_lists_every_item, [setup(inv_setup_listers), cleanup(clear_facts)]) :-
    findall(I-S, preferred_supplier(I, S), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [beans-acme_roasters, milk-dairy_co]).

test(preferred_supplier_bound_supplier_is_the_preferred_one, [setup(inv_setup_listers), cleanup(clear_facts)]) :-
    assertion(\+ preferred_supplier(beans, generic_supplier)).

test(days_of_stock_lists_every_item, [setup(inv_setup_listers), cleanup(clear_facts)]) :-
    findall(I-D, days_of_stock(I, D), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [beans-4, milk-unknown, sugar-unknown]).

test(days_of_stock_bound_unknown_is_false_with_usage, [setup(inv_setup_listers), cleanup(clear_facts)]) :-
    assertion(\+ days_of_stock(beans, unknown)).

:- end_tests(inventory_unbound_listers).
