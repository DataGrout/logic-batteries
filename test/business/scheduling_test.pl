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

%% ── Dates: one day count underneath, any of the three forms on top ───────────

setup_full_on_0531 :-
    assertz(attribute(tiny_room, slots, [9])),
    assertz(attribute(tiny_room, max_advance, 30)),
    assertz(relation(tiny_room, booked_at, b_0531)),
    assertz(attribute(b_0531, date, 20260531)),
    assertz(attribute(b_0531, slot, 9)).

setup_absolute_0510 :-
    assertz(attribute(today, absolute_days, 20583)).   % 2026-05-10

:- begin_tests(scheduling_dates).

test(next_slot_rolls_over_a_month_end, [setup((setup_today_0510, setup_full_on_0531)), cleanup(clear_facts)]) :-
    %% The old YYYYMMDD arithmetic stepped to 20260532, which matches no booking
    %% and no calendar day. 2026-06-01 is day 20605.
    next_available_slot(tiny_room, 20260531, 9),
    assertion(\+ slot_available(tiny_room, 20260531, 9)),
    assertion(slot_available(tiny_room, 20605, 9)).

test(forms_agree_on_a_booking, [setup(setup_full_on_0531), cleanup(clear_facts)]) :-
    %% 2026-05-31 is day 20604.
    assertion(booking_conflict(tiny_room, 20604, 9)),
    assertion(booking_conflict(tiny_room, '2026-05-31', 9)),
    assertion(booking_conflict(tiny_room, 20260531, 9)).

test(absolute_today_sets_the_window, [setup((setup_room_with_slots, setup_advance_rules, setup_absolute_0510)), cleanup(clear_facts)]) :-
    assertion(can_book(anyone, meeting_room_a, 20260511, 9)),
    assertion(\+ can_book(anyone, meeting_room_a, 20260510, 9)),
    assertion(\+ can_book(anyone, meeting_room_a, '2026-06-10', 9)).

:- end_tests(scheduling_dates).
