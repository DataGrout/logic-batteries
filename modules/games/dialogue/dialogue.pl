%% Battery: dialogue v1.0.0
%% Exports: npc_says/4, player_choices/4, choice_leads_to/3,
%%          npc_remembers/3, dialogue_complete/3

battery_module(dialogue, '1.0.0', auto).

battery_export(dialogue, 'npc_says/4',         'npc_says(NPC, Player, Topic, Line) — Line is what NPC says for Topic (context-aware)').
battery_export(dialogue, 'player_choices/4',   'player_choices(NPC, Player, Topic, Choices) — Choices is the list of available player responses').
battery_export(dialogue, 'choice_leads_to/3',  'choice_leads_to(Topic, Choice, NextTopic) — choosing Choice from Topic transitions to NextTopic').
battery_export(dialogue, 'npc_remembers/3',    'npc_remembers(NPC, Player, Topic) — NPC has previously discussed Topic with Player').
battery_export(dialogue, 'dialogue_complete/3','dialogue_complete(NPC, Player, Topic) — Topic has been fully exhausted (no further choices)').

%% ── Dialogue Data Model ───────────────────────────────────────────────────────
%%
%% Dialogue lines (NPC's words):
%%   attribute(buy_items, line, "What would you like to buy?")
%%
%% Context-sensitive variants (override base line when condition holds):
%%   attribute(buy_items, line_friendly, "Great to see a friend! What can I get you?")
%%   attribute(buy_items, line_hostile,  "Make it quick.")
%%   attribute(buy_items, line_morning,  "Good morning! Fresh stock just in.")
%%
%% Player response choices:
%%   relation(buy_items, has_choice, ask_price)
%%   relation(buy_items, has_choice, browse_weapons)
%%   relation(buy_items, has_choice, leave)
%%
%% Navigation:
%%   attribute(ask_price, leads_to, show_prices)
%%   attribute(leave,     leads_to, goodbye)
%%   attribute(leave,     ends_dialogue, true)
%%
%% Memory (NPC recalls prior conversations):
%%   relation(merchant_alice, discussed, secret_sale)    %% keyed as npc_player
%%
%% Condition-gated choices (combine with npc-state for prerequisites):
%%   attribute(bribe_guard, requires_gold, 50)

%% ── npc_says/4 ───────────────────────────────────────────────────────────────

npc_says(NPC, Player, Topic, Line) :-
    ( npc_says_contextual(NPC, Player, Topic, Line) -> true
    ; attribute(Topic, line, Line) -> true
    ; Line = "" ).

npc_says_contextual(NPC, _Player, Topic, Line) :-
    attribute(NPC, always_friendly, true),
    attribute(Topic, line_friendly, Line), !.
npc_says_contextual(NPC, _Player, Topic, Line) :-
    attribute(NPC, always_hostile, true),
    attribute(Topic, line_hostile, Line), !.
npc_says_contextual(NPC, Player, Topic, Line) :-
    attribute(Topic, line_repeat, Line),
    npc_remembers(NPC, Player, Topic), !.

%% ── player_choices/4 ─────────────────────────────────────────────────────────

player_choices(NPC, Player, Topic, Choices) :-
    findall(C, valid_choice(NPC, Player, Topic, C), Choices).

valid_choice(NPC, Player, Topic, Choice) :-
    relation(Topic, has_choice, Choice),
    \+ attribute(Choice, ends_dialogue, true),
    choice_prereqs_met(NPC, Player, Choice).

choice_prereqs_met(_, Player, Choice) :-
    ( attribute(Choice, requires_gold, Need)
      -> ( attribute(Player, gold, Have), Have >= Need )
      ;  true ),
    ( attribute(Choice, requires_item, Item)
      -> relation(Player, has_item, Item)
      ;  true ).

%% ── choice_leads_to/3 ────────────────────────────────────────────────────────

choice_leads_to(Topic, Choice, NextTopic) :-
    relation(Topic, has_choice, Choice),
    attribute(Choice, leads_to, NextTopic).

%% ── npc_remembers/3 ──────────────────────────────────────────────────────────

npc_remembers(NPC, Player, Topic) :-
    dialogue_key(NPC, Player, Key),
    relation(Key, discussed, Topic).

dialogue_key(NPC, Player, Key) :-
    atom_concat(NPC, '_', Tmp),
    atom_concat(Tmp, Player, Key).

%% ── dialogue_complete/3 ──────────────────────────────────────────────────────

dialogue_complete(NPC, Player, Topic) :-
    \+ ( relation(Topic, has_choice, Choice),
         \+ attribute(Choice, ends_dialogue, true),
         choice_prereqs_met(NPC, Player, Choice) ).
