:- use_module(library(plunit)).

:- consult('../../modules/reasoning/temporal/temporal').

%% (clear_facts/0 is in test/support/test_helpers.pl)
%% Timestamps are Unix-epoch integers throughout.

setup_ordered_events :-
    assertz(attribute(e1, timestamp, 1000)),
    assertz(attribute(e2, timestamp, 2000)),
    assertz(attribute(e3, timestamp, 3000)).

setup_interval_events :-
    assertz(attribute(meeting, start, 1000)),
    assertz(attribute(meeting, end,   2000)),
    assertz(attribute(call,    start, 1500)),
    assertz(attribute(call,    end,   2500)),
    assertz(attribute(after_meeting, start, 2100)),
    assertz(attribute(after_meeting, end,   3000)).

setup_deadline_task :-
    assertz(attribute(task_a, deadline, 1500)),
    assertz(attribute(task_b, deadline, 2500)).

setup_same_timestamp :-
    assertz(attribute(snap1, timestamp, 500)),
    assertz(attribute(snap2, timestamp, 500)).

setup_equal_timestamps :-
    assertz(attribute(a, timestamp, 100)),
    assertz(attribute(b, timestamp, 100)).

%% ── event_before/2 and event_after/2 ─────────────────────────────────────────

:- begin_tests(temporal_ordering).

test(event_before, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(event_before(e1, e2)),
    assertion(event_before(e1, e3)),
    assertion(event_before(e2, e3)).

test(event_not_before_later, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(\+ event_before(e2, e1)).

test(event_after_is_reverse, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(event_after(e3, e1)),
    assertion(event_after(e2, e1)).

:- end_tests(temporal_ordering).

%% ── event_within/3 ───────────────────────────────────────────────────────────

:- begin_tests(temporal_within).

test(event_within_range, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(event_within(e2, 500, 2500)).

test(event_at_boundary, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(event_within(e1, 1000, 2000)),
    assertion(event_within(e1, 500,  1000)).

test(event_outside_range, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(\+ event_within(e3, 100, 1500)).

:- end_tests(temporal_within).

%% ── event_concurrent/2 ───────────────────────────────────────────────────────

:- begin_tests(temporal_concurrent).

test(overlapping_events_concurrent, [setup(setup_interval_events), cleanup(clear_facts)]) :-
    assertion(event_concurrent(meeting, call)).

test(concurrent_symmetric, [setup(setup_interval_events), cleanup(clear_facts)]) :-
    assertion(event_concurrent(call, meeting)).

test(non_overlapping_not_concurrent, [setup(setup_interval_events), cleanup(clear_facts)]) :-
    assertion(\+ event_concurrent(meeting, after_meeting)).

:- end_tests(temporal_concurrent).

%% ── deadline_passed/2 and deadline_imminent/3 ─────────────────────────────────

:- begin_tests(temporal_deadlines).

test(deadline_passed_when_now_after, [setup(setup_deadline_task), cleanup(clear_facts)]) :-
    assertion(deadline_passed(task_a, 2000)).

test(deadline_not_passed_when_before, [setup(setup_deadline_task), cleanup(clear_facts)]) :-
    assertion(\+ deadline_passed(task_b, 2000)).

test(deadline_imminent_within_window, [setup(setup_deadline_task), cleanup(clear_facts)]) :-
    assertion(deadline_imminent(task_b, 2000, 600)).

test(deadline_not_imminent_outside_window, [setup(setup_deadline_task), cleanup(clear_facts)]) :-
    assertion(\+ deadline_imminent(task_b, 2000, 400)).

test(deadline_not_imminent_if_already_passed, [setup(setup_deadline_task), cleanup(clear_facts)]) :-
    assertion(\+ deadline_imminent(task_a, 2000, 1000)).

:- end_tests(temporal_deadlines).

%% ── duration_between/3 ───────────────────────────────────────────────────────

:- begin_tests(temporal_duration).

test(duration_forward, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    duration_between(e1, e3, D),
    assertion(D =:= 2000).

test(duration_backward_is_absolute, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    duration_between(e3, e1, D),
    assertion(D =:= 2000).

test(duration_zero_for_same_time, [setup(setup_same_timestamp), cleanup(clear_facts)]) :-
    duration_between(snap1, snap2, D),
    assertion(D =:= 0).

:- end_tests(temporal_duration).

%% ── gap_between/3 ────────────────────────────────────────────────────────────

:- begin_tests(temporal_gap).

test(positive_gap_between_non_overlapping, [nondet, setup(setup_interval_events), cleanup(clear_facts)]) :-
    gap_between(meeting, after_meeting, Gap),
    assertion(Gap =:= 100).

test(negative_gap_means_overlap, [nondet, setup(setup_interval_events), cleanup(clear_facts)]) :-
    gap_between(meeting, call, Gap),
    assertion(Gap < 0).

:- end_tests(temporal_gap).

%% ── events_in_order/1 ────────────────────────────────────────────────────────

:- begin_tests(temporal_sequence).

test(ordered_list_succeeds, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(events_in_order([e1, e2, e3])).

test(unordered_list_fails, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(\+ events_in_order([e3, e1, e2])).

test(single_event_is_ordered, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    assertion(events_in_order([e1])).

test(empty_list_is_ordered, [cleanup(clear_facts)]) :-
    assertion(events_in_order([])).

test(equal_timestamps_ok, [setup(setup_equal_timestamps), cleanup(clear_facts)]) :-
    assertion(events_in_order([a, b])).

:- end_tests(temporal_sequence).

%% ── next_event/3, latest_event/2, earliest_event/2 ───────────────────────────

:- begin_tests(temporal_selection).

test(next_event_after_threshold, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    next_event(1500, [e1, e2, e3], Next),
    assertion(Next == e2).

test(latest_event, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    latest_event([e1, e2, e3], L),
    assertion(L == e3).

test(earliest_event, [setup(setup_ordered_events), cleanup(clear_facts)]) :-
    earliest_event([e1, e2, e3], E),
    assertion(E == e1).

:- end_tests(temporal_selection).
