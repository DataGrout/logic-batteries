%% Battery: faction v1.0.0
%% Exports: faction_reputation/3, faction_standing/3, faction_allied/2,
%%          faction_at_war/2, faction_access/2

battery_module(faction, '1.0.0', auto).

battery_export(faction, 'faction_reputation/3', 'faction_reputation(Player, Faction, Rep) — numeric reputation score').
battery_export(faction, 'faction_standing/3',   'faction_standing(Player, Faction, Standing) — standing tier: hostile/unfriendly/neutral/friendly/honored/revered/exalted').
battery_export(faction, 'faction_allied/2',     'faction_allied(F1, F2) — factions are allied (symmetric)').
battery_export(faction, 'faction_at_war/2',     'faction_at_war(F1, F2) — factions are at war (symmetric)').
battery_export(faction, 'faction_access/2',     'faction_access(Player, Area) — Player meets the standing requirement to enter Area').

%% ── Reputation Data Model ─────────────────────────────────────────────────────
%%
%% Reputation keyed as player_faction:
%%   attribute(alice_traders_guild, score, 5000)
%%
%% Standing thresholds (global defaults; override by asserting per-faction):
%%   attribute(faction, exalted_threshold,    21000)   default
%%   attribute(faction, revered_threshold,    12000)   default
%%   attribute(faction, honored_threshold,     9000)   default
%%   attribute(faction, friendly_threshold,    3000)   default
%%   attribute(faction, unfriendly_threshold, -3000)   default
%%   attribute(faction, hostile_threshold,    -6000)   default
%%
%% Faction relationships:
%%   relation(traders_guild, allied_with,  merchants_guild)
%%   relation(bandits,       at_war_with,  kingdom)
%%
%% Area access gate:
%%   attribute(guild_hall, requires_faction,  traders_guild)
%%   attribute(guild_hall, requires_standing, friendly)       %% optional

faction_rep_key(Player, Faction, Key) :-
    atom_concat(Player, '_', Tmp),
    atom_concat(Tmp, Faction, Key).

%% faction_reputation(+Player, +Faction, -Rep)
faction_reputation(Player, Faction, Rep) :-
    faction_rep_key(Player, Faction, Key),
    attribute(Key, score, Rep), !.
faction_reputation(_, _, 0).

%% ── Standing thresholds ───────────────────────────────────────────────────────

threshold(exalted,    T) :- attribute(faction, exalted_threshold,    T), !.
threshold(exalted,    21000).
threshold(revered,    T) :- attribute(faction, revered_threshold,    T), !.
threshold(revered,    12000).
threshold(honored,    T) :- attribute(faction, honored_threshold,    T), !.
threshold(honored,    9000).
threshold(friendly,   T) :- attribute(faction, friendly_threshold,   T), !.
threshold(friendly,   3000).
threshold(unfriendly, T) :- attribute(faction, unfriendly_threshold, T), !.
threshold(unfriendly, -3000).
threshold(hostile,    T) :- attribute(faction, hostile_threshold,    T), !.
threshold(hostile,    -6000).

standing_rank(exalted,    6).
standing_rank(revered,    5).
standing_rank(honored,    4).
standing_rank(friendly,   3).
standing_rank(neutral,    2).
standing_rank(unfriendly, 1).
standing_rank(hostile,    0).

rep_to_standing(Rep, exalted)    :- threshold(exalted,    T), Rep >= T, !.
rep_to_standing(Rep, revered)    :- threshold(revered,    T), Rep >= T, !.
rep_to_standing(Rep, honored)    :- threshold(honored,    T), Rep >= T, !.
rep_to_standing(Rep, friendly)   :- threshold(friendly,   T), Rep >= T, !.
rep_to_standing(Rep, unfriendly) :- threshold(unfriendly, T), Rep < 0, Rep >= T, !.
rep_to_standing(Rep, hostile)    :- threshold(hostile,    T), Rep < T, !.
rep_to_standing(_, neutral).

%% faction_standing(+Player, +Faction, -Standing)
faction_standing(Player, Faction, Standing) :-
    faction_reputation(Player, Faction, Rep),
    rep_to_standing(Rep, Standing).

%% faction_allied(+F1, +F2)  (symmetric)
faction_allied(F1, F2) :- relation(F1, allied_with, F2), !.
faction_allied(F1, F2) :- relation(F2, allied_with, F1).

%% faction_at_war(+F1, +F2)  (symmetric)
faction_at_war(F1, F2) :- relation(F1, at_war_with, F2), !.
faction_at_war(F1, F2) :- relation(F2, at_war_with, F1).

%% faction_access(+Player, +Area)
faction_access(Player, Area) :-
    attribute(Area, requires_faction, Faction),
    faction_standing(Player, Faction, Standing),
    ( attribute(Area, requires_standing, ReqStanding)
      -> ( standing_rank(Standing, SR), standing_rank(ReqStanding, RR), SR >= RR )
      ;  Standing \= hostile ).
