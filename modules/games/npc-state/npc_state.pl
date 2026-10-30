%% Battery: npc-state v1.0.0
%% Exports: npc_friendly/2, npc_hostile/2, dialogue_available/3,
%%          faction_member/2, relationship_level/3

battery_module('npc-state', '1.0.0', auto).

battery_export('npc-state', 'npc_friendly/2',       'npc_friendly(NPC, Player) — NPC has a friendly disposition toward Player').
battery_export('npc-state', 'npc_hostile/2',        'npc_hostile(NPC, Player) — NPC has a hostile disposition toward Player').
battery_export('npc-state', 'dialogue_available/3', 'dialogue_available(NPC, Player, Topic) — Topic is an unlocked conversation option').
battery_export('npc-state', 'faction_member/2',     'faction_member(Entity, Faction) — Entity belongs to Faction').
battery_export('npc-state', 'relationship_level/3', 'relationship_level(NPC, Player, Level) — Level is the numeric relationship score').

%% ── Relationship Levels ──────────────────────────────────────────────────────
%%
%% Numeric relationship score between an NPC and a player:
%%   attribute(merchant_npc_alice, score, 75)   %% keyed by npc_player
%%
%% Thresholds (defaults):
%%   attribute(relationship, friendly_threshold, 25)
%%   attribute(relationship, hostile_threshold,  -25)
%%
%% Direct override (bypasses score):
%%   attribute(bandit, always_hostile, true)
%%   attribute(innkeeper, always_friendly, true)

relationship_key(NPC, Player, Key) :-
    atom_concat(NPC, '_', Tmp),
    atom_concat(Tmp, Player, Key).

%% relationship_level(?NPC, ?Player, ?Level)
%% Bound, Level is the `<npc>_<player>` score, or 0 when none is set; it is
%% computed before it is compared. Unbound NPC or Player ranges over the scores
%% that are set (npc_state_scored_npc/2, npc_state_scored_player/2), with no 0
%% default.
relationship_level(NPC, Player, Level) :-
    (   nonvar(NPC), nonvar(Player)
    ->  relationship_key(NPC, Player, Key),
        npc_state_key_score(Key, Level0),
        Level = Level0
    ;   ( var(NPC) -> npc_state_scored_npc(Player, NPC) ; true ),
        ( var(Player) -> npc_state_scored_player(NPC, Player) ; true ),
        relationship_key(NPC, Player, Key),
        npc_state_key_score(Key, Level)
    ).

npc_state_key_score(Key, Level) :-
    attribute(Key, score, Level), !.
npc_state_key_score(_, 0).

friendly_threshold(T) :-
    attribute(relationship, friendly_threshold, T), !.
friendly_threshold(25).

hostile_threshold(T) :-
    attribute(relationship, hostile_threshold, T), !.
hostile_threshold(-25).

%% npc_friendly(?NPC, ?Player)
%% Unbound NPC ranges over the NPCs the facts name (npc_state_npc/2); the
%% `always_friendly` override per NPC still wins first. That override is
%% friendly to anyone, so it leaves an unbound Player unbound; otherwise an
%% unbound Player ranges over the players the NPC has a `score` with. A player
%% with no score reads as 0 and is not enumerated.
npc_friendly(NPC, Player) :-
    ( var(NPC) -> npc_state_npc(Player, NPC) ; true ),
    npc_friendly_(NPC, Player).

npc_friendly_(NPC, _) :-
    attribute(NPC, always_friendly, true), !.
npc_friendly_(NPC, Player) :-
    \+ attribute(NPC, always_hostile, true),
    ( var(Player) -> npc_state_scored_player(NPC, Player) ; true ),
    relationship_level(NPC, Player, L),
    friendly_threshold(T),
    L >= T.

%% npc_hostile(?NPC, ?Player) — the mirror of npc_friendly/2.
npc_hostile(NPC, Player) :-
    ( var(NPC) -> npc_state_npc(Player, NPC) ; true ),
    npc_hostile_(NPC, Player).

npc_hostile_(NPC, _) :-
    attribute(NPC, always_hostile, true), !.
