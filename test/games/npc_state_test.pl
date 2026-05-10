:- use_module(library(plunit)).

:- consult('../../modules/games/npc-state/npc_state').

%% (clear_facts/0 and dynamic declarations are in test/support/test_helpers.pl)

%% ── Setup predicates ─────────────────────────────────────────────────────────

set_relationship(NPC, Player, Score) :-
    relationship_key(NPC, Player, Key),
    assertz(attribute(Key, score, Score)).

setup_merchant_neutral :-
    set_relationship(merchant, alice, 0).

setup_merchant_friendly :-
    set_relationship(merchant, alice, 50).

setup_merchant_hostile :-
    set_relationship(merchant, alice, -50).

setup_merchant_barely_friendly :-
    set_relationship(merchant, alice, 25).

setup_merchant_barely_hostile :-
    set_relationship(merchant, alice, -25).

setup_always_friendly_npc :-
    assertz(attribute(innkeeper, always_friendly, true)).

setup_always_hostile_npc :-
    assertz(attribute(bandit, always_hostile, true)).

setup_custom_thresholds :-
    assertz(attribute(relationship, friendly_threshold, 50)),
    assertz(attribute(relationship, hostile_threshold, -50)).

setup_merchant_faction :-
    assertz(attribute(merchant, faction, traders_guild)).

setup_merchant_alice_topic :-
    assertz(relation(merchant, has_dialogue, buy_items)).

setup_merchant_friendly_topic :-
    assertz(relation(merchant, has_dialogue, secret_sale)),
    assertz(attribute(secret_sale, requires_friendly, true)).

setup_merchant_relationship_topic :-
    assertz(relation(merchant, has_dialogue, guild_info)),
    assertz(attribute(guild_info, requires_relationship, 60)).

setup_merchant_quest_topic :-
    assertz(relation(merchant, has_dialogue, reward_topic)),
    assertz(attribute(reward_topic, requires_quest, find_artifact)).

setup_merchant_item_topic :-
    assertz(relation(merchant, has_dialogue, members_discount)),
    assertz(attribute(members_discount, requires_item, guild_badge)).

setup_quest_topic_met :-
    setup_merchant_quest_topic,
    assertz(relation(alice, completed_quest, find_artifact)).

setup_item_topic_met :-
    setup_merchant_item_topic,
    assertz(relation(alice, has_item, guild_badge)).

%% ── relationship_level/3 ─────────────────────────────────────────────────────

:- begin_tests(npc_relationship_level).

test(default_score_is_zero, [setup(true), cleanup(clear_facts)]) :-
    relationship_level(merchant, alice, L), assertion(L == 0).

test(set_positive_score, [setup(setup_merchant_friendly), cleanup(clear_facts)]) :-
    relationship_level(merchant, alice, L), assertion(L == 50).

test(set_negative_score, [setup(setup_merchant_hostile), cleanup(clear_facts)]) :-
    relationship_level(merchant, alice, L), assertion(L == -50).

:- end_tests(npc_relationship_level).

%% ── npc_friendly/2 ───────────────────────────────────────────────────────────

:- begin_tests(npc_friendly).

test(friendly_above_threshold, [setup(setup_merchant_friendly), cleanup(clear_facts)]) :-
    assertion(npc_friendly(merchant, alice)).

test(friendly_at_threshold, [setup(setup_merchant_barely_friendly), cleanup(clear_facts)]) :-
    assertion(npc_friendly(merchant, alice)).

test(not_friendly_below_threshold, [setup(setup_merchant_neutral), cleanup(clear_facts)]) :-
    assertion(\+ npc_friendly(merchant, alice)).

test(not_friendly_hostile_npc, [setup(setup_merchant_hostile), cleanup(clear_facts)]) :-
    assertion(\+ npc_friendly(merchant, alice)).

test(always_friendly_override, [setup(setup_always_friendly_npc), cleanup(clear_facts)]) :-
    assertion(npc_friendly(innkeeper, alice)).

