%% Battery: temporal v1.0.0
%% Exports: event_before/2, event_after/2, event_within/3, event_concurrent/2,
%%          deadline_passed/2, deadline_imminent/3, duration_between/3,
%%          gap_between/3, events_in_order/1, next_event/3, latest_event/2, earliest_event/2

battery_module(temporal, '1.0.0', auto).

battery_export(temporal, 'event_before/2',
    'event_before(E1, E2) — E1 occurred before E2 (compares timestamp attributes)').
battery_export(temporal, 'event_after/2',
    'event_after(E1, E2) — E1 occurred after E2').
battery_export(temporal, 'event_within/3',
    'event_within(Event, Start, End) — Event timestamp falls in [Start, End]').
battery_export(temporal, 'event_concurrent/2',
    'event_concurrent(E1, E2) — E1 and E2 overlap (using start/end attributes)').
battery_export(temporal, 'deadline_passed/2',
    'deadline_passed(Entity, Now) — Entity deadline attribute < Now').
battery_export(temporal, 'deadline_imminent/3',
    'deadline_imminent(Entity, Now, Window) — deadline within Window time units').
battery_export(temporal, 'duration_between/3',
    'duration_between(E1, E2, D) — D is |timestamp(E2) - timestamp(E1)|').
battery_export(temporal, 'gap_between/3',
    'gap_between(E1, E2, Gap) — Gap is time between E1 end and E2 start (negative = overlap)').
battery_export(temporal, 'events_in_order/1',
    'events_in_order(Events) — Events list is non-decreasing by timestamp').
battery_export(temporal, 'next_event/3',
    'next_event(After, Events, Next) — Next is the earliest event in Events with timestamp > After').
battery_export(temporal, 'latest_event/2',
    'latest_event(Events, Latest) — Latest has the highest timestamp in Events').
battery_export(temporal, 'earliest_event/2',
    'earliest_event(Events, Earliest) — Earliest has the lowest timestamp in Events').

%% ── Ordering ─────────────────────────────────────────────────────────────────
%% Assert timestamps as: { type="attribute", entity="event_a", attribute="timestamp", value=1700000000 }

event_before(E1, E2) :-
    attribute(E1, timestamp, T1),
    attribute(E2, timestamp, T2),
    T1 < T2.

event_after(E1, E2) :- event_before(E2, E1).

event_within(Event, Start, End) :-
    attribute(Event, timestamp, T),
    T >= Start, T =< End.

%% event_concurrent/2 — two events have overlapping [start, end] intervals.
%% Assert: { attribute="start", value=N } and { attribute="end", value=M }
event_concurrent(E1, E2) :-
    attribute(E1, start, S1), attribute(E1, end, End1),
    attribute(E2, start, S2), attribute(E2, end, End2),
    S1 < End2, End1 > S2.

%% ── Deadlines ────────────────────────────────────────────────────────────────
%% Assert: { type="attribute", entity="task_a", attribute="deadline", value=1700000000 }

deadline_passed(Entity, Now) :-
    attribute(Entity, deadline, D),
    Now > D.

deadline_imminent(Entity, Now, Window) :-
    attribute(Entity, deadline, D),
    D >= Now,
    D - Now =< Window.

%% ── Duration and gaps ────────────────────────────────────────────────────────

duration_between(E1, E2, D) :-
    attribute(E1, timestamp, T1),
    attribute(E2, timestamp, T2),
    D is abs(T2 - T1).

%% gap_between/3 — time between end of E1 and start of E2.
%% Negative gap means the events overlap.
gap_between(E1, E2, Gap) :-
    attribute(E1, end, End1),
    attribute(E2, start, S2),
    Gap is S2 - End1.

%% ── Sequence reasoning ───────────────────────────────────────────────────────

events_in_order([]).
events_in_order([_]).
events_in_order([E1, E2 | Rest]) :-
    attribute(E1, timestamp, T1),
    attribute(E2, timestamp, T2),
    T1 =< T2,
    events_in_order([E2 | Rest]).

next_event(After, Events, Next) :-
    findall(T-E,
        (member(E, Events), attribute(E, timestamp, T), T > After),
        Pairs),
    sort(1, @<, Pairs, [_-Next|_]).

latest_event(Events, Latest) :-
    findall(T-E,
        (member(E, Events), attribute(E, timestamp, T)),
        Pairs),
    sort(1, @>, Pairs, [_-Latest|_]).

earliest_event(Events, Earliest) :-
    findall(T-E,
        (member(E, Events), attribute(E, timestamp, T)),
        Pairs),
    sort(1, @<, Pairs, [_-Earliest|_]).
