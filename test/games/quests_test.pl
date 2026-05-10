:- use_module(library(plunit)).

:- consult('../../modules/games/quests/quests').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Named helpers — all assertz calls here go to user module ─────────────────

setup_quest(Quest) :-
    assertz(relation(world, quest_exists, Quest)).

set_in_progress(Player, Quest) :-
    quest_state_key(Player, Quest, Key),
    assertz(attribute(Key, status, in_progress)).

set_complete(Player, Quest) :-
    quest_state_key(Player, Quest, Key),
    assertz(attribute(Key, status, complete)).

setup_quest_with_objectives :-
    setup_quest(slay_dragon),
    set_in_progress(alice, slay_dragon),
    assertz(attribute(obj1, quest, slay_dragon)),
    assertz(attribute(obj1, order, 1)),
    assertz(attribute(obj1, description, "Find the lair")),
    assertz(attribute(obj2, quest, slay_dragon)),
    assertz(attribute(obj2, order, 2)),
    assertz(attribute(obj2, description, "Defeat the dragon")).

setup_slay_dragon_requires_sword :-
    setup_quest(slay_dragon),
    assertz(attribute(slay_dragon, requires_quest, find_sword)).

setup_slay_dragon_requires_sword_complete :-
    setup_quest(slay_dragon),
    assertz(attribute(slay_dragon, requires_quest, find_sword)),
    set_complete(alice, find_sword).

setup_hard_quest_level_met :-
    setup_quest(hard_quest),
    assertz(attribute(hard_quest, requires_level, 10)),
    assertz(attribute(alice, level, 15)).

setup_hard_quest_level_unmet :-
    setup_quest(hard_quest),
    assertz(attribute(hard_quest, requires_level, 10)),
    assertz(attribute(alice, level, 5)).

setup_hard_quest_high_requirement :-
    setup_quest(hard_quest),
    assertz(attribute(hard_quest, requires_level, 20)),
    assertz(attribute(alice, level, 5)).

setup_vault_quest_with_key :-
    setup_quest(vault_quest),
    assertz(attribute(vault_quest, requires_item, golden_key)),
    assertz(relation(alice, has_item, golden_key)).

setup_vault_quest_no_key :-
    setup_quest(vault_quest),
    assertz(attribute(vault_quest, requires_item, golden_key)).

setup_objectives_first_done :-
    setup_quest_with_objectives,
    quest_state_key(alice, obj1, Key),
    assertz(attribute(Key, complete, true)).

setup_objectives_all_done :-
    setup_quest_with_objectives,
    quest_state_key(alice, obj1, K1),
    assertz(attribute(K1, complete, true)),
    quest_state_key(alice, obj2, K2),
    assertz(attribute(K2, complete, true)).

setup_turn_in_all_done :-
    setup_quest(slay_dragon),
    set_in_progress(alice, slay_dragon),
    assertz(attribute(obj1, quest, slay_dragon)),
    assertz(attribute(obj1, order, 1)),
    quest_state_key(alice, obj1, Key),
    assertz(attribute(Key, complete, true)).

setup_turn_in_not_done :-
    setup_quest(slay_dragon),
    set_in_progress(alice, slay_dragon),
    assertz(attribute(obj1, quest, slay_dragon)),
    assertz(attribute(obj1, order, 1)).

%% ── quest_state_key ───────────────────────────────────────────────────────────

:- begin_tests(quest_state_key).

test(key_format, [setup(true), cleanup(clear_facts)]) :-
    quest_state_key(alice, slay_dragon, Key),
    assertion(Key == alice_slay_dragon).

:- end_tests(quest_state_key).

%% ── quest_in_progress / quest_complete ───────────────────────────────────────

:- begin_tests(quest_status).

test(in_progress_true, [setup(set_in_progress(alice, slay_dragon)),
                         cleanup(clear_facts)]) :-
    assertion(quest_in_progress(alice, slay_dragon)).

test(in_progress_false_when_complete, [setup(set_complete(alice, slay_dragon)),
                                        cleanup(clear_facts)]) :-
    assertion(\+ quest_in_progress(alice, slay_dragon)).

test(complete_true, [setup(set_complete(alice, slay_dragon)),
                     cleanup(clear_facts)]) :-
    assertion(quest_complete(alice, slay_dragon)).

