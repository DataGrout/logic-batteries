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
