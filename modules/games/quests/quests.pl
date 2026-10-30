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

%% quest_in_progress(?Player, ?Quest), quest_complete(?Player, ?Quest)
%% Bound, these check the <player>_<quest> key. With one side unbound it is
%% read back off the status keys, so the lister returns exactly the values the
%% bound check accepts. With both unbound, Quest runs over the quests the
%% definition facts name (quest_known/1) and Player is read off the keys.
quest_in_progress(Player, Quest) :-
    quest_status(Player, Quest, in_progress).

quest_complete(Player, Quest) :-
    quest_status(Player, Quest, complete).

quest_status(Player, Quest, Status) :-
    (   nonvar(Player), nonvar(Quest)
    ->  true
    ;   var(Player), var(Quest)
    ->  quest_known(Quest),
        quest_status_split(Player, Quest, Status)
    ;   quest_status_split(Player, Quest, Status)
    ),
    quest_state_key(Player, Quest, Key),
    attribute(Key, status, Status).

%% quest_status_split(?Player, ?Quest, +Status) — one side bound; each
%% Player-Quest pair once.
quest_status_split(Player, Quest, Status) :-
    setof(P-Q, quest_key_split(Status, P, Q), Pairs),
    member(Player-Quest, Pairs).

quest_key_split(Status, Player, Quest) :-
    attribute(Key, status, Status),
    atom(Key),
    (   nonvar(Player)
    ->  atom_concat(Player, '_', Prefix),
        atom_concat(Prefix, Quest, Key)
    ;   atom_concat(Prefix, Quest, Key),
        atom_concat(Player, '_', Prefix)
    ),
    Player \== '',
    Quest \== ''.

%% quest_known(-Quest) — each quest the definition facts name, once.
quest_known(Quest) :-
    setof(Q, quest_named(Q), Qs),
    member(Quest, Qs).

quest_named(Q) :- relation(world, quest_exists, Q).
quest_named(Q) :- attribute(Q, requires_quest, _).
quest_named(Q) :- attribute(Q, requires_level, _).
quest_named(Q) :- attribute(Q, requires_item, _).
quest_named(Q) :- attribute(_, requires_quest, Q).
quest_named(Q) :- attribute(Obj, quest, Q), attribute(Obj, order, _).

%% ── Prerequisites ─────────────────────────────────────────────────────────────
%% Assert quest prerequisites:
%%   { type:"attribute", entity:"slay_dragon", attribute:"requires_quest", value:"find_sword" }
%%   { type:"attribute", entity:"slay_dragon", attribute:"requires_level", value:10 }
%%   { type:"attribute", entity:"slay_dragon", attribute:"requires_item", value:"dragon_bane" }

%% prerequisite_met(+Player, +Quest) — every requires_* fact holds (all-of).
%% One clause, so a quest with no prerequisites succeeds once.
prerequisite_met(Player, Quest) :-
    \+ ( attribute(Quest, requires_quest, ReqQ),
         \+ quest_complete(Player, ReqQ) ),
    \+ ( attribute(Quest, requires_level, ReqL),
         \+ ( attribute(Player, level, L), L >= ReqL ) ),
    \+ ( attribute(Quest, requires_item, ReqItem),
         \+ relation(Player, has_item, ReqItem) ).

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

%% objective_complete(?Player, ?Obj)
%% Bound, this checks the <player>_<obj> key. With either side unbound it is
%% read back off the `complete` keys like quest_status/3, each pair once; with
%% both unbound, Obj runs over the objectives the facts define.
objective_complete(Player, Obj) :-
    (   nonvar(Player), nonvar(Obj)
    ->  quest_state_key(Player, Obj, Key),
        attribute(Key, complete, true)
    ;   setof(P-O, quest_objective_split(P, O), Pairs),
        member(Player-Obj, Pairs)
    ).

quest_objective_split(Player, Obj) :-
    ( var(Player), var(Obj) -> quest_objective(Obj) ; true ),
    attribute(Key, complete, true),
    atom(Key),
    (   nonvar(Player)
    ->  atom_concat(Player, '_', Prefix),
        atom_concat(Prefix, Obj, Key)
    ;   atom_concat(Prefix, Obj, Key),
        atom_concat(Player, '_', Prefix)
    ),
    Player \== '',
    Obj \== ''.

quest_objective(Obj) :-
    attribute(Obj, quest, _),
    attribute(Obj, order, _).

%% next_objective(?Player, ?Quest, ?Obj)
%% Unbound Player ranges over the players the facts tie to the quest: a status
%% on it, or a completed objective of it (quest_objective_player/2). A bound
%% player with no facts still starts at the first objective.
next_objective(Player, Quest, Obj) :-
    (   var(Player)
    ->  ( var(Quest) -> quest_with_objectives(Quest) ; true ),
        quest_objective_player(Quest, Player)
    ;   true
    ),
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

quest_with_objectives(Quest) :-
    setof(Q, quest_has_objective(Q), Qs),
    member(Quest, Qs).

quest_has_objective(Quest) :-
    attribute(Obj, quest, Quest),
    attribute(Obj, order, _).

quest_objective_player(Quest, Player) :-
    setof(P, quest_objective_holder(Quest, P), Players),
    member(Player, Players).

quest_objective_holder(Quest, Player) :-
    quest_status(Player, Quest, _).
quest_objective_holder(Quest, Player) :-
    attribute(Obj, quest, Quest),
    objective_complete(Player, Obj).

can_turn_in(Player, Quest) :-
    quest_in_progress(Player, Quest),
    \+ next_objective(Player, Quest, _).
