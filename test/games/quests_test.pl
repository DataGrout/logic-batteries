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

setup_hard_quest_no_player_level :-
    setup_quest(hard_quest),
    assertz(attribute(hard_quest, requires_level, 10)).

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

%% A board with several quests and two players, for the lister modes.
%% find_sword is only ever named as a prerequisite (no quest_exists fact).
setup_quest_board :-
    setup_quest(slay_dragon),
    setup_quest(gather_herbs),
    setup_quest(vault_quest),
    setup_quest(hard_quest),
    assertz(attribute(slay_dragon, requires_quest, find_sword)),
    assertz(attribute(vault_quest, requires_item, golden_key)),
    assertz(attribute(hard_quest, requires_level, 20)),
    assertz(attribute(alice, level, 5)),
    set_complete(alice, find_sword),
    set_in_progress(alice, gather_herbs),
    set_in_progress(bob, slay_dragon),
    assertz(attribute(herbs_obj1, quest, gather_herbs)),
    assertz(attribute(herbs_obj1, order, 1)),
    quest_state_key(alice, herbs_obj1, Key),
    assertz(attribute(Key, complete, true)).

%% Two quest prerequisites, only the first met.
setup_two_quest_prereqs :-
    setup_quest(epic),
    assertz(attribute(epic, requires_quest, find_sword)),
    assertz(attribute(epic, requires_quest, find_shield)),
    set_complete(alice, find_sword).

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
        nondet, setup((setup_quest(easy_quest), set_complete(alice, easy_quest))),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, easy_quest, Reason),
    assertion(Reason == 'already complete').

