%% Battery: duty v1.0.0
%% Requires: (nothing)
%% Exports: duty_conflict/3, unavailable/3, duty_limit/3, policy_gap/2,
%%          duty_length_ok/3, rest_before/3, rest_satisfied/2,
%%          cumulative_duty/4, rolling_limit_ok/3, duty_headroom/3,
%%          qualified_for/3, missing_qualification/4, role_matches/2,
%%          fit_for_duty/4, unfit_reason/5, available_staff/4

:- dynamic(relation/3).
:- dynamic(attribute/3).

battery_module('duty', '1.0.0', auto).

battery_export('duty', 'duty_conflict/3',
    'duty_conflict(Worker, Start, End) — an existing duty period of Worker overlaps [Start, End)').
battery_export('duty', 'unavailable/3',
    'unavailable(Entity, Start, End) — an unavailability window (leave, training, maintenance) of Entity overlaps [Start, End); works for people and equipment alike').
battery_export('duty', 'duty_limit/3',
    'duty_limit(Worker, Key, Value) — resolved policy value for Key (max_duty | min_rest | rolling_window | rolling_limit): worker override, else role, else global duty_policy').
battery_export('duty', 'policy_gap/2',
    'policy_gap(Worker, Key) — a policy Key that is not configured for Worker at any level; unconfigured limits are NOT enforced, so callers who need a complete policy should refuse when this succeeds').
battery_export('duty', 'duty_length_ok/3',
    'duty_length_ok(Worker, Start, End) — End - Start does not exceed max_duty (vacuously true when no max_duty is configured)').
battery_export('duty', 'rest_before/3',
    'rest_before(Worker, Start, Rest) — Rest is the time between the end of the latest duty period ending at or before Start and Start; fails when Worker has no prior duty').
battery_export('duty', 'rest_satisfied/2',
    'rest_satisfied(Worker, Start) — rest before Start is at least min_rest, or Worker has no prior duty, or no min_rest is configured').
battery_export('duty', 'cumulative_duty/4',
    'cumulative_duty(Worker, WindowStart, WindowEnd, Total) — total duty time of Worker inside [WindowStart, WindowEnd), clipping periods that straddle the window edges').
battery_export('duty', 'rolling_limit_ok/3',
    'rolling_limit_ok(Worker, Start, End) — existing duty in the rolling_window ending at End, plus the proposed [Start, End), does not exceed rolling_limit (vacuously true when either is unconfigured)').
battery_export('duty', 'duty_headroom/3',
    'duty_headroom(Worker, At, Headroom) — rolling_limit minus duty already accrued in the rolling_window ending at At; how much more duty Worker may take on ending at At').
battery_export('duty', 'qualified_for/3',
    'qualified_for(Worker, Task, At) — for every qualification kind Task requires, Worker holds one that has not expired at time At').
battery_export('duty', 'missing_qualification/4',
    'missing_qualification(Worker, Task, At, Kind) — a required qualification Kind that Worker does not hold, or holds only in expired form, at time At').
battery_export('duty', 'role_matches/2',
    'role_matches(Worker, Task) — Task has no needs_role, or Worker has that role').
battery_export('duty', 'fit_for_duty/4',
    'fit_for_duty(Worker, Task, Start, End) — every check passes: role, no duty conflict, not unavailable, duty length, rest, rolling limit, qualifications').
battery_export('duty', 'unfit_reason/5',
    'unfit_reason(Worker, Task, Start, End, Reason) — each reason Worker is not fit: role_mismatch(R) | duty_conflict(D) | unavailable(W) | duty_too_long(Len, Max) | insufficient_rest(Rest, Min) | rolling_limit_exceeded(Total, Limit) | missing_qualification(K)').
