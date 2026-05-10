%% Tether Module: npc-state v1.0.0
%% Exports: npc_friendly/2, npc_hostile/2, dialogue_available/3,
%%          faction_member/2, relationship_level/3

tether_module('npc-state', '1.0.0', auto).

tether_export('npc-state', 'npc_friendly/2',       'npc_friendly(NPC, Player) — NPC has a friendly disposition toward Player').
tether_export('npc-state', 'npc_hostile/2',        'npc_hostile(NPC, Player) — NPC has a hostile disposition toward Player').
tether_export('npc-state', 'dialogue_available/3', 'dialogue_available(NPC, Player, Topic) — Topic is an unlocked conversation option').
tether_export('npc-state', 'faction_member/2',     'faction_member(Entity, Faction) — Entity belongs to Faction').
tether_export('npc-state', 'relationship_level/3', 'relationship_level(NPC, Player, Level) — Level is the numeric relationship score').

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

relationship_level(NPC, Player, Level) :-
    relationship_key(NPC, Player, Key),
    attribute(Key, score, Level), !.
relationship_level(_, _, 0).

friendly_threshold(T) :-
    attribute(relationship, friendly_threshold, T), !.
friendly_threshold(25).

hostile_threshold(T) :-
    attribute(relationship, hostile_threshold, T), !.
hostile_threshold(-25).

%% npc_friendly(+NPC, +Player)
npc_friendly(NPC, _) :-
    attribute(NPC, always_friendly, true), !.
npc_friendly(NPC, Player) :-
    \+ attribute(NPC, always_hostile, true),
    relationship_level(NPC, Player, L),
    friendly_threshold(T),
    L >= T.

%% npc_hostile(+NPC, +Player)
npc_hostile(NPC, _) :-
    attribute(NPC, always_hostile, true), !.
npc_hostile(NPC, Player) :-
    \+ attribute(NPC, always_friendly, true),
    relationship_level(NPC, Player, L),
    hostile_threshold(T),
    L =< T.

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
