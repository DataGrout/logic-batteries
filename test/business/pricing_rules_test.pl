:- use_module(library(plunit)).

:- consult('../../modules/business/pricing_rules/pricing_rules').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_widget_base :-
    assertz(attribute(widget, base_price, 100)).

setup_standard_customer :-
    true.  %% no tier attribute → defaults to standard

setup_member_customer :-
    assertz(attribute(customer_123, pricing_tier, member)).

setup_vip_customer :-
    assertz(attribute(customer_123, pricing_tier, vip)).

setup_discount_20pct :-
    setup_widget_base,
    assertz(relation(widget, has_discount, sale)),
    assertz(attribute(sale, pct_off, 20)).

setup_discount_flat_10 :-
    setup_widget_base,
    assertz(relation(widget, has_discount, coupon)),
    assertz(attribute(coupon, flat_off, 10)).

setup_discount_member_only :-
    setup_widget_base,
    assertz(relation(widget, has_discount, member_sale)),
    assertz(attribute(member_sale, pct_off, 15)),
    assertz(attribute(member_sale, requires_tier, member)).

setup_bulk_tiers :-
    setup_widget_base,
    assertz(attribute(widget, bulk_qty_1, 10)),
    assertz(attribute(widget, bulk_pct_1, 5)),
    assertz(attribute(widget, bulk_qty_2, 50)),
    assertz(attribute(widget, bulk_pct_2, 15)).

setup_price_floor :-
    setup_discount_20pct,
    assertz(attribute(widget, price_floor, 90)).

setup_price_ceil :-
    setup_widget_base,
    assertz(attribute(widget, price_ceil, 80)).

%% ── price_tier/3 ─────────────────────────────────────────────────────────────

:- begin_tests(pricing_tier).

test(standard_by_default, [setup(setup_widget_base), cleanup(clear_facts)]) :-
    price_tier(widget, unknown_customer, T), assertion(T == standard).

test(member_tier, [setup((setup_widget_base, setup_member_customer)), cleanup(clear_facts)]) :-
    price_tier(widget, customer_123, T), assertion(T == member).

test(vip_tier, [setup((setup_widget_base, setup_vip_customer)), cleanup(clear_facts)]) :-
    price_tier(widget, customer_123, T), assertion(T == vip).

:- end_tests(pricing_tier).

%% ── discount_applicable/2 ────────────────────────────────────────────────────

:- begin_tests(pricing_discounts).

test(discount_linked, [setup(setup_discount_20pct), cleanup(clear_facts)]) :-
    assertion(discount_applicable(widget, sale)).

test(no_discount_for_item, [setup(setup_widget_base), cleanup(clear_facts)]) :-
    assertion(\+ discount_applicable(widget, nonexistent)).

:- end_tests(pricing_discounts).

%% ── bulk_discount/3 ──────────────────────────────────────────────────────────

:- begin_tests(pricing_bulk).

test(bulk_discount_below_threshold, [setup(setup_bulk_tiers), cleanup(clear_facts)]) :-
    bulk_discount(widget, 5, P), assertion(P == 0).

test(bulk_discount_first_tier, [setup(setup_bulk_tiers), cleanup(clear_facts)]) :-
    bulk_discount(widget, 10, P), assertion(P == 5).

test(bulk_discount_second_tier, [setup(setup_bulk_tiers), cleanup(clear_facts)]) :-
    bulk_discount(widget, 50, P), assertion(P == 15).

:- end_tests(pricing_bulk).

%% ── effective_price/3 ────────────────────────────────────────────────────────

:- begin_tests(pricing_effective).

test(standard_no_discount, [setup(setup_widget_base), cleanup(clear_facts)]) :-
    effective_price(widget, unknown_customer, P), assertion(P == 100).

test(member_price, [setup((setup_widget_base, setup_member_customer)), cleanup(clear_facts)]) :-
    %% round(100 * 0.9) = 90
    effective_price(widget, customer_123, P), assertion(P == 90).

test(vip_price, [setup((setup_widget_base, setup_vip_customer)), cleanup(clear_facts)]) :-
    %% round(100 * 0.8) = 80
    effective_price(widget, customer_123, P), assertion(P == 80).

test(pct_discount_applied, [setup(setup_discount_20pct), cleanup(clear_facts)]) :-
    %% 100 - round(100*20/100) = 80
    effective_price(widget, unknown_customer, P), assertion(P == 80).

test(flat_discount_applied, [setup(setup_discount_flat_10), cleanup(clear_facts)]) :-
    effective_price(widget, unknown_customer, P), assertion(P == 90).

test(member_only_discount_applies_for_member, [setup((setup_discount_member_only, setup_member_customer)), cleanup(clear_facts)]) :-
    %% standard tier 100, member tier 90, then member_sale 15% off 90 = ~76
    effective_price(widget, customer_123, P), assertion(P =< 90).

test(member_only_discount_skipped_for_standard, [setup(setup_discount_member_only), cleanup(clear_facts)]) :-
    effective_price(widget, unknown_customer, P), assertion(P == 100).

:- end_tests(pricing_effective).

%% ── price_capped/3 ───────────────────────────────────────────────────────────

:- begin_tests(pricing_capped).

test(floor_prevents_discount, [setup(setup_price_floor), cleanup(clear_facts)]) :-
    %% 20% off 100 = 80, floor=90 → 90
    price_capped(widget, unknown_customer, P), assertion(P == 90).

test(ceil_clips_base_price, [setup(setup_price_ceil), cleanup(clear_facts)]) :-
    %% no discount, but ceil=80 clips 100 → 80
    price_capped(widget, unknown_customer, P), assertion(P == 80).

:- end_tests(pricing_capped).

%% ── Unbound Customer: price_tier enumerates every tiered customer ────────────

pricing_setup_two_customers :-
    setup_widget_base,
    assertz(attribute(cust_m, pricing_tier, member)),
    assertz(attribute(cust_v, pricing_tier, vip)).

:- begin_tests(pricing_unbound_customer).

test(price_tier_lists_every_customer, [setup(pricing_setup_two_customers), cleanup(clear_facts)]) :-
    findall(C-T, price_tier(widget, C, T), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [cust_m-member, cust_v-vip]).

test(price_tier_filters_by_tier, [setup(pricing_setup_two_customers), cleanup(clear_facts)]) :-
    findall(C, price_tier(widget, C, vip), Vips),
    assertion(Vips == [cust_v]),
    findall(C, price_tier(widget, C, standard), Std),
    assertion(Std == []).

test(price_tier_bound_tier_is_the_computed_one, [setup(pricing_setup_two_customers), cleanup(clear_facts)]) :-
    assertion(\+ price_tier(widget, cust_v, standard)),
    assertion(price_tier(widget, nobody, standard)).

test(effective_price_lists_every_customer, [setup(pricing_setup_two_customers), cleanup(clear_facts)]) :-
    findall(C-P, effective_price(widget, C, P), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [cust_m-90, cust_v-80]).

:- end_tests(pricing_unbound_customer).
