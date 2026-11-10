%% Battery: commitment v1.0.0
%% Requires: (nothing)
%% Exports: due_on/2, outstanding/1, overdue/1, overdue_days/2, due_soon/1,
%%          done_late/1, owner_of/2

:- dynamic(attribute/3).

battery_module(commitment, '1.0.0', auto).

battery_export(commitment, 'due_on/2',
    'due_on(Commitment, Day) — the day Commitment falls due: its stated date, made_on plus due_in_days, or days_before an event').
battery_export(commitment, 'outstanding/1',
    'outstanding(Commitment) — Commitment is neither done nor cancelled').
battery_export(commitment, 'overdue/1',
    'overdue(Commitment) — Commitment is open and its due day is before today').
battery_export(commitment, 'overdue_days/2',
    'overdue_days(Commitment, Days) — how many days Commitment is overdue (0 when it is not)').
battery_export(commitment, 'due_soon/1',
    'due_soon(Commitment) — Commitment is open and falls due within the next due_soon_days days, today included').
battery_export(commitment, 'done_late/1',
    'done_late(Commitment) — Commitment was done after its due day').
battery_export(commitment, 'owner_of/2',
    'owner_of(Commitment, Owner) — Owner committed to it').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). One subject per
%% commitment: an action item, a promise in a message, or a notice date in a
%% contract. A due date can be stated, relative to when the commitment was made
%% ("within 30 days"), or measured back from an event ("60 days before
%% renewal"); any one of them makes the subject a commitment.

battery_input(commitment, commitment, attribute(owner), atom, required,
    'Who committed.').
battery_input(commitment, commitment, attribute(due), days, key,
    'The day it is due, when stated as a date.').
battery_input(commitment, commitment, attribute(due_in_days), integer, key,
    'Due this many days after made_on ("within 30 days").').
battery_input(commitment, commitment, attribute(made_on), days, conditional,
    'The day the commitment was made; due_in_days counts from it.').
battery_input(commitment, commitment, attribute(event_on), days, key,
    'The day of an event the commitment is measured against, such as a renewal date.').
battery_input(commitment, commitment, attribute(days_before), integer, optional,
    'Due this many days before event_on ("give notice 60 days before renewal"); absent, it is due on event_on.').
battery_input(commitment, commitment, attribute(done), bool, default(false),
    'true once done.').
battery_input(commitment, commitment, attribute(done_on), days, optional,
    'The day it was done.').
battery_input(commitment, commitment, attribute(cancelled), bool, default(false),
    'true once released or cancelled; a cancelled commitment is never overdue.').
battery_input(commitment, fixed(today), attribute(absolute_days), days, key,
    'Today as a day count from 1970-01-01, the shared convention.').
battery_input(commitment, fixed(commitments), attribute(due_soon_days), integer, default(7),
    'Days ahead within which an open commitment counts as due soon.').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%%   attribute(c1, owner, ravi)            attribute(c4, owner, jordan)
%%   attribute(c1, due, 20756)             attribute(c4, event_on, 20828)
%%   attribute(c2, owner, mei)             attribute(c4, days_before, 60)
%%   attribute(c2, made_on, 20746)         attribute(today, absolute_days, 20765)
%%   attribute(c2, due_in_days, 30)

%% ── Commitments and due days ─────────────────────────────────────────────────

cmt_target(C) :-
    ( var(C) -> cmt_commitments(Cs), member(C, Cs) ; cmt_keyed(C), ! ).

cmt_commitments(Cs) :-
    findall(C, cmt_keyed(C), Cs0),
    sort(Cs0, Cs).

cmt_keyed(C) :- attribute(C, due, _).
cmt_keyed(C) :- attribute(C, due_in_days, _).
cmt_keyed(C) :- attribute(C, event_on, _).

%% The stated date wins; then made_on + due_in_days; then the event date less
%% days_before. due_in_days without made_on gives no due day.
cmt_due(C, Day) :- attribute(C, due, Day), !.
cmt_due(C, Day) :-
    attribute(C, due_in_days, N),
    attribute(C, made_on, Made), !,
    Day is Made + N.
cmt_due(C, Day) :-
    attribute(C, event_on, Event), !,
    ( attribute(C, days_before, Before) -> Day is Event - Before ; Day = Event ).

cmt_today(T) :- attribute(today, absolute_days, T).

cmt_done(C) :- attribute(C, done, true).
cmt_cancelled(C) :- attribute(C, cancelled, true).

cmt_window(W) :-
    ( attribute(commitments, due_soon_days, W0) -> W = W0 ; W = 7 ).

%% ── Exports ──────────────────────────────────────────────────────────────────

%% due_on(?Commitment, ?Day)
due_on(C, Day) :-
    cmt_target(C),
    cmt_due(C, Day).

%% outstanding(?Commitment)
outstanding(C) :-
    cmt_target(C),
    \+ cmt_done(C),
    \+ cmt_cancelled(C).

%% overdue(?Commitment)
overdue(C) :-
    outstanding(C),
    cmt_due(C, Due),
    cmt_today(Today),
    Today > Due.

%% overdue_days(+Commitment, -Days)
overdue_days(C, Days) :-
    cmt_target(C),
    (   overdue(C)
    ->  cmt_due(C, Due), cmt_today(Today), Days is Today - Due
    ;   Days = 0
    ).

%% due_soon(?Commitment)
due_soon(C) :-
    outstanding(C),
    cmt_due(C, Due),
    cmt_today(Today),
    cmt_window(W),
    Today =< Due,
    Due - Today =< W.

%% done_late(?Commitment)
done_late(C) :-
    cmt_target(C),
    cmt_done(C),
    attribute(C, done_on, DoneOn),
    cmt_due(C, Due),
    DoneOn > Due.

%% owner_of(?Commitment, ?Owner)
owner_of(C, Owner) :-
    cmt_target(C),
    attribute(C, owner, Owner).