test(always_hostile_cannot_be_friendly, [setup(setup_always_hostile_npc), cleanup(clear_facts)]) :-
    assertion(\+ npc_friendly(bandit, alice)).

test(custom_friendly_threshold, [
        setup((setup_custom_thresholds, set_relationship(merchant, alice, 49))),
        cleanup(clear_facts)]) :-
    assertion(\+ npc_friendly(merchant, alice)).

:- end_tests(npc_friendly).

%% ── npc_hostile/2 ────────────────────────────────────────────────────────────

:- begin_tests(npc_hostile).

test(hostile_below_threshold, [setup(setup_merchant_hostile), cleanup(clear_facts)]) :-
    assertion(npc_hostile(merchant, alice)).

test(hostile_at_threshold, [setup(setup_merchant_barely_hostile), cleanup(clear_facts)]) :-
    assertion(npc_hostile(merchant, alice)).

test(not_hostile_neutral, [setup(setup_merchant_neutral), cleanup(clear_facts)]) :-
    assertion(\+ npc_hostile(merchant, alice)).

test(not_hostile_friendly, [setup(setup_merchant_friendly), cleanup(clear_facts)]) :-
    assertion(\+ npc_hostile(merchant, alice)).

test(always_hostile_override, [setup(setup_always_hostile_npc), cleanup(clear_facts)]) :-
    assertion(npc_hostile(bandit, alice)).

test(always_friendly_cannot_be_hostile, [setup(setup_always_friendly_npc), cleanup(clear_facts)]) :-
    assertion(\+ npc_hostile(innkeeper, alice)).

:- end_tests(npc_hostile).

%% ── faction_member/2 ─────────────────────────────────────────────────────────

:- begin_tests(npc_faction).

test(faction_membership, [setup(setup_merchant_faction), cleanup(clear_facts)]) :-
    assertion(faction_member(merchant, traders_guild)).

test(no_faction, [setup(true), cleanup(clear_facts)]) :-
    assertion(\+ faction_member(merchant, traders_guild)).

:- end_tests(npc_faction).

%% ── dialogue_available/3 ─────────────────────────────────────────────────────

:- begin_tests(npc_dialogue).

test(unrestricted_topic_always_available, [
        setup(setup_merchant_alice_topic),
        cleanup(clear_facts)]) :-
    assertion(dialogue_available(merchant, alice, buy_items)).

test(friendly_topic_available_when_friendly, [
        setup((setup_merchant_friendly_topic, setup_merchant_friendly)),
        cleanup(clear_facts)]) :-
    assertion(dialogue_available(merchant, alice, secret_sale)).

test(friendly_topic_unavailable_when_neutral, [
        setup((setup_merchant_friendly_topic, setup_merchant_neutral)),
        cleanup(clear_facts)]) :-
    assertion(\+ dialogue_available(merchant, alice, secret_sale)).

test(relationship_topic_met, [
        setup((setup_merchant_relationship_topic, set_relationship(merchant, alice, 60))),
        cleanup(clear_facts)]) :-
    assertion(dialogue_available(merchant, alice, guild_info)).

test(relationship_topic_unmet, [
        setup((setup_merchant_relationship_topic, set_relationship(merchant, alice, 59))),
        cleanup(clear_facts)]) :-
    assertion(\+ dialogue_available(merchant, alice, guild_info)).

test(quest_topic_met, [
        setup(setup_quest_topic_met),
        cleanup(clear_facts)]) :-
    assertion(dialogue_available(merchant, alice, reward_topic)).

test(quest_topic_unmet, [
        setup(setup_merchant_quest_topic),
        cleanup(clear_facts)]) :-
    assertion(\+ dialogue_available(merchant, alice, reward_topic)).

test(item_topic_met, [
        setup(setup_item_topic_met),
        cleanup(clear_facts)]) :-
    assertion(dialogue_available(merchant, alice, members_discount)).

test(item_topic_unmet, [
        setup(setup_merchant_item_topic),
        cleanup(clear_facts)]) :-
    assertion(\+ dialogue_available(merchant, alice, members_discount)).

:- end_tests(npc_dialogue).
