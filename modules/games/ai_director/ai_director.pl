%% Battery: ai_director v1.0.1
%% Exports: spawn_eligible/2, difficulty_modifier/2, pacing_state/2,
%%          threat_level/2, director_event/2

battery_module(ai_director, '1.0.1', auto).

battery_export(ai_director, 'spawn_eligible/2',    'spawn_eligible(Enemy, Zone) — Enemy may spawn in Zone given current pacing and threat').
battery_export(ai_director, 'difficulty_modifier/2','difficulty_modifier(Zone, Modifier) — numeric multiplier for challenge in Zone (1.0 = baseline)').
battery_export(ai_director, 'pacing_state/2',      'pacing_state(Zone, State) — current pacing: calm/building/tense/peak/recovery').
battery_export(ai_director, 'threat_level/2',      'threat_level(Zone, Level) — current threat score for Zone').
battery_export(ai_director, 'director_event/2',    'director_event(Zone, Event) — Event is triggered by the director given current state').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). Thresholds,
%% modifiers and events are global, on the fixed subject `director`. The event
%% for each pacing state is an attribute named `<state>_event` (peak_event,
%% tense_event, building_event, calm_event, recovery_event), built from the
%% state at query time, so it cannot be declared here; absent, that state
%% triggers no event.

battery_input(ai_director, zone, attribute(threat), number, key,
    'The zone''s current threat score (0-100 by convention); a zone named only by spawn_zone reads as 0.').
battery_input(ai_director, enemy, attribute(spawn_zone), ref(zone), key,
    'A zone the enemy may spawn in; one fact per zone, and an enemy with none may spawn in any zone.').
battery_input(ai_director, enemy, attribute(min_threat), number, key,
    'The enemy spawns only where the threat is at least this.').
battery_input(ai_director, enemy, attribute(max_threat), number, key,
    'The enemy spawns only where the threat is at most this.').
battery_input(ai_director, fixed(director), attribute(peak_threshold), number, default(80),
    'Threat at or above which a zone is at peak.').
battery_input(ai_director, fixed(director), attribute(tense_threshold), number, default(50),
    'Threat at or above which a zone below peak is tense.').
battery_input(ai_director, fixed(director), attribute(building_threshold), number, default(20),
    'Threat at or above which a zone below tense is building.').
battery_input(ai_director, fixed(director), attribute(recovery_threshold), number, default(5),
    'Threat below which a zone is in recovery, where nothing spawns; between this and building is calm.').
battery_input(ai_director, fixed(director), attribute(peak_modifier), number, default(1.6),
    'Difficulty multiplier at peak.').
battery_input(ai_director, fixed(director), attribute(tense_modifier), number, default(1.3),
    'Difficulty multiplier when tense.').
battery_input(ai_director, fixed(director), attribute(building_modifier), number, default(1.0),
    'Difficulty multiplier when building.').
battery_input(ai_director, fixed(director), attribute(calm_modifier), number, default(0.7),
    'Difficulty multiplier when calm.').
battery_input(ai_director, fixed(director), attribute(recovery_modifier), number, default(0.5),
    'Difficulty multiplier in recovery.').

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

%% Unbound, Zone ranges over every zone the director knows: those with a
%% `threat` fact or named by some enemy's `spawn_zone`. Level is computed before
%% it is compared, so the 0 default never answers for a zone with a threat.
threat_level(Zone, Level) :-
    ( var(Zone) -> director_zone(Zone) ; true ),
    director_threat(Zone, Level0),
    Level = Level0.

director_threat(Zone, Level) :-
    attribute(Zone, threat, Level), !.
director_threat(_, 0).

director_zone(Zone) :-
    setof(Z, director_zone_fact(Z), Zones),
    member(Zone, Zones).

director_zone_fact(Zone) :- attribute(Zone, threat, _).
director_zone_fact(Zone) :- attribute(_, spawn_zone, Zone).

%% ── pacing_state/2 ───────────────────────────────────────────────────────────

pacing_threshold(peak,     T) :- attribute(director, peak_threshold,     T), !.
pacing_threshold(peak,     80).
pacing_threshold(tense,    T) :- attribute(director, tense_threshold,    T), !.
pacing_threshold(tense,    50).
pacing_threshold(building, T) :- attribute(director, building_threshold, T), !.
pacing_threshold(building, 20).
pacing_threshold(recovery, T) :- attribute(director, recovery_threshold, T), !.
pacing_threshold(recovery, 5).

%% The first matching state wins per zone, and State is computed before it is
%% compared: `pacing_state(Zone, calm)` is false for a zone at peak.
pacing_state(Zone, State) :-
    threat_level(Zone, Level),
    director_pacing(Level, State0),
    State = State0.

director_pacing(L, peak)     :- pacing_threshold(peak,     T), L >= T, !.
director_pacing(L, tense)    :- pacing_threshold(tense,    T), L >= T, !.
director_pacing(L, building) :- pacing_threshold(building, T), L >= T, !.
director_pacing(L, recovery) :- pacing_threshold(recovery, T), L < T, !.
director_pacing(_, calm).

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

%% An enemy with spawn_zone facts may spawn only in those zones; one with none
%% may spawn anywhere. (The earlier `-> true ; true` succeeded either way, so
%% spawn_zone was never enforced.) Unbound, Enemy ranges over every enemy with a
%% spawn rule, and Zone over its spawn zones, or over every known zone when it
%% has none.
spawn_eligible(Enemy, Zone) :-
    ( var(Enemy) -> director_enemy(Enemy) ; true ),
    ( attribute(Enemy, spawn_zone, _) -> attribute(Enemy, spawn_zone, Zone) ; true ),
    threat_level(Zone, Threat),
    ( attribute(Enemy, min_threat, Min) -> Threat >= Min ; true ),
    ( attribute(Enemy, max_threat, Max) -> Threat =< Max ; true ),
    pacing_state(Zone, State),
    State \= recovery.

director_enemy(Enemy) :-
    setof(E, director_enemy_fact(E), Enemies),
    member(Enemy, Enemies).

director_enemy_fact(Enemy) :- attribute(Enemy, spawn_zone, _).
director_enemy_fact(Enemy) :- attribute(Enemy, min_threat, _).
director_enemy_fact(Enemy) :- attribute(Enemy, max_threat, _).

%% ── director_event/2 ─────────────────────────────────────────────────────────

director_event(Zone, Event) :-
    pacing_state(Zone, State),
    atom_concat(State, '_event', Attr),
    attribute(director, Attr, Event).
