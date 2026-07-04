%% Battery: world v1.0.0
%% Exports: world_time/1, world_weather/1, world_season/1, world_moon/1,
%%          is_daytime/0, is_nighttime/0

battery_module(world, '1.0.0', auto).

battery_export(world, 'world_time/1',    'world_time(Period) — current time period: dawn/day/dusk/night').
battery_export(world, 'world_weather/1', 'world_weather(Condition) — current weather: clear/rain/storm/fog/snow').
battery_export(world, 'world_season/1',  'world_season(Season) — current season: spring/summer/autumn/winter').
battery_export(world, 'world_moon/1',    'world_moon(Phase) — current moon phase: new/crescent/quarter/gibbous/full').
battery_export(world, 'is_daytime/0',    'is_daytime — succeeds during dawn and day periods').
battery_export(world, 'is_nighttime/0',  'is_nighttime — succeeds during dusk and night periods').

%% ── World State ──────────────────────────────────────────────────────────────
%%
%% Assert the current world state as attribute facts on the atom `world`:
%%   attribute(world, time_of_day,  night)    %% dawn/day/dusk/night
%%   attribute(world, hour,         22)        %% 0–23 (used if time_of_day not set)
%%   attribute(world, weather,      rain)      %% clear/rain/storm/fog/snow/blizzard
%%   attribute(world, season,       winter)    %% spring/summer/autumn/winter
%%   attribute(world, moon_phase,   full)      %% new/crescent/quarter/gibbous/full
%%
%% Defaults: day, clear, summer, crescent

%% world_time(+Period)
world_time(Period) :-
    attribute(world, time_of_day, Period), !.
world_time(Period) :-
    attribute(world, hour, H), !,
    hour_to_period(H, Period).
world_time(day).

hour_to_period(H, dawn)  :- H >= 5,  H < 7,  !.
hour_to_period(H, day)   :- H >= 7,  H < 18, !.
hour_to_period(H, dusk)  :- H >= 18, H < 21, !.
hour_to_period(_, night).

%% world_weather(?Condition)
world_weather(Condition) :-
    attribute(world, weather, Condition), !.
world_weather(clear).

%% world_season(?Season)
world_season(Season) :-
    attribute(world, season, Season), !.
world_season(summer).

%% world_moon(?Phase)
world_moon(Phase) :-
    attribute(world, moon_phase, Phase), !.
world_moon(crescent).

%% is_daytime/0
is_daytime :-
    world_time(T),
    ( T = dawn ; T = day ), !.

%% is_nighttime/0
is_nighttime :-
    world_time(T),
    ( T = dusk ; T = night ), !.