test(complete_false_when_in_progress, [setup(set_in_progress(alice, slay_dragon)),
                                        cleanup(clear_facts)]) :-
    assertion(\+ quest_complete(alice, slay_dragon)).

:- end_tests(quest_status).

%% ── quest_available ───────────────────────────────────────────────────────────

:- begin_tests(quest_available).

test(available_no_prereqs, [setup(setup_quest(easy_quest)), cleanup(clear_facts)]) :-
    assertion(quest_available(alice, easy_quest)).

test(not_available_in_progress, [
        setup((setup_quest(easy_quest), set_in_progress(alice, easy_quest))),
        cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, easy_quest)).

test(not_available_complete, [
        setup((setup_quest(easy_quest), set_complete(alice, easy_quest))),
        cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, easy_quest)).

test(available_with_met_quest_prereq, [
        setup(setup_slay_dragon_requires_sword_complete),
        cleanup(clear_facts)]) :-
    assertion(quest_available(alice, slay_dragon)).

test(not_available_unmet_quest_prereq, [
        setup(setup_slay_dragon_requires_sword),
        cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, slay_dragon)).

test(available_with_met_level_prereq, [
        setup(setup_hard_quest_level_met),
        cleanup(clear_facts)]) :-
    assertion(quest_available(alice, hard_quest)).

test(not_available_unmet_level_prereq, [
        setup(setup_hard_quest_level_unmet),
        cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, hard_quest)).

test(available_with_met_item_prereq, [
        setup(setup_vault_quest_with_key),
        cleanup(clear_facts)]) :-
    assertion(quest_available(alice, vault_quest)).

test(not_available_unmet_item_prereq, [
        setup(setup_vault_quest_no_key),
        cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, vault_quest)).

:- end_tests(quest_available).

%% ── quest_blocked_by ──────────────────────────────────────────────────────────

:- begin_tests(quest_blocked).

test(blocked_already_complete, [
        setup((setup_quest(easy_quest), set_complete(alice, easy_quest))),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, easy_quest, Reason),
    assertion(Reason == 'already complete').

test(blocked_requires_quest, [
        setup(setup_slay_dragon_requires_sword),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, slay_dragon, Reason),
    assertion(Reason == requires_quest(find_sword)).

test(blocked_requires_level, [
        setup(setup_hard_quest_high_requirement),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, hard_quest, Reason),
    assertion(Reason == requires_level(20)).

test(blocked_requires_item, [
        setup(setup_vault_quest_no_key),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, vault_quest, Reason),
    assertion(Reason == requires_item(golden_key)).

:- end_tests(quest_blocked).

%% ── next_objective ────────────────────────────────────────────────────────────

:- begin_tests(quest_objectives).

test(first_objective_when_none_complete, [
        setup(setup_quest_with_objectives),
        cleanup(clear_facts)]) :-
    next_objective(alice, slay_dragon, Obj),
    assertion(Obj == obj1).

test(second_objective_after_first_complete, [
        setup(setup_objectives_first_done),
        cleanup(clear_facts)]) :-
    next_objective(alice, slay_dragon, Obj),
    assertion(Obj == obj2).

test(no_objective_when_all_complete, [
        setup(setup_objectives_all_done),
        cleanup(clear_facts)]) :-
    assertion(\+ next_objective(alice, slay_dragon, _)).

:- end_tests(quest_objectives).

%% ── can_turn_in ───────────────────────────────────────────────────────────────

:- begin_tests(quest_turn_in).

test(can_turn_in_all_objectives_done, [
        setup(setup_turn_in_all_done),
        cleanup(clear_facts)]) :-
    assertion(can_turn_in(alice, slay_dragon)).

test(cannot_turn_in_objective_remaining, [
        setup(setup_turn_in_not_done),
        cleanup(clear_facts)]) :-
    assertion(\+ can_turn_in(alice, slay_dragon)).

test(cannot_turn_in_not_in_progress, [
        setup(setup_quest(slay_dragon)),
        cleanup(clear_facts)]) :-
    assertion(\+ can_turn_in(alice, slay_dragon)).

:- end_tests(quest_turn_in).
