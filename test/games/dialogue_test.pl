:- use_module(library(plunit)).

:- consult('../../modules/games/dialogue/dialogue').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_merchant_buy_topic :-
    assertz(attribute(buy_items, line, "What would you like?")),
    assertz(relation(buy_items, has_choice, ask_price)),
    assertz(relation(buy_items, has_choice, leave)),
    assertz(attribute(ask_price, leads_to, show_prices)),
    assertz(attribute(leave, ends_dialogue, true)).

setup_merchant_friendly_line :-
    setup_merchant_buy_topic,
    assertz(attribute(merchant_alice, always_friendly, true)),
    assertz(attribute(buy_items, line_friendly, "Great to see you!")).

setup_merchant_hostile_line :-
    setup_merchant_buy_topic,
    assertz(attribute(merchant_alice, always_hostile, true)),
    assertz(attribute(buy_items, line_hostile, "Make it quick.")).

setup_repeat_line :-
    setup_merchant_buy_topic,
    assertz(attribute(buy_items, line_repeat, "Again? Let me know.")),
    assertz(relation(merchant_alice_player1, discussed, buy_items)).

setup_gold_gated_choice :-
    assertz(relation(buy_items, has_choice, rare_item)),
    assertz(attribute(rare_item, requires_gold, 50)).

setup_player_rich :-
    assertz(attribute(player1, gold, 100)).

setup_player_broke :-
    assertz(attribute(player1, gold, 10)).

setup_item_gated_choice :-
    assertz(relation(buy_items, has_choice, secret_trade)),
    assertz(attribute(secret_trade, requires_item, golden_token)).

setup_player_has_token :-
    assertz(relation(player1, has_item, golden_token)).

setup_memory :-
    assertz(relation(merchant_alice_player1, discussed, buy_items)).

%% ── npc_says/4 ───────────────────────────────────────────────────────────────

:- begin_tests(dialogue_npc_says).

test(base_line, [setup(setup_merchant_buy_topic), cleanup(clear_facts)]) :-
    npc_says(merchant_alice, player1, buy_items, Line),
    assertion(Line == "What would you like?").

test(friendly_override, [setup(setup_merchant_friendly_line), cleanup(clear_facts)]) :-
    npc_says(merchant_alice, player1, buy_items, Line),
    assertion(Line == "Great to see you!").

test(hostile_override, [setup(setup_merchant_hostile_line), cleanup(clear_facts)]) :-
    npc_says(merchant_alice, player1, buy_items, Line),
    assertion(Line == "Make it quick.").

test(repeat_line_when_remembered, [setup(setup_repeat_line), cleanup(clear_facts)]) :-
    npc_says(merchant_alice, player1, buy_items, Line),
    assertion(Line == "Again? Let me know.").

test(empty_line_for_unknown_topic, [cleanup(clear_facts)]) :-
    npc_says(merchant_alice, player1, unknown_topic, Line),
    assertion(Line == "").

:- end_tests(dialogue_npc_says).

%% ── player_choices/4 ─────────────────────────────────────────────────────────

:- begin_tests(dialogue_choices).

test(choices_excludes_ending, [setup(setup_merchant_buy_topic), cleanup(clear_facts)]) :-
    player_choices(merchant_alice, player1, buy_items, Cs),
    assertion(member(ask_price, Cs)),
    assertion(\+ member(leave, Cs)).

test(gold_gated_choice_met, [setup((setup_merchant_buy_topic, setup_gold_gated_choice, setup_player_rich)), cleanup(clear_facts)]) :-
    player_choices(merchant_alice, player1, buy_items, Cs),
    assertion(member(rare_item, Cs)).

test(gold_gated_choice_not_met, [setup((setup_merchant_buy_topic, setup_gold_gated_choice, setup_player_broke)), cleanup(clear_facts)]) :-
    player_choices(merchant_alice, player1, buy_items, Cs),
    assertion(\+ member(rare_item, Cs)).

test(item_gated_choice_met, [setup((setup_merchant_buy_topic, setup_item_gated_choice, setup_player_has_token)), cleanup(clear_facts)]) :-
    player_choices(merchant_alice, player1, buy_items, Cs),
    assertion(member(secret_trade, Cs)).

test(item_gated_choice_not_met, [setup((setup_merchant_buy_topic, setup_item_gated_choice)), cleanup(clear_facts)]) :-
    player_choices(merchant_alice, player1, buy_items, Cs),
    assertion(\+ member(secret_trade, Cs)).

:- end_tests(dialogue_choices).

%% ── choice_leads_to/3 ────────────────────────────────────────────────────────

:- begin_tests(dialogue_navigation).

test(choice_leads_to_next_topic, [setup(setup_merchant_buy_topic), cleanup(clear_facts)]) :-
    choice_leads_to(buy_items, ask_price, Next),
    assertion(Next == show_prices).

:- end_tests(dialogue_navigation).

%% ── npc_remembers/3 ──────────────────────────────────────────────────────────

:- begin_tests(dialogue_memory).

test(remembers_discussed_topic, [setup(setup_memory), cleanup(clear_facts)]) :-
    assertion(npc_remembers(merchant_alice, player1, buy_items)).

test(does_not_remember_undiscussed, [setup(setup_memory), cleanup(clear_facts)]) :-
    assertion(\+ npc_remembers(merchant_alice, player1, sell_items)).

:- end_tests(dialogue_memory).
