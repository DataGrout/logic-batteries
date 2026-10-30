%% Battery: scheduling v1.0.0
%% Exports: slot_available/3, booking_conflict/3, can_book/4,
%%          next_available_slot/3, resource_utilization/3

battery_module(scheduling, '1.0.0', auto).

battery_export(scheduling, 'slot_available/3',        'slot_available(Resource, Date, Slot) — the time slot is open for booking').
battery_export(scheduling, 'booking_conflict/3',      'booking_conflict(Resource, Date, Slot) — another booking blocks this slot').
battery_export(scheduling, 'can_book/4',              'can_book(Customer, Resource, Date, Slot) — customer meets all booking prerequisites for the given date and slot').
battery_export(scheduling, 'next_available_slot/3',   'next_available_slot(Resource, Date, Slot) — first open slot on or after Date').
battery_export(scheduling, 'resource_utilization/3',  'resource_utilization(Resource, Date, Pct) — percentage of slots booked on Date').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read, for a host to validate facts against and to build a
%% schema from (see CONTRIBUTING, "Input contract"). A resource is anything
%% with slots; a booking is what a resource's booked_at points to.

battery_input(scheduling, resource, attribute(slots), list, key,
    'Every bookable slot on the resource, e.g. [9,10,11,13]; utilisation is booked slots over its length.').
battery_input(scheduling, resource, relation(booked_at), ref(booking), optional,
    'One existing booking on the resource; it blocks its slot on its date.').
battery_input(scheduling, resource, attribute(advance_days), integer, default(0),
    'Fewest days ahead of today a booking may be made.').
battery_input(scheduling, resource, attribute(max_advance), integer, default(365),
    'Most days ahead of today a booking may be made; also how far next_available_slot searches.').
battery_input(scheduling, resource, attribute(requires_role), atom, optional,
    'When set, only a customer with this role can book the resource.').
battery_input(scheduling, booking, attribute(slot), integer, key,
    'The slot the booking holds, one of its resource''s slots.').
battery_input(scheduling, booking, attribute(date), date, required,
    'The day the booking is for.').
battery_input(scheduling, customer, attribute(role), atom, key,
    'The customer''s role, matched against a resource''s requires_role.').
battery_input(scheduling, fixed(today), attribute(absolute_days), days, key,
    'Today as a day count from 1970-01-01, the shared convention. Preferred over date.').
battery_input(scheduling, fixed(today), attribute(date), date, key,
    'Today as a day count, a YYYYMMDD integer or an ISO atom, when absolute_days is absent.').

%% ── Scheduling Data Model ─────────────────────────────────────────────────────
%%
%% Resource slots (what slots exist):
%%   attribute(meeting_room_a, slots, [9,10,11,13,14,15,16])   %% hour-of-day
%%   attribute(meeting_room_a, capacity, 10)
%%
%% Existing bookings:
%%   relation(meeting_room_a, booked_at, booking_001)
%%   attribute(booking_001, date, 20583)         %% a date (see Dates below)
%%   attribute(booking_001, slot, 10)
%%   attribute(booking_001, customer, customer_123)
%%
%% Booking rules:
%%   attribute(meeting_room_a, advance_days,  1)    %% must book at least 1 day ahead
%%   attribute(meeting_room_a, max_advance,  30)    %% cannot book more than 30 days out
%%   attribute(meeting_room_a, requires_role, premium)   %% optional role gate
%%
%% Current date, the convention every dated battery shares (a day count from
%% 1970-01-01), or the older `date` form:
%%   attribute(today, absolute_days, 20583)
%%   attribute(today, date, 20260510)
%%
%% Dates: a day count from 1970-01-01, a YYYYMMDD integer, or an ISO
%% 'YYYY-MM-DD' atom, in any mix. Each is turned into a day count before it is
%% compared or stepped, so the day after 20260531 is June 1st, not 20260532.
%%
%% Customer attributes:
%%   attribute(customer_123, role, premium)

%% ── Booking conflict detection ────────────────────────────────────────────────

booking_conflict(Resource, Date, Slot) :-
    relation(Resource, booked_at, Booking),
    attribute(Booking, date, Stored),
    attribute(Booking, slot, Slot),
    (   var(Date)
    ->  Date = Stored
    ;   sched_day(Date, Day),
        sched_day(Stored, Day)
    ).

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
    sched_today(Today),
    sched_day(Date, Day),
    ( attribute(Resource, advance_days, MinAdv) -> true ; MinAdv = 0 ),
    ( attribute(Resource, max_advance,  MaxAdv) -> true ; MaxAdv = 365 ),
    Day >= Today + MinAdv,
    Day =< Today + MaxAdv.

%% ── Next available slot ───────────────────────────────────────────────────────

%% next_available_slot(+Resource, +Date, -Slot)
%% Slot is the first open slot number on Date; recurses to Date+1 if none.
next_available_slot(Resource, Date, Slot) :-
    sched_day(Date, Day),
    sched_next_slot(Resource, Day, Slot).

sched_next_slot(Resource, Day, Slot) :-
    slot_available(Resource, Day, Slot), !.
sched_next_slot(Resource, Day, Slot) :-
    sched_today(Today),
    ( attribute(Resource, max_advance, MaxAdv) -> true ; MaxAdv = 365 ),
    Next is Day + 1,
    Next =< Today + MaxAdv,
    sched_next_slot(Resource, Next, Slot).

%% ── Resource utilization ─────────────────────────────────────────────────────

resource_utilization(Resource, Date, Pct) :-
    attribute(Resource, slots, Slots),
    length(Slots, Total),
    Total > 0,
    findall(S, (member(S, Slots), booking_conflict(Resource, Date, S)), Booked),
    length(Booked, BookedCount),
    Pct is round(BookedCount * 100 / Total).

%% ── Dates ─────────────────────────────────────────────────────────────────────

sched_today(Day) :-
    attribute(today, absolute_days, Day), !.
sched_today(Day) :-
    attribute(today, date, Value),
    sched_day(Value, Day).

%% sched_day(+Date, -Day): Day counts from 1970-01-01. A number of 10000101 or
%% more is read as YYYYMMDD; a smaller one is already a day count.
sched_day(Value, Day) :-
    integer(Value),
    Value >= 10000101, !,
    Y is Value // 10000,
    M is (Value // 100) mod 100,
    D is Value mod 100,
    sched_days_from_civil(Y, M, D, Day).
sched_day(Value, Value) :-
    number(Value), !.
sched_day(Value, Day) :-
    atom(Value),
    atom_chars(Value, [Y1, Y2, Y3, Y4, '-', M1, M2, '-', D1, D2]),
    number_chars(Y, [Y1, Y2, Y3, Y4]),
    number_chars(M, [M1, M2]),
    number_chars(D, [D1, D2]),
    sched_days_from_civil(Y, M, D, Day).

%% Proleptic Gregorian, the same count as invoice_rules and bom_policy.
sched_days_from_civil(Y, M, D, Day) :-
    Y0 is Y - (14 - M) // 12 + 400,
    Era is Y0 // 400,
    YoE is Y0 - Era * 400,
    DoY is (153 * ((M + 9) mod 12) + 2) // 5 + D - 1,
    DoE is YoE * 365 + YoE // 4 - YoE // 100 + DoY,
    Day is Era * 146097 + DoE - 719468 - 146097.