npc_hostile_(NPC, Player) :-
    \+ attribute(NPC, always_friendly, true),
    ( var(Player) -> npc_state_scored_player(NPC, Player) ; true ),
    relationship_level(NPC, Player, L),
    hostile_threshold(T),
    L =< T.

%% npc_state_npc(?Player, -NPC): the NPCs the facts name, each once — those
%% with an `always_*` flag or a `has_dialogue` topic, and those with a score.
%% A score sits on `<npc>_<player>`: with Player bound the NPC is the key less
%% the `_<player>` suffix; unbound, it is the key up to its first `_`, which is
%% exact only when NPC ids are free of `_` (the README's convention).
npc_state_npc(Player, NPC) :-
    setof(N, npc_state_npc_named(Player, N), NPCs),
    member(NPC, NPCs).

npc_state_npc_named(_, N) :- attribute(N, always_friendly, true).
npc_state_npc_named(_, N) :- attribute(N, always_hostile, true).
npc_state_npc_named(_, N) :- relation(N, has_dialogue, _).
npc_state_npc_named(Player, N) :-
    npc_state_score_npc(Player, N).

%% npc_state_scored_npc(?Player, -NPC): each NPC with a score, once, read off
%% the key as npc_state_npc/2 describes.
npc_state_scored_npc(Player, NPC) :-
    setof(N, npc_state_score_npc(Player, N), NPCs),
    member(NPC, NPCs).

npc_state_score_npc(Player, N) :-
    attribute(Key, score, _),
    atom(Key),
    (   atom(Player)
    ->  atom_concat('_', Player, Suffix),
        atom_concat(N, Suffix, Key),
        N \== ''
    ;   var(Player),
        atom_codes(Key, Codes),
        append(NCodes, [0'_|_], Codes),
        NCodes \== [],
        \+ member(0'_, NCodes),
        atom_codes(N, NCodes)
    ).

%% npc_state_scored_player(+NPC, -Player): each player with a score on
%% `<NPC>_<Player>`, once.
npc_state_scored_player(NPC, Player) :-
    atom(NPC),
    atom_concat(NPC, '_', Prefix),
    setof(P, S^Key^( attribute(Key, score, S),
                     atom(Key),
                     atom_concat(Prefix, P, Key),
                     P \== '' ), Players),
    member(Player, Players).

%% ── Factions ─────────────────────────────────────────────────────────────────
%%
%% Assert faction membership:
%%   attribute(merchant_npc, faction, traders_guild)
%%
%% Faction-level relations:
%%   attribute(traders_guild, allied_with, merchants_guild)
%%   attribute(bandits, at_war_with, kingdom)

faction_member(Entity, Faction) :-
    attribute(Entity, faction, Faction).

%% ── Dialogue ─────────────────────────────────────────────────────────────────
%%
%% dialogue_available(?NPC, ?Player, ?Topic)
%% Unbound Player ranges over the players the gates name: those friendly to the
%% NPC (npc_friendly/2), with a set score, or with the completed quest or held
%% item. A topic with no player gate leaves Player unbound (open to anyone).
%%
%% Assert dialogue topics with prerequisites:
%%   relation(merchant_npc, has_dialogue, buy_topic)
%%   attribute(buy_topic, requires_friendly, true)       %% NPC must be friendly
%%   attribute(buy_topic, requires_relationship, 50)     %% minimum score
%%   attribute(buy_topic, requires_quest, find_artifact) %% quest must be complete
%%   attribute(buy_topic, requires_item, guild_badge)    %% player must carry item

dialogue_available(NPC, Player, Topic) :-
    relation(NPC, has_dialogue, Topic),
    dialogue_prereqs_met(NPC, Player, Topic).

dialogue_prereqs_met(NPC, Player, Topic) :-
    ( attribute(Topic, requires_friendly, true)
      -> npc_friendly(NPC, Player)
      ;  true ),
    ( attribute(Topic, requires_relationship, MinScore)
      -> ( relationship_level(NPC, Player, L), L >= MinScore )
      ;  true ),
    ( attribute(Topic, requires_quest, Quest)
      -> relation(Player, completed_quest, Quest)
      ;  true ),
    ( attribute(Topic, requires_item, Item)
      -> relation(Player, has_item, Item)
      ;  true ).
