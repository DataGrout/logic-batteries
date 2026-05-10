:- use_module(library(plunit)).

:- consult('../../modules/games/world/world').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_time_night :-
    assertz(attribute(world, time_of_day, night)).

setup_time_dawn :-
    assertz(attribute(world, time_of_day, dawn)).

setup_time_day :-
    assertz(attribute(world, time_of_day, day)).

setup_time_dusk :-
    assertz(attribute(world, time_of_day, dusk)).

setup_hour_22 :-
    assertz(attribute(world, hour, 22)).

setup_hour_6 :-
    assertz(attribute(world, hour, 6)).

setup_hour_12 :-
    assertz(attribute(world, hour, 12)).

setup_hour_19 :-
    assertz(attribute(world, hour, 19)).

setup_weather_storm :-
    assertz(attribute(world, weather, storm)).

setup_season_winter :-
    assertz(attribute(world, season, winter)).

setup_moon_full :-
    assertz(attribute(world, moon_phase, full)).

%% ── world_time/1 ─────────────────────────────────────────────────────────────

:- begin_tests(world_time).

test(explicit_night, [setup(setup_time_night), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == night).

test(explicit_dawn, [setup(setup_time_dawn), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == dawn).

test(explicit_day, [setup(setup_time_day), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == day).

test(explicit_dusk, [setup(setup_time_dusk), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == dusk).

test(hour_22_is_night, [setup(setup_hour_22), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == night).

test(hour_6_is_dawn, [setup(setup_hour_6), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == dawn).

test(hour_12_is_day, [setup(setup_hour_12), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == day).

test(hour_19_is_dusk, [setup(setup_hour_19), cleanup(clear_facts)]) :-
    world_time(T), assertion(T == dusk).

test(default_is_day, [cleanup(clear_facts)]) :-
    world_time(T), assertion(T == day).

:- end_tests(world_time).

%% ── is_daytime / is_nighttime ─────────────────────────────────────────────────

:- begin_tests(world_daytime).

test(dawn_is_daytime, [setup(setup_time_dawn), cleanup(clear_facts)]) :-
    assertion(is_daytime).

test(day_is_daytime, [setup(setup_time_day), cleanup(clear_facts)]) :-
    assertion(is_daytime).

test(night_not_daytime, [setup(setup_time_night), cleanup(clear_facts)]) :-
    assertion(\+ is_daytime).

test(dusk_is_nighttime, [setup(setup_time_dusk), cleanup(clear_facts)]) :-
    assertion(is_nighttime).

test(night_is_nighttime, [setup(setup_time_night), cleanup(clear_facts)]) :-
    assertion(is_nighttime).

test(day_not_nighttime, [setup(setup_time_day), cleanup(clear_facts)]) :-
    assertion(\+ is_nighttime).

:- end_tests(world_daytime).

%% ── world_weather / world_season / world_moon ────────────────────────────────

:- begin_tests(world_conditions).

test(explicit_weather, [setup(setup_weather_storm), cleanup(clear_facts)]) :-
    world_weather(W), assertion(W == storm).

test(default_weather_clear, [cleanup(clear_facts)]) :-
    world_weather(W), assertion(W == clear).

test(explicit_season, [setup(setup_season_winter), cleanup(clear_facts)]) :-
    world_season(S), assertion(S == winter).

test(default_season_summer, [cleanup(clear_facts)]) :-
    world_season(S), assertion(S == summer).

test(explicit_moon, [setup(setup_moon_full), cleanup(clear_facts)]) :-
    world_moon(M), assertion(M == full).

test(default_moon_crescent, [cleanup(clear_facts)]) :-
    world_moon(M), assertion(M == crescent).

:- end_tests(world_conditions).
