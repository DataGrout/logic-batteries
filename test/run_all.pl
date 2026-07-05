%% Test runner — loads all test files and runs the full suite.
%% Usage: swipl -g "run_tests, halt(0)" -t "halt(1)" test/run_all.pl

:- use_module(library(plunit)).

:- load_files([
    'support/test_helpers',
    %% Core
    'fsm_test',
    %% Games
    'games/inventory_test',
    'games/loot_tables_test',
    'games/quests_test',
    'games/progression_test',
    'games/combat_test',
    'games/economy_test',
    'games/npc_state_test',
    'games/puzzle_fsm_test',
    'games/world_test',
    'games/faction_test',
    'games/dialogue_test',
    'games/crafting_test',
    'games/permissions_test',
    'games/ai_director_test',
    'games/dungeon_test',
    %% Business
    'business/lead_scoring_test',
    'business/invoice_rules_test',
    'business/approval_chains_test',
    'business/inventory_mgmt_test',
    'business/pricing_rules_test',
    'business/loyalty_test',
    'business/scheduling_test',
    'business/compliance_test',
    %% Reasoning
    'reasoning/taxonomy_test',
    'reasoning/temporal_test',
    'reasoning/explain_test',
    'reasoning/fixpoint_test',
    %% Probabilistic
    'probabilistic/prob_loot_test',
    'probabilistic/prob_npc_test',
    'probabilistic/prob_detection_test',
    'probabilistic/prob_economy_test',
    'probabilistic/prob_core_iso_test',
    'probabilistic/prob_decide_test',
    %% Integration
    'integration_test'
], [relative_to('.')]).