test(blocked_requires_quest, [
        nondet, setup(setup_slay_dragon_requires_sword),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, slay_dragon, Reason),
    assertion(Reason == requires_quest(find_sword)).

test(blocked_requires_level, [
        nondet, setup(setup_hard_quest_high_requirement),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, hard_quest, Reason),
    assertion(Reason == requires_level(20)).

%% A player with no level fails the level gate in quest_available, so the
%% gate is also the reason it gives (it used to give none).
test(blocked_requires_level_when_player_has_no_level, [
        setup(setup_hard_quest_no_player_level),
        cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, hard_quest)),
    findall(R, quest_blocked_by(alice, hard_quest, R), Rs),
    assertion(Rs == [requires_level(10)]).

test(blocked_requires_item, [
        setup(setup_vault_quest_no_key),
        cleanup(clear_facts)]) :-
    quest_blocked_by(alice, vault_quest, Reason),
    assertion(Reason == requires_item(golden_key)).

:- end_tests(quest_blocked).

%% ── next_objective ────────────────────────────────────────────────────────────

:- begin_tests(quest_objectives).

test(first_objective_when_none_complete, [
        nondet, setup(setup_quest_with_objectives),
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

%% ── Listing (unbound arguments) ──────────────────────────────────────────────

:- begin_tests(quest_listing).

test(available_no_prereqs_once, [setup(setup_quest(easy_quest)), cleanup(clear_facts)]) :-
    findall(Q, quest_available(alice, Q), Qs),
    assertion(Qs == [easy_quest]),
    findall(x, quest_available(alice, easy_quest), Xs),
    assertion(Xs == [x]).

test(available_lists_each_once, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(Q, quest_available(alice, Q), A),
    assertion(A == [slay_dragon]),
    findall(Q, quest_available(bob, Q), B),
    assertion(B == [gather_herbs]).

test(prerequisites_all_of, [setup(setup_two_quest_prereqs), cleanup(clear_facts)]) :-
    assertion(\+ quest_available(alice, epic)),
    findall(R, quest_blocked_by(alice, epic, R), Rs),
    assertion(Rs == [requires_quest(find_shield)]).

test(complete_lists_quests, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(Q, quest_complete(alice, Q), Qs),
    assertion(Qs == [find_sword]).

test(in_progress_lists_quests, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(Q, quest_in_progress(alice, Q), A),
    assertion(A == [gather_herbs]),
    findall(Q, quest_in_progress(bob, Q), B),
    assertion(B == [slay_dragon]).

test(in_progress_lists_players, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(P, quest_in_progress(P, slay_dragon), Ps),
    assertion(Ps == [bob]),
    findall(P, quest_complete(P, find_sword), Cs),
    assertion(Cs == [alice]).

test(in_progress_lists_pairs, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(P-Q, quest_in_progress(P, Q), Pairs),
    msort(Pairs, Sorted),
    assertion(Sorted == [alice-gather_herbs, bob-slay_dragon]).

test(blocked_by_lists_quests, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(Q-R, quest_blocked_by(alice, Q, R), Found),
    msort(Found, Sorted),
    assertion(Sorted == [find_sword-'already complete',
                         hard_quest-requires_level(20),
                         vault_quest-requires_item(golden_key)]).

test(can_turn_in_lists_quests, [setup(setup_quest_board), cleanup(clear_facts)]) :-
    findall(Q, can_turn_in(alice, Q), A),
    assertion(A == [gather_herbs]),
    findall(Q, can_turn_in(bob, Q), B),
    assertion(B == [slay_dragon]).

test(nothing_listed_without_state, [cleanup(clear_facts)]) :-
    findall(Q, quest_complete(alice, Q), Qs),
    assertion(Qs == []),
    findall(Q, can_turn_in(alice, Q), Ts),
    assertion(Ts == []).

:- end_tests(quest_listing).

%% ── Unbound Player: next_objective and objective_complete ────────────────────

%% alice is on obj2 of slay_dragon, bob on obj1, carol has finished obj1 of
%% gather_herbs without a status fact, dave has finished slay_dragon outright.
%% Objective ids are not suffixes of one another (see the README's `_` note).
setup_objective_board :-
    setup_quest_with_objectives,
    set_in_progress(bob, slay_dragon),
    set_complete(dave, slay_dragon),
    quest_state_key(alice, obj1, KA),
    assertz(attribute(KA, complete, true)),
    quest_state_key(dave, obj1, KD1),
    assertz(attribute(KD1, complete, true)),
    quest_state_key(dave, obj2, KD2),
    assertz(attribute(KD2, complete, true)),
    assertz(attribute(herb1, quest, gather_herbs)),
    assertz(attribute(herb1, order, 1)),
    assertz(attribute(herb2, quest, gather_herbs)),
    assertz(attribute(herb2, order, 2)),
    quest_state_key(carol, herb1, KC),
    assertz(attribute(KC, complete, true)).

:- begin_tests(quest_unbound_player).

test(objective_complete_lists_players, [setup(setup_objective_board), cleanup(clear_facts)]) :-
    findall(P, objective_complete(P, obj1), Ps0),
    msort(Ps0, Ps),
    assertion(Ps == [alice, dave]).

test(objective_complete_lists_pairs, [setup(setup_objective_board), cleanup(clear_facts)]) :-
    findall(P-O, objective_complete(P, O), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [alice-obj1, carol-herb1, dave-obj1, dave-obj2]).

test(next_objective_lists_players, [setup(setup_objective_board), cleanup(clear_facts)]) :-
    findall(P-O, next_objective(P, slay_dragon, O), Pairs0),
    msort(Pairs0, Pairs),
    assertion(Pairs == [alice-obj2, bob-obj1]).

test(next_objective_lists_every_triple, [setup(setup_objective_board), cleanup(clear_facts)]) :-
    findall(P-Q-O, next_objective(P, Q, O), Triples0),
    msort(Triples0, Triples),
    assertion(Triples == [alice-slay_dragon-obj2, bob-slay_dragon-obj1,
                          carol-gather_herbs-herb2]).

test(next_objective_bound_unchanged, [setup(setup_objective_board), cleanup(clear_facts)]) :-
    %% a bound player with no facts still starts at the first objective
    findall(O, next_objective(erin, slay_dragon, O), Os),
    assertion(Os == [obj1]).

:- end_tests(quest_unbound_player).
