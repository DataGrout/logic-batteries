:- use_module(library(plunit)).

:- consult('../../modules/business/scheduling/scheduling').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_room_with_slots :-
    assertz(attribute(meeting_room_a, slots, [9,10,11,13,14,15,16])).

setup_today_0510 :-
    assertz(attribute(today, date, 20260510)).

setup_booking_slot_10 :-
    assertz(relation(meeting_room_a, booked_at, booking_001)),
    assertz(attribute(booking_001, date, 20260510)),
    assertz(attribute(booking_001, slot, 10)),
    assertz(attribute(booking_001, customer, customer_a)).

setup_advance_rules :-
    assertz(attribute(meeting_room_a, advance_days, 1)),
    assertz(attribute(meeting_room_a, max_advance, 30)).

setup_role_gate :-
    assertz(attribute(meeting_room_a, requires_role, premium)).

setup_premium_customer :-
    assertz(attribute(customer_123, role, premium)).

setup_standard_customer :-
    true.  %% no role attribute

setup_room_open :-
    setup_room_with_slots,
    setup_today_0510,
    setup_advance_rules.

setup_room_one_booked :-
    setup_room_with_slots,
    setup_today_0510,
    setup_booking_slot_10.

setup_can_book_base :-
    setup_room_with_slots,
    setup_today_0510,
    setup_advance_rules.

setup_can_book_role_gated :-
    setup_room_with_slots,
    setup_today_0510,
    setup_advance_rules,
    setup_role_gate.

%% ── slot_available/3 ─────────────────────────────────────────────────────────

:- begin_tests(scheduling_slot_available).

test(slot_available_when_open, [setup(setup_room_open), cleanup(clear_facts)]) :-
    assertion(slot_available(meeting_room_a, 20260511, 9)).

test(slot_not_available_when_booked, [setup(setup_room_one_booked), cleanup(clear_facts)]) :-
    assertion(\+ slot_available(meeting_room_a, 20260510, 10)).

test(other_slot_still_available, [setup(setup_room_one_booked), cleanup(clear_facts)]) :-
    assertion(slot_available(meeting_room_a, 20260510, 9)).

test(slot_not_in_list, [setup(setup_room_open), cleanup(clear_facts)]) :-
    assertion(\+ slot_available(meeting_room_a, 20260511, 12)).

:- end_tests(scheduling_slot_available).

%% ── booking_conflict/3 ───────────────────────────────────────────────────────

:- begin_tests(scheduling_conflicts).

test(conflict_detected, [setup(setup_room_one_booked), cleanup(clear_facts)]) :-
    assertion(booking_conflict(meeting_room_a, 20260510, 10)).

test(no_conflict_different_slot, [setup(setup_room_one_booked), cleanup(clear_facts)]) :-
    assertion(\+ booking_conflict(meeting_room_a, 20260510, 11)).

test(no_conflict_different_date, [setup(setup_room_one_booked), cleanup(clear_facts)]) :-
    assertion(\+ booking_conflict(meeting_room_a, 20260511, 10)).

:- end_tests(scheduling_conflicts).

%% ── can_book/3 ───────────────────────────────────────────────────────────────

:- begin_tests(scheduling_can_book).

test(can_book_open_slot, [setup(setup_can_book_base), cleanup(clear_facts)]) :-
    assertion(can_book(anyone, meeting_room_a, 20260511, 9)).

test(cannot_book_same_day_when_advance_required, [setup(setup_can_book_base), cleanup(clear_facts)]) :-
    assertion(\+ can_book(anyone, meeting_room_a, 20260510, 9)).

test(premium_customer_can_book_gated_room, [setup((setup_can_book_role_gated, setup_premium_customer)), cleanup(clear_facts)]) :-
    assertion(can_book(customer_123, meeting_room_a, 20260511, 9)).

test(standard_cannot_book_gated_room, [setup(setup_can_book_role_gated), cleanup(clear_facts)]) :-
    assertion(\+ can_book(anyone, meeting_room_a, 20260511, 9)).

:- end_tests(scheduling_can_book).

%% ── resource_utilization/3 ───────────────────────────────────────────────────

:- begin_tests(scheduling_utilization).

test(zero_utilization_empty_day, [setup(setup_room_with_slots), cleanup(clear_facts)]) :-
    resource_utilization(meeting_room_a, 20260510, Pct), assertion(Pct == 0).

test(partial_utilization, [setup((setup_room_with_slots, setup_booking_slot_10)), cleanup(clear_facts)]) :-
    %% 1 of 7 slots booked → round(1*100/7) = 14
    resource_utilization(meeting_room_a, 20260510, Pct), assertion(Pct == 14).

:- end_tests(scheduling_utilization).
