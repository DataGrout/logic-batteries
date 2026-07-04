%% Battery: prob-npc v1.0.0
%% Requires: npc-state, faction
%% Exports: trust_probability/3, will_share_info/3, will_assist/3,
%%          npc_price_modifier/3, disposition_probability/3

battery_module('prob-npc', '1.0.0', auto).

battery_export('prob-npc', 'trust_probability/3',
    'trust_probability(NPC, Player, P) — P is probability (0.0–1.0) NPC trusts Player based on faction standing and relationship').
battery_export('prob-npc', 'will_share_info/3',
    'will_share_info(NPC, Player, Topic) — probabilistic: NPC shares Topic with Player').
battery_export('prob-npc', 'will_assist/3',
    'will_assist(NPC, Player, Task) — probabilistic: NPC helps Player with Task').
battery_export('prob-npc', 'npc_price_modifier/3',
    'npc_price_modifier(NPC, Player, Mod) — Mod is a price multiplier (0.7–1.3) based on trust; below 1.0 = discount').
battery_export('prob-npc', 'disposition_probability/3',
    'disposition_probability(NPC, Player, P) — P is overall probability NPC responds positively to Player').

%% ── Trust probability by faction standing ─────────────────────────────────
%% Requires faction battery (faction_standing/3) and npc-state battery.
%%
%% Assert NPC faction membership:
%%   attribute(merchant_npc, faction, traders_guild)
%%
%% Assert player faction reputation (via faction battery):
%%   attribute(alice_traders_guild, score, 5000)   → standing: friendly

0.90::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, exalted).

0.80::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, revered).

0.70::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, honored).

0.55::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, friendly).

0.35::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, neutral).

0.10::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, unfriendly).

0.02::npc_trusts(NPC, Player) :-
    attribute(NPC, faction, Faction),
    faction_standing(Player, Faction, hostile).

%% Personal relationship boosts trust above faction baseline
0.75::npc_trusts(NPC, Player) :-
    \+ attribute(NPC, faction, _),
    npc_friendly(NPC, Player).

0.20::npc_trusts(NPC, Player) :-
    \+ attribute(NPC, faction, _),
    \+ npc_friendly(NPC, Player),
    \+ npc_hostile(NPC, Player).

%% ── Information sharing ─────────────────────────────────────────────────────
%% Assert topics:
%%   relation(merchant_npc, knows_topic, trade_routes)
%%   attribute(trade_routes, sensitivity, low)    %% low | medium | high | secret

0.90::will_share_info(NPC, Player, Topic) :-
    relation(NPC, knows_topic, Topic),
    \+ attribute(Topic, sensitivity, _),
    npc_trusts(NPC, Player).

0.75::will_share_info(NPC, Player, Topic) :-
    relation(NPC, knows_topic, Topic),
    attribute(Topic, sensitivity, low),
    npc_trusts(NPC, Player).

0.50::will_share_info(NPC, Player, Topic) :-
    relation(NPC, knows_topic, Topic),
    attribute(Topic, sensitivity, medium),
    npc_trusts(NPC, Player),
    relationship_level(NPC, Player, L), L >= 25.

0.25::will_share_info(NPC, Player, Topic) :-
    relation(NPC, knows_topic, Topic),
    attribute(Topic, sensitivity, high),
    npc_trusts(NPC, Player),
    relationship_level(NPC, Player, L), L >= 60.

0.05::will_share_info(NPC, Player, Topic) :-
    relation(NPC, knows_topic, Topic),
    attribute(Topic, sensitivity, secret),
    npc_trusts(NPC, Player),
    relationship_level(NPC, Player, L), L >= 90.

%% ── Task assistance ─────────────────────────────────────────────────────────
%% Assert tasks the NPC can assist with:
%%   relation(blacksmith_npc, can_assist, forge_weapon)
%%   attribute(forge_weapon, assistance_cost, high)   %% low | medium | high

0.90::will_assist(NPC, Player, Task) :-
    relation(NPC, can_assist, Task),
    \+ attribute(Task, assistance_cost, _),
    npc_trusts(NPC, Player).

0.80::will_assist(NPC, Player, Task) :-
    relation(NPC, can_assist, Task),
    attribute(Task, assistance_cost, low),
    npc_trusts(NPC, Player).

0.50::will_assist(NPC, Player, Task) :-
    relation(NPC, can_assist, Task),
    attribute(Task, assistance_cost, medium),
    npc_trusts(NPC, Player),
    relationship_level(NPC, Player, L), L >= 25.

0.20::will_assist(NPC, Player, Task) :-
    relation(NPC, can_assist, Task),
    attribute(Task, assistance_cost, high),
    npc_trusts(NPC, Player),
    relationship_level(NPC, Player, L), L >= 50.

%% ── Deterministic accessors ─────────────────────────────────────────────────

%% trust_probability/3 — numeric trust score without ProbLog inference
trust_probability(NPC, Player, P) :-
    ( attribute(NPC, faction, Faction)
    -> faction_standing(Player, Faction, Standing),
       standing_trust_base(Standing, FactionP)
    ;  FactionP = 0.35 ),
    relationship_level(NPC, Player, RelLevel),
    RelBoost is RelLevel / 500.0,
    P is min(0.99, max(0.01, FactionP + RelBoost)).

standing_trust_base(exalted,    0.90).
standing_trust_base(revered,    0.80).
standing_trust_base(honored,    0.70).
standing_trust_base(friendly,   0.55).
standing_trust_base(neutral,    0.35).
standing_trust_base(unfriendly, 0.10).
standing_trust_base(hostile,    0.02).

%% npc_price_modifier/3
%% trusted player gets a discount; distrusted gets a markup
%% Mod < 1.0 = cheaper prices, Mod > 1.0 = more expensive

npc_price_modifier(NPC, Player, Mod) :-
    trust_probability(NPC, Player, P),
    Mod is max(0.70, min(1.30, 1.0 - (P - 0.50) * 0.40)).

%% disposition_probability/3 — overall positive response probability
disposition_probability(NPC, Player, P) :-
    trust_probability(NPC, Player, TrustP),
    ( npc_friendly(NPC, Player) -> FriendBoost = 0.15 ; FriendBoost = 0.0 ),
    ( npc_hostile(NPC, Player)  -> HostilePen  = 0.30 ; HostilePen  = 0.0 ),
    P is min(0.99, max(0.01, TrustP + FriendBoost - HostilePen)).
