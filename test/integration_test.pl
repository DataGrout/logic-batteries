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
:- consult('../modules/reasoning/taxonomy/taxonomy').
:- consult('../modules/reasoning/temporal/temporal').
:- consult('../modules/probabilistic/prob-loot/prob_loot').
:- consult('../modules/probabilistic/prob-detection/prob_detection').
:- consult('../modules/probabilistic/prob-economy/prob_economy').

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

%% ─────────────────────────────────────────────────────────────────────────────
%% taxonomy + temporal: class hierarchy with timed events
%% A creature's faction membership is inherited from its parent class.
%% Temporal reasoning confirms events occurred during the creature's active period.
%% ─────────────────────────────────────────────────────────────────────────────

setup_creature_events :-
    %% Taxonomy: wolf → beast → creature
    assertz(relation(wolf,    is_a, beast)),
    assertz(relation(beast,   is_a, creature)),
    assertz(attribute(beast,  faction, wilds)),
    assertz(attribute(creature, sentient, false)),
    %% Temporal: wolf_encounter happened before the safe_window closes
    assertz(attribute(wolf_encounter, timestamp, 1200)),
    assertz(attribute(safe_window_open,  timestamp, 1000)),
    assertz(attribute(safe_window_close, timestamp, 2000)).

:- begin_tests(integration_taxonomy_temporal).

test(wolf_inherits_faction_from_beast, [setup(setup_creature_events), cleanup(clear_facts)]) :-
    assertion(inherits_property(wolf, faction, wilds)).

test(wolf_inherits_non_sentient, [setup(setup_creature_events), cleanup(clear_facts)]) :-
    assertion(inherits_property(wolf, sentient, false)).

test(encounter_within_safe_window, [setup(setup_creature_events), cleanup(clear_facts)]) :-
    assertion(event_within(wolf_encounter, 1000, 2000)).

test(encounter_after_window_open, [setup(setup_creature_events), cleanup(clear_facts)]) :-
    assertion(event_after(wolf_encounter, safe_window_open)).

test(encounter_before_window_close, [setup(setup_creature_events), cleanup(clear_facts)]) :-
    assertion(event_before(wolf_encounter, safe_window_close)).

:- end_tests(integration_taxonomy_temporal).

%% ─────────────────────────────────────────────────────────────────────────────
%% loot-tables + prob-loot: drop probability tracks rarity tier
%% Validates that drop_probability/3 correctly reads loot_chance via rarity_tier.
%% ─────────────────────────────────────────────────────────────────────────────

setup_boss_loot :-
    assertz(relation(dragon, can_drop, gold_ingot)),
    assertz(attribute(gold_ingot, rarity, rare)),
    assertz(relation(dragon, can_drop, dragon_heart)),
    assertz(attribute(dragon_heart, rarity, legendary)),
    assertz(relation(goblin, can_drop, copper_coin)),
    assertz(attribute(copper_coin, rarity, common)).

:- begin_tests(integration_loot_probability).

test(rare_item_drop_probability, [setup(setup_boss_loot), cleanup(clear_facts)]) :-
    drop_probability(dragon, gold_ingot, P),
    assertion(P =:= 0.10).       %% rare tier: loot_chance = 10 → 10/100

test(legendary_item_drop_probability, [setup(setup_boss_loot), cleanup(clear_facts)]) :-
    drop_probability(dragon, dragon_heart, P),
    assertion(P =:= 0.01).       %% legendary tier: loot_chance = 1 → 1/100

test(common_item_drop_probability, [setup(setup_boss_loot), cleanup(clear_facts)]) :-
    drop_probability(goblin, copper_coin, P),
    assertion(P =:= 0.70).       %% common tier: loot_chance = 70 → 70/100

test(expected_drops_over_many_kills, [setup(setup_boss_loot), cleanup(clear_facts)]) :-
    expected_drops(dragon, dragon_heart, 1000, E),
    assertion(E =:= 10.0).       %% 1000 * 0.01

:- end_tests(integration_loot_probability).

%% ─────────────────────────────────────────────────────────────────────────────
%% combat + prob-detection: stealth viability against guards with world state
%% ─────────────────────────────────────────────────────────────────────────────

setup_heist_scenario :-
    %% Guard can attack the player (in range, both alive)
    assertz(attribute(guard, perception, 6)),
    assertz(attribute(guard, alert_state, active)),
    %% Dark world reduces detection
    assertz(attribute(world, light_level, dark)),
    %% Player has stealth gear
    assertz(attribute(rogue, stealth_bonus, 5)).

:- begin_tests(integration_combat_detection).

test(dark_world_lowers_detection, [nondet, setup(setup_heist_scenario), cleanup(clear_facts)]) :-
    detection_probability(guard, rogue, P),
    assertion(P < 0.60).   %% base would be ~0.78 active mid-perception, dark halves it

test(stealth_success_in_dark, [setup(setup_heist_scenario), cleanup(clear_facts)]) :-
    %% base 0.78 * dark 0.5 * stealth(5) = 0.78 * 0.5 * 0.65 ≈ 0.253 < 0.5
    assertion(stealth_success(guard, rogue)).

:- end_tests(integration_combat_detection).

%% ─────────────────────────────────────────────────────────────────────────────
%% economy + prob-economy: price range widens under conflict
%% ─────────────────────────────────────────────────────────────────────────────

setup_wartime_economy :-
    assertz(attribute(healing_potion, category, healing)),
    assertz(attribute(healing_potion, base_price, 40)),
    assertz(attribute(world, recent_conflict, true)),
    assertz(attribute(world, threat_rising,   true)).

:- begin_tests(integration_economy_prob).

test(demand_spike_raises_expected_price, [setup(setup_wartime_economy), cleanup(clear_facts)]) :-
    expected_price(healing_potion, Price),
    buy_price(healing_potion, Base),
    assertion(Price > Base).

test(high_demand_probability_in_conflict, [setup(setup_wartime_economy), cleanup(clear_facts)]) :-
    demand_spike(healing_potion, Pd),
    assertion(Pd =:= 0.75).    %% healing + recent_conflict is the highest rule

test(price_ceiling_above_base, [setup(setup_wartime_economy), cleanup(clear_facts)]) :-
    price_range(healing_potion, Base, _Low, High),
    assertion(High > Base).

:- end_tests(integration_economy_prob).
