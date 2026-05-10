%% Tether Module: progression v1.0.0
%% Exports: level_for_xp/2, xp_to_next_level/2, stat_at_level/3,
%%          unlock_available/2, can_prestige/1

tether_module(progression, '1.0.0', auto).

tether_export(progression, 'level_for_xp/2',     'level_for_xp(XP, Level) — Level reached with XP total experience').
tether_export(progression, 'xp_to_next_level/2', 'xp_to_next_level(Player, Needed) — XP gap from Player''s current position to next level').
tether_export(progression, 'stat_at_level/3',    'stat_at_level(Stat, Level, Value) — Value of Stat at Level').
tether_export(progression, 'unlock_available/2', 'unlock_available(Player, Unlock) — Unlock is available to Player at their current level').
tether_export(progression, 'can_prestige/1',     'can_prestige(Player) — Player meets all configured prestige conditions').

%% ── XP Curve Configuration ───────────────────────────────────────────────────
%%
%% Linear (default):
%%   attribute(xp_curve, type, linear)
%%   attribute(xp_curve, base_xp, 100)      %% cost to reach level 2 (default: 100)
%%   attribute(xp_curve, increment, 50)     %% added per subsequent level (default: 50)
%%   → level 2 needs 100 total, level 3 needs 250, level 4 needs 450, ...
%%
%% Exponential:
%%   attribute(xp_curve, type, exponential)
%%   attribute(xp_curve, base_xp, 100)      %% cost to reach level 2 (default: 100)
%%   attribute(xp_curve, multiplier, 1.5)   %% growth factor per level (default: 1.5)
%%   → level 2 needs 100, level 3 needs 250, level 4 needs 475, ...
%%
%% Custom breakpoints (cumulative XP to reach each level):
%%   attribute(level_2, xp_required, 100)
%%   attribute(level_3, xp_required, 300)
%%   attribute(level_4, xp_required, 700)
%%
%% Max level:
%%   attribute(xp_curve, max_level, 50)     %% default: 100

xp_curve_type(Type) :-
    attribute(xp_curve, type, Type), !.
xp_curve_type(linear).

xp_curve_max(Max) :-
    attribute(xp_curve, max_level, Max), !.
xp_curve_max(100).

%% cumulative_xp(+Level, -TotalXP): total XP to reach Level from level 1
cumulative_xp(1, 0) :- !.
cumulative_xp(Level, XP) :-
    Level > 1,
    atom_concat(level_, Level, Key),
    attribute(Key, xp_required, XP), !.
cumulative_xp(Level, Total) :-
    Level > 1,
    Prev is Level - 1,
    cumulative_xp(Prev, PrevTotal),
    xp_curve_type(Type),
    xp_step_cost(Type, Level, Step),
    Total is PrevTotal + Step.

xp_step_cost(linear, Level, Step) :-
    ( attribute(xp_curve, base_xp,    Base) -> true ; Base = 100 ),
    ( attribute(xp_curve, increment,  Inc)  -> true ; Inc  = 50  ),
    Step is Base + (Level - 2) * Inc.
xp_step_cost(exponential, Level, Step) :-
    ( attribute(xp_curve, base_xp,   Base) -> true ; Base = 100 ),
    ( attribute(xp_curve, multiplier, Mult) -> true ; Mult = 1.5 ),
    Step is round(Base * Mult ^ (Level - 2)).

%% level_for_xp(+XP, -Level): highest level reached with XP total experience
level_for_xp(XP, Level) :-
    xp_curve_max(Max),
    find_level(XP, 1, Max, Level).

find_level(XP, Current, Max, Level) :-
    Next is Current + 1,
    ( Next > Max
      -> Level = Current
      ;  ( cumulative_xp(Next, Threshold)
           -> ( XP >= Threshold
                -> find_level(XP, Next, Max, Level)
                ;  Level = Current )
           ;  Level = Current )   %% no threshold defined = custom curve ceiling
    ).

