%% Battery: quests v1.0.0
%% Exports: quest_available/2, quest_complete/2, quest_in_progress/2,
%%          next_objective/3, quest_blocked_by/3, can_turn_in/2

battery_module(quests, '1.0.0', auto).

battery_export(quests, 'quest_available/2',   'quest_available(Player, Quest) — Quest is available for Player to accept').
battery_export(quests, 'quest_complete/2',    'quest_complete(Player, Quest) — Player has completed Quest').
battery_export(quests, 'quest_in_progress/2', 'quest_in_progress(Player, Quest) — Player has accepted but not completed Quest').
battery_export(quests, 'next_objective/3',    'next_objective(Player, Quest, Obj) — Obj is the current unmet objective').
battery_export(quests, 'quest_blocked_by/3',  'quest_blocked_by(Player, Quest, Reason) — Quest is not available due to Reason').
battery_export(quests, 'can_turn_in/2',       'can_turn_in(Player, Quest) — all objectives met, ready to complete').

%% ── Quest state ──────────────────────────────────────────────────────────────
%% Assert state facts as the player progresses:
%%   { type:"relation", subject:"alice", relation:"quest_status", object:"slay_dragon" }
%%   { type:"attribute", entity:"alice_slay_dragon", attribute:"status", value:"in_progress" }
%%   { type:"attribute", entity:"alice_slay_dragon", attribute:"status", value:"complete" }

quest_state_key(Player, Quest, Key) :-
    atom_concat(Player, '_', Tmp),
    atom_concat(Tmp, Quest, Key).

quest_in_progress(Player, Quest) :-
    quest_state_key(Player, Quest, Key),
    attribute(Key, status, in_progress).

quest_complete(Player, Quest) :-
    quest_state_key(Player, Quest, Key),
    attribute(Key, status, complete).

%% ── Prerequisites ─────────────────────────────────────────────────────────────
%% Assert quest prerequisites:
%%   { type:"attribute", entity:"slay_dragon", attribute:"requires_quest", value:"find_sword" }
%%   { type:"attribute", entity:"slay_dragon", attribute:"requires_level", value:10 }
%%   { type:"attribute", entity:"slay_dragon", attribute:"requires_item", value:"dragon_bane" }

prerequisite_met(_Player, Quest) :-
    \+ attribute(Quest, requires_quest, _),
    \+ attribute(Quest, requires_level, _),
    \+ attribute(Quest, requires_item, _).
prerequisite_met(Player, Quest) :-
    (   attribute(Quest, requires_quest, ReqQ)
    ->  quest_complete(Player, ReqQ)
    ;   true ),
    (   attribute(Quest, requires_level, ReqL)
    ->  attribute(Player, level, L), L >= ReqL
    ;   true ),
    (   attribute(Quest, requires_item, ReqItem)
    ->  relation(Player, has_item, ReqItem)
    ;   true ).

%% ── Availability ─────────────────────────────────────────────────────────────

quest_available(Player, Quest) :-
    relation(world, quest_exists, Quest),
    \+ quest_in_progress(Player, Quest),
    \+ quest_complete(Player, Quest),
    prerequisite_met(Player, Quest).

quest_blocked_by(Player, Quest, 'already complete') :-
    quest_complete(Player, Quest).
quest_blocked_by(Player, Quest, requires_quest(ReqQ)) :-
    attribute(Quest, requires_quest, ReqQ),
    \+ quest_complete(Player, ReqQ).
quest_blocked_by(Player, Quest, requires_level(ReqL)) :-
    attribute(Quest, requires_level, ReqL),
    attribute(Player, level, L),
    L < ReqL.
quest_blocked_by(Player, Quest, requires_item(ReqItem)) :-
    attribute(Quest, requires_item, ReqItem),
    \+ relation(Player, has_item, ReqItem).

%% ── Objectives ────────────────────────────────────────────────────────────────
%% Assert objectives:
%%   { type:"attribute", entity:"slay_dragon_obj1", attribute:"quest", value:"slay_dragon" }
%%   { type:"attribute", entity:"slay_dragon_obj1", attribute:"order", value:1 }
%%   { type:"attribute", entity:"slay_dragon_obj1", attribute:"description", value:"Find the dragon's lair" }
%% Mark complete:
%%   { type:"attribute", entity:"alice_slay_dragon_obj1", attribute:"complete", value:true }

objective_complete(Player, Obj) :-
    quest_state_key(Player, Obj, Key),
    attribute(Key, complete, true).

next_objective(Player, Quest, Obj) :-
    attribute(Obj, quest, Quest),
    attribute(Obj, order, _),
    \+ objective_complete(Player, Obj),
    \+ (
        attribute(Obj2, quest, Quest),
        attribute(Obj2, order, O2),
        attribute(Obj, order, O1),
        O2 < O1,
        \+ objective_complete(Player, Obj2)
    ).

can_turn_in(Player, Quest) :-
    quest_in_progress(Player, Quest),
    \+ next_objective(Player, Quest, _).