battery_export('duty', 'available_staff/4',
    'available_staff(Task, Start, End, Worker) — enumerates every rostered worker (has a role attribute) who is fit_for_duty for Task over [Start, End)').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%% Time is an integer in ONE consistent unit per namespace (minutes and unix
%% seconds are both fine). Intervals are half-open, written [Start, End):
%% the square bracket means Start is included, the parenthesis means End is
%% excluded, so a period ending at 1080 and one starting at 1080 do not touch.
%% Two intervals overlap iff S1 < E2 and E1 > S2 — the same convention the
%% `temporal` battery uses, so duty periods and windows asserted here also
%% answer temporal's event_concurrent/2 and gap_between/3.
%%
%% Roster and roles:
%%   attribute(alvarez, role, nurse).
%%   attribute(okafor,  role, orderly).
%%
%% Duty periods (past, current, and already-committed future):
%%   relation(alvarez, duty_period, d_101).
%%   attribute(d_101, start, 480).          %% 08:00 in minutes-of-day, say
%%   attribute(d_101, end,   1080).         %% 18:00
%%
%% Unavailability windows — leave, training, equipment maintenance:
%%   relation(alvarez, unavailable_during, w_7).
%%   relation(van_3,   unavailable_during, w_8).
%%   attribute(w_8, start, 360). attribute(w_8, end, 840).
%%   attribute(w_8, reason, maintenance).   %% optional, for explanation
%%
%% Policy limits, resolved worker → role → duty_policy (global):
%%   attribute(duty_policy, max_duty,       720).   %% 12 h in minutes
%%   attribute(duty_policy, min_rest,       660).   %% 11 h
%%   attribute(nurse,       rolling_window, 10080). %% 7 days
%%   attribute(nurse,       rolling_limit,  2880).  %% 48 h in any 7 days
%%   attribute(alvarez,     max_duty,       600).   %% per-worker override
%%
%% Qualifications and currency:
%%   relation(alvarez, holds, q_1).
%%   attribute(q_1, kind, icu_cert).
%%   attribute(q_1, expires, 20000).        %% optional; absent = does not expire
%%
%% Tasks (a shift, a job, an assignment):
%%   relation(t_42, requires, icu_cert).    %% zero or more kinds
%%   attribute(t_42, needs_role, nurse).    %% optional role filter

%% ── Interval helpers ─────────────────────────────────────────────────────────

duty_overlaps(S1, E1, S2, E2) :-
    S1 < E2,
    E1 > S2.

duty_window(W, S, E) :-
    attribute(W, start, S),
    attribute(W, end, E).

%% Length of the part of [S, E) that lies inside [WS, WE); 0 if disjoint.
duty_clipped(S, E, WS, WE, Len) :-
    CS is max(S, WS),
    CE is min(E, WE),
    ( CE > CS -> Len is CE - CS ; Len = 0 ).

%% Pure ISO maximum over a list with a seed (Scryer's library(lists) has no
%% max_list/2, and batteries must run identically on both engines).
duty_max_of([], Max, Max).
duty_max_of([X|Xs], Acc, Max) :-
    ( X > Acc -> Acc1 = X ; Acc1 = Acc ),
    duty_max_of(Xs, Acc1, Max).

%% ── Conflicts and unavailability ─────────────────────────────────────────────

duty_conflict(Worker, Start, End) :-
    relation(Worker, duty_period, D),
    duty_window(D, DS, DE),
    duty_overlaps(Start, End, DS, DE).

unavailable(Entity, Start, End) :-
    relation(Entity, unavailable_during, W),
    duty_window(W, WS, WE),
    duty_overlaps(Start, End, WS, WE).

%% ── Policy resolution ────────────────────────────────────────────────────────

duty_limit(Worker, Key, Value) :-
    duty_policy_key(Key),
    (   attribute(Worker, Key, V0)
    ->  Value = V0
    ;   attribute(Worker, role, Role), attribute(Role, Key, V1)
    ->  Value = V1
    ;   attribute(duty_policy, Key, V2)
    ->  Value = V2
    ).

duty_policy_key(max_duty).
duty_policy_key(min_rest).
duty_policy_key(rolling_window).
duty_policy_key(rolling_limit).

policy_gap(Worker, Key) :-
    duty_policy_key(Key),
    \+ duty_limit(Worker, Key, _).

%% ── Duty length ──────────────────────────────────────────────────────────────

duty_length_ok(Worker, Start, End) :-
    (   duty_limit(Worker, max_duty, Max)
    ->  End - Start =< Max
    ;   true
    ).

%% ── Rest ─────────────────────────────────────────────────────────────────────

%% Latest duty end at or before Start. Periods that run past Start are
%% conflicts, not rest, and are reported by duty_conflict/3 instead.
rest_before(Worker, Start, Rest) :-
    findall(DE,
        ( relation(Worker, duty_period, D),
          attribute(D, end, DE),
          DE =< Start ),
        Ends),
    Ends = [E0|Es],
    duty_max_of(Es, E0, Latest),
    Rest is Start - Latest.

