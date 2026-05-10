%% Tether Module: scheduling v1.0.0
%% Exports: slot_available/3, booking_conflict/3, can_book/4,
%%          next_available_slot/3, resource_utilization/3

tether_module(scheduling, '1.0.0', auto).

tether_export(scheduling, 'slot_available/3',        'slot_available(Resource, Date, Slot) — the time slot is open for booking').
tether_export(scheduling, 'booking_conflict/3',      'booking_conflict(Resource, Date, Slot) — another booking blocks this slot').
tether_export(scheduling, 'can_book/4',              'can_book(Customer, Resource, Date, Slot) — customer meets all booking prerequisites for the given date and slot').
tether_export(scheduling, 'next_available_slot/3',   'next_available_slot(Resource, Date, Slot) — first open slot on or after Date').
tether_export(scheduling, 'resource_utilization/3',  'resource_utilization(Resource, Date, Pct) — percentage of slots booked on Date').

%% ── Scheduling Data Model ─────────────────────────────────────────────────────
%%
%% Resource slots (what slots exist):
%%   attribute(meeting_room_a, slots, [9,10,11,13,14,15,16])   %% hour-of-day
%%   attribute(meeting_room_a, capacity, 10)
%%
%% Existing bookings:
%%   relation(meeting_room_a, booked_at, booking_001)
%%   attribute(booking_001, date, 20260510)      %% YYYYMMDD integer
%%   attribute(booking_001, slot, 10)
%%   attribute(booking_001, customer, customer_123)
%%
%% Booking rules:
%%   attribute(meeting_room_a, advance_days,  1)    %% must book at least 1 day ahead
%%   attribute(meeting_room_a, max_advance,  30)    %% cannot book more than 30 days out
%%   attribute(meeting_room_a, requires_role, premium)   %% optional role gate
%%
%% Current date (assert at runtime — YYYYMMDD integer):
%%   attribute(today, date, 20260510)
%%
%% Customer attributes:
%%   attribute(customer_123, role, premium)

%% ── Booking conflict detection ────────────────────────────────────────────────

booking_conflict(Resource, Date, Slot) :-
    relation(Resource, booked_at, Booking),
    attribute(Booking, date, Date),
    attribute(Booking, slot, Slot).

%% slot_available(+Resource, +Date, ?Slot)
slot_available(Resource, Date, Slot) :-
    attribute(Resource, slots, Slots),
    member(Slot, Slots),
    \+ booking_conflict(Resource, Date, Slot).

%% ── Booking prerequisites ─────────────────────────────────────────────────────

can_book(Customer, Resource, Date, Slot) :-
    slot_available(Resource, Date, Slot),
    check_advance_window(Resource, Date),
    ( attribute(Resource, requires_role, Role)
      -> attribute(Customer, role, Role)
      ;  true ).

check_advance_window(Resource, Date) :-
    attribute(today, date, Today),
    ( attribute(Resource, advance_days, MinAdv) -> true ; MinAdv = 0 ),
    ( attribute(Resource, max_advance,  MaxAdv) -> true ; MaxAdv = 365 ),
    Date >= Today + MinAdv,
    Date =< Today + MaxAdv.

%% ── Next available slot ───────────────────────────────────────────────────────

%% next_available_slot(+Resource, +Date, -Slot)
%% Slot is the first open slot number on Date; recurses to Date+1 if none.
next_available_slot(Resource, Date, Slot) :-
    slot_available(Resource, Date, Slot), !.
next_available_slot(Resource, Date, Slot) :-
    attribute(today, date, Today),
    ( attribute(Resource, max_advance, MaxAdv) -> true ; MaxAdv = 365 ),
    NextDate is Date + 1,
    NextDate =< Today + MaxAdv,
    next_available_slot(Resource, NextDate, Slot).

%% ── Resource utilization ─────────────────────────────────────────────────────

resource_utilization(Resource, Date, Pct) :-
    attribute(Resource, slots, Slots),
    length(Slots, Total),
    Total > 0,
    findall(S, (member(S, Slots), booking_conflict(Resource, Date, S)), Booked),
    length(Booked, BookedCount),
    Pct is round(BookedCount * 100 / Total).
