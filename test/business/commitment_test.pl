:- use_module(library(plunit)).

:- consult('../../modules/business/commitment/commitment').

%% Cases from the synthetic set with planted answers (C1-C10); today is
%% 20765 (2026-11-08). An answer the platform reports as unknown (no due date
%% of any kind, no owner) is a failure here.

setup_cmt_today :- assertz(attribute(today, absolute_days, 20765)).

fact(S, A, V) :- assertz(attribute(S, A, V)).

setup_c1 :- setup_cmt_today, fact(c1, owner, ravi), fact(c1, made_on, 20748), fact(c1, due, 20756).
setup_c2 :- setup_cmt_today, fact(c2, owner, mei), fact(c2, made_on, 20746), fact(c2, due_in_days, 30).
setup_c3 :- setup_cmt_today, fact(c3, owner, mei), fact(c3, due_in_days, 10).
setup_c4 :- setup_cmt_today, fact(c4, owner, jordan), fact(c4, event_on, 20828), fact(c4, days_before, 60).
setup_c5 :- setup_cmt_today, fact(c5, owner, ana), fact(c5, due, 20759), fact(c5, done, true), fact(c5, done_on, 20759).
setup_c6 :- setup_cmt_today, fact(c6, owner, ravi), fact(c6, due, 20756), fact(c6, done, true), fact(c6, done_on, 20757).
setup_c7 :- setup_cmt_today, fact(c7, owner, sam), fact(c7, due, 20754), fact(c7, cancelled, true).
setup_c8 :- setup_cmt_today, fact(c8, owner, sam), fact(c8, made_on, 20760).
setup_c10 :- setup_cmt_today, fact(c10, owner, lee), fact(c10, due, 20760).
setup_window :- setup_c2, fact(commitments, due_soon_days, 14).

:- begin_tests(commitment).

test(c1_stated_date_overdue, [setup(setup_c1), cleanup(clear_facts)]) :-
    assertion(due_on(c1, 20756)),
    assertion(overdue(c1)),
    assertion(overdue_days(c1, 9)).

test(c2_relative_to_made_on, [setup(setup_c2), cleanup(clear_facts)]) :-
    assertion(due_on(c2, 20776)),
    assertion(outstanding(c2)),
    assertion(\+ overdue(c2)),
    assertion(\+ due_soon(c2)).

%% Open point: due_in_days with no made_on gives no due day.
test(c3_relative_without_made_on, [setup(setup_c3), cleanup(clear_facts)]) :-
    assertion(\+ due_on(c3, _)),
    assertion(\+ overdue(c3)).

test(c4_notice_before_renewal, [setup(setup_c4), cleanup(clear_facts)]) :-
    assertion(due_on(c4, 20768)),
    assertion(due_soon(c4)),
    assertion(\+ overdue(c4)).

test(c5_done_on_time, [setup(setup_c5), cleanup(clear_facts)]) :-
    assertion(\+ outstanding(c5)),
    assertion(\+ overdue(c5)),
    assertion(\+ done_late(c5)).

test(c6_done_late, [setup(setup_c6), cleanup(clear_facts)]) :-
    assertion(done_late(c6)),
    assertion(\+ overdue(c6)).

test(c7_cancelled, [setup(setup_c7), cleanup(clear_facts)]) :-
    assertion(\+ outstanding(c7)),
    assertion(\+ overdue(c7)).

%% Unknown on the platform: no due date of any kind, so c8 is not a commitment.
test(c8_no_due_date, [setup(setup_c8), cleanup(clear_facts)]) :-
    assertion(\+ due_on(c8, _)),
    assertion(\+ overdue(c8)).

test(c10_done_not_mentioned, [setup(setup_c10), cleanup(clear_facts)]) :-
    assertion(overdue(c10)),
    assertion(overdue_days(c10, 5)),
    assertion(owner_of(c10, lee)).

test(due_soon_window_is_a_setting, [setup(setup_window), cleanup(clear_facts)]) :-
    assertion(due_soon(c2)).

test(not_overdue_has_zero_days, [setup(setup_c2), cleanup(clear_facts)]) :-
    assertion(overdue_days(c2, 0)).

:- end_tests(commitment).