%% ── Player Helpers ───────────────────────────────────────────────────────────

player_total_xp(Player, XP) :-
    attribute(Player, xp, XP), !.
player_total_xp(_, 0).

%% player_level/2 — prefers explicit level attribute, falls back to XP derivation
player_level(Player, Level) :-
    attribute(Player, level, Level), !.
player_level(Player, Level) :-
    player_total_xp(Player, XP),
    level_for_xp(XP, Level).

%% xp_to_next_level(+Player, -Needed)
%% With asserted XP: gap from current XP to next level threshold.
%% With asserted level only: step cost from current level to next.
xp_to_next_level(Player, Needed) :-
    player_level(Player, Current),
    xp_curve_max(Max),
    Current < Max,
    Next is Current + 1,
    cumulative_xp(Next, NextThreshold),
    ( attribute(Player, xp, Have)
      -> Needed is NextThreshold - Have
      ;  cumulative_xp(Current, CurThreshold),
         Needed is NextThreshold - CurThreshold ).

%% ── Stat Scaling ─────────────────────────────────────────────────────────────
%%
%% Linear (default):
%%   attribute(hp, base_value, 100)    %% value at level 1
%%   attribute(hp, per_level, 10)      %% added per level above 1
%%   → hp at level 5 = 100 + 4*10 = 140
%%
%% Exponential:
%%   attribute(hp, scale, exponential)
%%   attribute(hp, base_value, 100)
%%   attribute(hp, multiplier, 1.1)
%%   → hp at level 5 = round(100 * 1.1^4) = 146
%%
%% Per-level override (highest priority):
%%   attribute(hp, level_5, 150)       %% exact value at level 5

stat_at_level(Stat, Level, Value) :-
    atom_concat(level_, Level, Key),
    attribute(Stat, Key, Value), !.
stat_at_level(Stat, Level, Value) :-
    attribute(Stat, scale, exponential), !,
    ( attribute(Stat, base_value, Base) -> true ; Base = 1 ),
    ( attribute(Stat, multiplier, Mult) -> true ; Mult = 1.1 ),
    Value is round(Base * Mult ^ (Level - 1)).
stat_at_level(Stat, Level, Value) :-
    ( attribute(Stat, base_value, Base) -> true ; Base = 0 ),
    ( attribute(Stat, per_level,  Inc)  -> true ; Inc  = 0 ),
    Value is Base + (Level - 1) * Inc.

%% ── Unlocks ──────────────────────────────────────────────────────────────────
%%
%% Assert unlock requirements:
%%   attribute(fireball, unlock_at_level, 10)
%%   attribute(fireball, unlock_requires_class, mage)    %% optional class gate

unlock_available(Player, Unlock) :-
    attribute(Unlock, unlock_at_level, ReqLevel),
    player_level(Player, PlayerLevel),
    PlayerLevel >= ReqLevel,
    ( attribute(Unlock, unlock_requires_class, ReqClass)
      -> attribute(Player, class, ReqClass)
      ;  true ).

%% ── Prestige ─────────────────────────────────────────────────────────────────
%%
%% Assert prestige requirements (at least one must be configured):
%%   attribute(prestige, requires_max_level, true)    %% must reach max level
%%   attribute(prestige, requires_level, 50)          %% or a specific level
%%   attribute(prestige, requires_quest, slay_dragon) %% optional quest gate

can_prestige(Player) :-
    ( attribute(prestige, requires_max_level, true)
      -> ( xp_curve_max(Max), player_level(Player, Max) )
      ;  ( attribute(prestige, requires_level, ReqLevel)
           -> ( player_level(Player, PL), PL >= ReqLevel )
           ;  fail )   %% no level requirement configured = no prestige
    ),
    ( attribute(prestige, requires_quest, Quest)
      -> relation(Player, completed_quest, Quest)
      ;  true ).