rest_satisfied(Worker, Start) :-
    (   duty_limit(Worker, min_rest, Min)
    ->  (   rest_before(Worker, Start, Rest)
        ->  Rest >= Min
        ;   true
        )
    ;   true
    ).

%% ── Cumulative and rolling limits ────────────────────────────────────────────

cumulative_duty(Worker, WS, WE, Total) :-
    findall(Len,
        ( relation(Worker, duty_period, D),
          duty_window(D, DS, DE),
          duty_clipped(DS, DE, WS, WE, Len) ),
        Lens),
    sum_list(Lens, Total).

rolling_limit_ok(Worker, Start, End) :-
    (   duty_limit(Worker, rolling_window, Window),
        duty_limit(Worker, rolling_limit, Limit)
    ->  WS is End - Window,
        cumulative_duty(Worker, WS, End, Existing),
        duty_clipped(Start, End, WS, End, Proposed),
        Existing + Proposed =< Limit
    ;   true
    ).

duty_headroom(Worker, At, Headroom) :-
    duty_limit(Worker, rolling_window, Window),
    duty_limit(Worker, rolling_limit, Limit),
    WS is At - Window,
    cumulative_duty(Worker, WS, At, Existing),
    Headroom is Limit - Existing.

%% ── Qualifications ───────────────────────────────────────────────────────────

duty_holds_current(Worker, Kind, At) :-
    relation(Worker, holds, Q),
    attribute(Q, kind, Kind),
    (   attribute(Q, expires, Exp)
    ->  Exp > At
    ;   true
    ).

missing_qualification(Worker, Task, At, Kind) :-
    relation(Task, requires, Kind),
    \+ duty_holds_current(Worker, Kind, At).

qualified_for(Worker, Task, At) :-
    \+ missing_qualification(Worker, Task, At, _).

%% ── Role ─────────────────────────────────────────────────────────────────────

role_matches(Worker, Task) :-
    (   attribute(Task, needs_role, Role)
    ->  attribute(Worker, role, Role)
    ;   true
    ).

%% ── Verdict and explanation ──────────────────────────────────────────────────

fit_for_duty(Worker, Task, Start, End) :-
    role_matches(Worker, Task),
    \+ duty_conflict(Worker, Start, End),
    \+ unavailable(Worker, Start, End),
    duty_length_ok(Worker, Start, End),
    rest_satisfied(Worker, Start),
    rolling_limit_ok(Worker, Start, End),
    qualified_for(Worker, Task, Start).

unfit_reason(Worker, Task, _, _, role_mismatch(Role)) :-
    attribute(Task, needs_role, Role),
    \+ attribute(Worker, role, Role).
unfit_reason(Worker, _, Start, End, duty_conflict(D)) :-
    relation(Worker, duty_period, D),
    duty_window(D, DS, DE),
    duty_overlaps(Start, End, DS, DE).
unfit_reason(Worker, _, Start, End, unavailable(W)) :-
    relation(Worker, unavailable_during, W),
    duty_window(W, WS, WE),
    duty_overlaps(Start, End, WS, WE).
unfit_reason(Worker, _, Start, End, duty_too_long(Len, Max)) :-
    duty_limit(Worker, max_duty, Max),
    Len is End - Start,
    Len > Max.
unfit_reason(Worker, _, Start, _, insufficient_rest(Rest, Min)) :-
    duty_limit(Worker, min_rest, Min),
    rest_before(Worker, Start, Rest),
    Rest < Min.
unfit_reason(Worker, _, Start, End, rolling_limit_exceeded(Total, Limit)) :-
    duty_limit(Worker, rolling_window, Window),
    duty_limit(Worker, rolling_limit, Limit),
    WS is End - Window,
    cumulative_duty(Worker, WS, End, Existing),
    duty_clipped(Start, End, WS, End, Proposed),
    Total is Existing + Proposed,
    Total > Limit.
unfit_reason(Worker, Task, Start, _, missing_qualification(Kind)) :-
    missing_qualification(Worker, Task, Start, Kind).

%% ── Enumeration ──────────────────────────────────────────────────────────────

available_staff(Task, Start, End, Worker) :-
    attribute(Worker, role, _),
    fit_for_duty(Worker, Task, Start, End).
