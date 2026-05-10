%% Tether Module: ai_director v1.0.0
%% Exports: spawn_eligible/2, difficulty_modifier/2, pacing_state/2,
%%          threat_level/2, director_event/2

tether_module(ai_director, '1.0.0', auto).

tether_export(ai_director, 'spawn_eligible/2',    'spawn_eligible(Enemy, Zone) — Enemy may spawn in Zone given current pacing and threat').
tether_export(ai_director, 'difficulty_modifier/2','difficulty_modifier(Zone, Modifier) — numeric multiplier for challenge in Zone (1.0 = baseline)').
tether_export(ai_director, 'pacing_state/2',      'pacing_state(Zone, State) — current pacing: calm/building/tense/peak/recovery').
tether_export(ai_director, 'threat_level/2',      'threat_level(Zone, Level) — current threat score for Zone').
tether_export(ai_director, 'director_event/2',    'director_event(Zone, Event) — Event is triggered by the director given current state').

%% ── AI Director Data Model ────────────────────────────────────────────────────
%%
%% Zone threat score (updated at runtime):
%%   attribute(forest_zone, threat, 45)        %% 0–100
%%
%% Pacing thresholds (defaults; override per-zone or globally):
%%   attribute(director, peak_threshold,     80)
%%   attribute(director, tense_threshold,    50)
%%   attribute(director, building_threshold, 20)
%%   attribute(director, recovery_threshold,  5)
%%
%% Enemy spawn rules:
%%   attribute(goblin,    min_threat, 10)     %% won't spawn below this threat
%%   attribute(goblin,    max_threat, 60)     %% won't spawn above this threat
%%   attribute(goblin,    spawn_zone, forest_zone)
%%   attribute(dragon,    min_threat, 70)
%%
%% Difficulty modifiers per pacing state:
%%   attribute(director, calm_modifier,     0.7)
%%   attribute(director, building_modifier, 1.0)
%%   attribute(director, tense_modifier,    1.3)
%%   attribute(director, peak_modifier,     1.6)
%%   attribute(director, recovery_modifier, 0.5)
%%
%% Director events:
%%   attribute(director, peak_event,     boss_spawn)
%%   attribute(director, recovery_event, treasure_chest)

%% ── threat_level/2 ───────────────────────────────────────────────────────────

threat_level(Zone, Level) :-
    attribute(Zone, threat, Level), !.
threat_level(_, 0).

%% ── pacing_state/2 ───────────────────────────────────────────────────────────

pacing_threshold(peak,     T) :- attribute(director, peak_threshold,     T), !.
pacing_threshold(peak,     80).
pacing_threshold(tense,    T) :- attribute(director, tense_threshold,    T), !.
pacing_threshold(tense,    50).
pacing_threshold(building, T) :- attribute(director, building_threshold, T), !.
pacing_threshold(building, 20).
pacing_threshold(recovery, T) :- attribute(director, recovery_threshold, T), !.
pacing_threshold(recovery, 5).

pacing_state(Zone, peak)     :- threat_level(Zone, L), pacing_threshold(peak,     T), L >= T, !.
pacing_state(Zone, tense)    :- threat_level(Zone, L), pacing_threshold(tense,    T), L >= T, !.
pacing_state(Zone, building) :- threat_level(Zone, L), pacing_threshold(building, T), L >= T, !.
pacing_state(Zone, recovery) :- threat_level(Zone, L), pacing_threshold(recovery, T), L < T, !.
pacing_state(_, calm).

%% ── difficulty_modifier/2 ────────────────────────────────────────────────────

state_modifier(peak,     M) :- attribute(director, peak_modifier,     M), !.
state_modifier(peak,     1.6).
state_modifier(tense,    M) :- attribute(director, tense_modifier,    M), !.
state_modifier(tense,    1.3).
state_modifier(building, M) :- attribute(director, building_modifier, M), !.
state_modifier(building, 1.0).
state_modifier(calm,     M) :- attribute(director, calm_modifier,     M), !.
state_modifier(calm,     0.7).
state_modifier(recovery, M) :- attribute(director, recovery_modifier, M), !.
state_modifier(recovery, 0.5).

difficulty_modifier(Zone, Modifier) :-
    pacing_state(Zone, State),
    state_modifier(State, Modifier).

%% ── spawn_eligible/2 ─────────────────────────────────────────────────────────

spawn_eligible(Enemy, Zone) :-
    ( attribute(Enemy, spawn_zone, Zone) -> true ; true ),
    threat_level(Zone, Threat),
    ( attribute(Enemy, min_threat, Min) -> Threat >= Min ; true ),
    ( attribute(Enemy, max_threat, Max) -> Threat =< Max ; true ),
    pacing_state(Zone, State),
    State \= recovery.

%% ── director_event/2 ─────────────────────────────────────────────────────────

director_event(Zone, Event) :-
    pacing_state(Zone, State),
    atom_concat(State, '_event', Attr),
    attribute(director, Attr, Event).
