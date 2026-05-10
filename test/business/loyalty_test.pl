:- use_module(library(plunit)).

:- consult('../../modules/business/loyalty/loyalty').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_platinum_customer :-
    assertz(attribute(customer_123, lifetime_points, 6000)).

setup_gold_customer :-
    assertz(attribute(customer_123, lifetime_points, 2500)).

setup_silver_customer :-
    assertz(attribute(customer_123, lifetime_points, 800)).

setup_bronze_customer :-
    assertz(attribute(customer_123, lifetime_points, 100)).

setup_customer_with_redemptions :-
    assertz(attribute(customer_123, lifetime_points, 2500)),
    assertz(attribute(customer_123, redeemed_points, 500)).

setup_reward_coffee :-
    assertz(attribute(free_coffee, points_cost, 100)).

setup_reward_shipping :-
    assertz(attribute(free_shipping, points_cost, 200)).

setup_gold_with_enough_points :-
    setup_gold_customer,
    setup_reward_coffee.

setup_bronze_not_enough_for_shipping :-
    setup_bronze_customer,
    setup_reward_shipping.

setup_gold_benefit :-
    assertz(relation(gold, has_benefit, early_access)),
    assertz(attribute(early_access, benefit_value, true)).

setup_gold_customer_benefit :-
    setup_gold_customer,
    setup_gold_benefit.

setup_bronze_customer_with_gold_benefit :-
    setup_bronze_customer,
    setup_gold_benefit.

setup_platinum_with_gold_benefit :-
    setup_platinum_customer,
    assertz(relation(gold, has_benefit, early_access)),
    assertz(attribute(early_access, benefit_value, true)).

%% ── loyalty_tier/2 ───────────────────────────────────────────────────────────

:- begin_tests(loyalty_tier).

test(platinum, [setup(setup_platinum_customer), cleanup(clear_facts)]) :-
    loyalty_tier(customer_123, T), assertion(T == platinum).

test(gold, [setup(setup_gold_customer), cleanup(clear_facts)]) :-
    loyalty_tier(customer_123, T), assertion(T == gold).

test(silver, [setup(setup_silver_customer), cleanup(clear_facts)]) :-
    loyalty_tier(customer_123, T), assertion(T == silver).

test(bronze, [setup(setup_bronze_customer), cleanup(clear_facts)]) :-
    loyalty_tier(customer_123, T), assertion(T == bronze).

:- end_tests(loyalty_tier).

%% ── points_balance/2 ─────────────────────────────────────────────────────────

:- begin_tests(loyalty_balance).

test(balance_no_redemptions, [setup(setup_gold_customer), cleanup(clear_facts)]) :-
    points_balance(customer_123, B), assertion(B == 2500).

test(balance_with_redemptions, [setup(setup_customer_with_redemptions), cleanup(clear_facts)]) :-
    points_balance(customer_123, B), assertion(B == 2000).

:- end_tests(loyalty_balance).

%% ── points_to_redeem/3 ───────────────────────────────────────────────────────

:- begin_tests(loyalty_points_cost).

test(standard_cost_at_bronze, [setup((setup_bronze_customer, setup_reward_coffee)), cleanup(clear_facts)]) :-
    %% bronze multiplier = 1.0, ceiling(100 * 1.0) = 100
    points_to_redeem(customer_123, free_coffee, P), assertion(P == 100).

test(reduced_cost_at_gold, [setup((setup_gold_customer, setup_reward_coffee)), cleanup(clear_facts)]) :-
    %% gold multiplier = 0.85, ceiling(100 * 0.85) = 85
    points_to_redeem(customer_123, free_coffee, P), assertion(P == 85).

test(reduced_cost_at_platinum, [setup((setup_platinum_customer, setup_reward_coffee)), cleanup(clear_facts)]) :-
    %% platinum multiplier = 0.7, ceiling(100 * 0.7) = 70
    points_to_redeem(customer_123, free_coffee, P), assertion(P == 70).

:- end_tests(loyalty_points_cost).

%% ── reward_eligible/2 ────────────────────────────────────────────────────────

:- begin_tests(loyalty_eligible).

test(eligible_with_enough_points, [setup(setup_gold_with_enough_points), cleanup(clear_facts)]) :-
    assertion(reward_eligible(customer_123, free_coffee)).

test(not_eligible_insufficient_points, [setup(setup_bronze_not_enough_for_shipping), cleanup(clear_facts)]) :-
    assertion(\+ reward_eligible(customer_123, free_shipping)).

:- end_tests(loyalty_eligible).

%% ── tier_benefit/3 ───────────────────────────────────────────────────────────

:- begin_tests(loyalty_benefits).

test(gold_gets_own_benefit, [setup(setup_gold_customer_benefit), cleanup(clear_facts)]) :-
    assertion(tier_benefit(customer_123, early_access, true)).

test(platinum_inherits_gold_benefit, [setup(setup_platinum_with_gold_benefit), cleanup(clear_facts)]) :-
    assertion(tier_benefit(customer_123, early_access, true)).

test(bronze_no_gold_benefit, [setup(setup_bronze_customer_with_gold_benefit), cleanup(clear_facts)]) :-
    assertion(\+ tier_benefit(customer_123, early_access, _)).

:- end_tests(loyalty_benefits).
