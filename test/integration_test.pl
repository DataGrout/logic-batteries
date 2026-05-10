%% Cross-module integration tests.
%% Proves that batteries interoperate through shared attribute/relation facts.

:- use_module(library(plunit)).

:- consult('../modules/games/world/world').
:- consult('../modules/games/loot-tables/loot_tables').
:- consult('../modules/games/progression/progression').
:- consult('../modules/games/combat/combat').
:- consult('../modules/games/quests/quests').
:- consult('../modules/games/npc-state/npc_state').
:- consult('../modules/games/faction/faction').
:- consult('../modules/games/dialogue/dialogue').
:- consult('../modules/games/inventory/inventory').
:- consult('../modules/games/economy/economy').
:- consult('../modules/business/lead_scoring/lead_scoring').
:- consult('../modules/business/approval_chains/approval_chains').
:- consult('../modules/business/invoice_rules/invoice_rules').
:- consult('../modules/business/compliance/compliance').
:- consult('../modules/business/inventory_mgmt/inventory_mgmt').
:- consult('../modules/business/loyalty/loyalty').

%% ─────────────────────────────────────────────────────────────────────────────
%% world + loot_tables: night drops only spawn at night
%% ─────────────────────────────────────────────────────────────────────────────

setup_night_loot :-
    assertz(attribute(world, time_of_day, night)),
    assertz(relation(shadow_chest, has_drop,  shadow_gem)),
    assertz(attribute(shadow_gem, drop_weight, 10)),
    assertz(attribute(shadow_gem, requires_condition, night)).

:- begin_tests(integration_world_loot).

test(night_condition_satisfied, [setup(setup_night_loot), cleanup(clear_facts)]) :-
    %% is_nighttime succeeds, so condition would gate the drop
    assertion(is_nighttime),
    world_time(T), assertion(T == night).

:- end_tests(integration_world_loot).

%% ─────────────────────────────────────────────────────────────────────────────
%% progression + combat: level gates damage eligibility
%% ─────────────────────────────────────────────────────────────────────────────

setup_alice_level_10_combat :-
    assertz(attribute(alice, level, 10)),
    assertz(attribute(alice, base_damage, 30)),
    assertz(attribute(boss, resistance, fire, 50)).

:- begin_tests(integration_progression_combat).

test(level_and_damage_independent_facts, [setup(setup_alice_level_10_combat), cleanup(clear_facts)]) :-
    attribute(alice, level, L), assertion(L == 10),
    attribute(alice, base_damage, D), assertion(D == 30).

:- end_tests(integration_progression_combat).

%% ─────────────────────────────────────────────────────────────────────────────
%% quests + npc_state: quest completion unlocks NPC dialogue
%% ─────────────────────────────────────────────────────────────────────────────

setup_quest_unlock_npc :-
    %% Quest in progress for alice (state key = alice_find_artifact)
    assertz(attribute(alice_find_artifact, status, in_progress)),
    %% Quest objective definition
    assertz(attribute(collect_gem, quest,  find_artifact)),
    assertz(attribute(collect_gem, order,  1)),
    %% Objective complete (state key = alice_collect_gem)
    assertz(attribute(alice_collect_gem, complete, true)),
    %% NPC: merchant dialogue gated on quest completion
    assertz(attribute(secret_deal, line, "I heard you found the gem.")),
    assertz(attribute(secret_deal, requires_quest, find_artifact)).

:- begin_tests(integration_quests_npc).

test(quest_objective_state_marked_complete, [setup(setup_quest_unlock_npc), cleanup(clear_facts)]) :-
    %% objective_complete uses quest_state_key(Player, Obj, Key)
    assertion(can_turn_in(alice, find_artifact)).

test(quest_completion_enables_npc_topic, [setup(setup_quest_unlock_npc), cleanup(clear_facts)]) :-
    assertion(can_turn_in(alice, find_artifact)),
    attribute(secret_deal, requires_quest, Q),
    assertion(Q == find_artifact).

:- end_tests(integration_quests_npc).

%% ─────────────────────────────────────────────────────────────────────────────
%% faction + npc_state: faction standing affects NPC relationship
%% ─────────────────────────────────────────────────────────────────────────────

setup_faction_npc_bridge :-
    %% alice is friendly with traders guild
    assertz(attribute(alice_traders_guild, score, 5000)),
    %% merchant NPC belongs to traders guild
    assertz(attribute(merchant_bob, faction, traders_guild)),
    %% relationship mirrors faction standing
    assertz(attribute(alice_merchant_bob, affinity, 50)).

:- begin_tests(integration_faction_npc).

test(faction_standing_computed, [setup(setup_faction_npc_bridge), cleanup(clear_facts)]) :-
    faction_standing(alice, traders_guild, S),
    assertion(S == friendly).

test(npc_affinity_independent_of_faction, [setup(setup_faction_npc_bridge), cleanup(clear_facts)]) :-
    %% both facts coexist for same player
    faction_reputation(alice, traders_guild, R), assertion(R == 5000),
    attribute(alice_merchant_bob, affinity, A), assertion(A == 50).

:- end_tests(integration_faction_npc).

%% ─────────────────────────────────────────────────────────────────────────────
%% inventory + economy: held items have buy/sell prices
%% ─────────────────────────────────────────────────────────────────────────────

setup_inventory_economy :-
    assertz(attribute(iron_sword, base_price, 100)),
    assertz(attribute(alice, slot_1, iron_sword)),
    assertz(relation(alice, equip_slot, slot_1)).

:- begin_tests(integration_inventory_economy).

test(held_item_has_price, [setup(setup_inventory_economy), cleanup(clear_facts)]) :-
    attribute(alice, slot_1, Item),
    buy_price(Item, P),
    assertion(P == 100).

test(sell_price_less_than_buy, [setup(setup_inventory_economy), cleanup(clear_facts)]) :-
    attribute(alice, slot_1, Item),
    buy_price(Item, Buy),
    sell_price(Item, Sell),
    assertion(Sell < Buy).

:- end_tests(integration_inventory_economy).

%% ─────────────────────────────────────────────────────────────────────────────
%% lead_scoring + approval_chains: hot leads trigger high-value approval
%% ─────────────────────────────────────────────────────────────────────────────

setup_hot_lead_approval :-
    %% Hot lead: enterprise, budget confirmed, decision maker
    assertz(attribute(lead_001, company_size, enterprise)),
    assertz(attribute(lead_001, budget_confirmed, true)),
    assertz(attribute(lead_001, decision_maker, true)),
    %% Approval chain for the deal request
    assertz(attribute(deal_req_step1, request,  deal_req_001)),
    assertz(attribute(deal_req_step1, approver, sales_manager)),
    assertz(attribute(deal_req_step1, step,     1)).

:- begin_tests(integration_lead_approval).

test(hot_lead_scored, [setup(setup_hot_lead_approval), cleanup(clear_facts)]) :-
    lead_score(lead_001, S),
    assertion(S >= 70),
    lead_tier(lead_001, T), assertion(T == hot).

test(approval_required_for_deal, [setup(setup_hot_lead_approval), cleanup(clear_facts)]) :-
    assertion(approval_required(deal_req_001, sales_manager)).

test(hot_lead_qualified_and_approval_pending, [setup(setup_hot_lead_approval), cleanup(clear_facts)]) :-
    assertion(lead_qualified(lead_001)),
    assertion(\+ fully_approved(deal_req_001)).

:- end_tests(integration_lead_approval).

%% ─────────────────────────────────────────────────────────────────────────────
%% invoice_rules + compliance: overdue invoices may violate retention policy
%% ─────────────────────────────────────────────────────────────────────────────

setup_overdue_compliance :-
    %% Today: April 25
    assertz(attribute(today, year,  2026)),
    assertz(attribute(today, month, 4)),
    assertz(attribute(today, day,   25)),
    assertz(attribute(today, date,  20260425)),
    %% Overdue invoice
    assertz(attribute(inv_001, amount,    1500)),
    assertz(attribute(inv_001, due_year,  2026)),
    assertz(attribute(inv_001, due_month, 3)),
    assertz(attribute(inv_001, due_day,   10)),
    assertz(attribute(inv_001, paid,      false)),
    %% Compliance policy requires payment_verified
    assertz(relation(ar_policy, requires, payment_verified)).

:- begin_tests(integration_invoice_compliance).

test(overdue_invoice_detected, [setup(setup_overdue_compliance), cleanup(clear_facts)]) :-
    assertion(invoice_overdue(inv_001)).

test(invoice_escalation_level, [setup(setup_overdue_compliance), cleanup(clear_facts)]) :-
    escalation_level(inv_001, L),
    assertion(member(L, [reminder, warning, collections])).

test(entity_not_compliant_without_payment_verified, [setup(setup_overdue_compliance), cleanup(clear_facts)]) :-
    assertion(\+ compliant(inv_001, ar_policy)).

:- end_tests(integration_invoice_compliance).

%% ─────────────────────────────────────────────────────────────────────────────
%% inventory_mgmt + loyalty: loyal customers get restocking priority notice
%% ─────────────────────────────────────────────────────────────────────────────

setup_stock_and_loyalty :-
    %% Coffee beans need reorder
    assertz(attribute(coffee_beans, stock,             15)),
    assertz(attribute(coffee_beans, reorder_threshold, 20)),
    assertz(attribute(coffee_beans, daily_usage,       5)),
    %% Customer is gold tier
    assertz(attribute(customer_123, lifetime_points, 3000)).

:- begin_tests(integration_inventory_loyalty).

test(low_stock_needs_reorder, [setup(setup_stock_and_loyalty), cleanup(clear_facts)]) :-
    assertion(needs_reorder(coffee_beans)).

test(gold_customer_gets_tier, [setup(setup_stock_and_loyalty), cleanup(clear_facts)]) :-
    loyalty_tier(customer_123, T), assertion(T == gold).

test(days_of_stock_computable, [setup(setup_stock_and_loyalty), cleanup(clear_facts)]) :-
    days_of_stock(coffee_beans, D),
    assertion(D == 3).

:- end_tests(integration_inventory_loyalty).
