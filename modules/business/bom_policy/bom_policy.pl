%% Battery: bom-policy v1.1.0
%% Exports: bom_violation/4, bom_compliant/2, part_risk/3, part_alternate/3,
%%          last_time_buy_due/4, bom_risk_summary/5, source_count/2, part_exempt/2

:- dynamic(part_exempt/2).

battery_module('bom-policy', '1.1.0', auto).

battery_export('bom-policy', 'bom_violation/4',     'bom_violation(Bom, Policy, Part, Reason) — Part on Bom fails Policy for Reason; one solution per reason').
battery_export('bom-policy', 'bom_compliant/2',     'bom_compliant(Bom, Policy) — no part on Bom has a blocking reason under Policy').
battery_export('bom-policy', 'part_risk/3',         'part_risk(Part, Policy, Level) — blocked, warn or ok for Part under Policy').
battery_export('bom-policy', 'part_alternate/3',    'part_alternate(Part, Policy, Alt) — Alt is a declared cross of Part that is not itself blocked under Policy').
battery_export('bom-policy', 'last_time_buy_due/4', 'last_time_buy_due(Bom, Policy, Part, DaysLeft) — a last-time-buy or end-of-life date on Part falls within the policy horizon; DaysLeft may be negative').
battery_export('bom-policy', 'bom_risk_summary/5',  'bom_risk_summary(Bom, Policy, Blocked, Warned, Ok) — how many parts on Bom land in each level').
battery_export('bom-policy', 'source_count/2',      'source_count(Part, N) — distinct suppliers Part is sourced from').
battery_export('bom-policy', 'part_exempt/2',       'part_exempt(Bom, Part) — HOOK: add clauses to waive Part on Bom (an approved deviation); an exempt part has no violations').

%% ── BOM Policy Data Model ─────────────────────────────────────────────────────
%%
%% A bill of materials and the parts on it:
%%   relation(board_a, includes, mcu_1)
%%   relation(board_a, includes, cap_7)
%%
%% What a part-intelligence feed knows about each part (one attribute each;
%% assert what you have, the rules cope with absence):
%%   attribute(mcu_1, lifecycle, active)          %% active | nrnd | eol | obsolete | unknown
%%   attribute(mcu_1, eol_day,   '2026-02-16')    %% estimated end-of-life
%%   attribute(mcu_1, ltb_day,   20400)           %% last-time-buy date
%%   attribute(mcu_1, rohs,      compliant)       %% any flag a policy may require
%%   attribute(mcu_1, reach,     compliant)
%%   attribute(mcu_1, aec_qualified, true)
%%   relation(mcu_1, sourced_from, supplier_x)    %% one per distinct supplier
%%   relation(mcu_1, cross, mcu_1b)               %% a form-fit-function alternate
%%
%% The clock:
%%   attribute(today, date, '2024-10-04')
%%
%% A date is an ISO YYYY-MM-DD date (an atom, a string, or a character list)
%% or an integer day number. An ISO date converts to days since 1970-01-01, so
%% an integer counted from that day compares with it. A value that is neither
%% reads as absent, the way an unrecognised flag value reads as missing.
%%
%% A policy (thresholds are facts; change one and nothing redeploys):
%%   relation(auto_policy, requires, rohs)                %% part must carry rohs = compliant/true/yes/qualified
%%   relation(auto_policy, requires, aec_qualified)
%%   attribute(auto_policy, min_sources, 2)               %% fewer distinct suppliers is a warning; default 2
%%   attribute(auto_policy, eol_horizon_days, 730)        %% eol/ltb inside this many days is due; default 365
%%   relation(auto_policy, blocks_lifecycle, obsolete)    %% default when none declared: obsolete
%%   relation(auto_policy, warns_lifecycle, nrnd)         %% default when none declared: nrnd and eol
%%
%% Waivers are a hook: assert part_exempt(board_a, cap_7) for an approved
%% deviation and the part drops out of every check.

%% ── Policy defaults ───────────────────────────────────────────────────────────

bom_policy_min_sources(Policy, N) :-
    ( attribute(Policy, min_sources, N0) -> N = N0 ; N = 2 ).

bom_policy_horizon(Policy, Days) :-
    ( attribute(Policy, eol_horizon_days, D0) -> Days = D0 ; Days = 365 ).

bom_policy_blocks(Policy, Stage) :-
    relation(Policy, blocks_lifecycle, Stage).
bom_policy_blocks(Policy, obsolete) :-
    \+ relation(Policy, blocks_lifecycle, _).

bom_policy_warns(Policy, Stage) :-
    relation(Policy, warns_lifecycle, Stage).
bom_policy_warns(Policy, Stage) :-
    \+ relation(Policy, warns_lifecycle, _),
    ( Stage = nrnd ; Stage = eol ).

part_exempt(_, _) :- fail.

%% ── Dates ─────────────────────────────────────────────────────────────────────
%%
%% Cut-free, with exclusive clauses, and made of goals a provenance interpreter
%% calls directly (number, atom, atom_chars, member, arithmetic), so why/2
%% follows a date the way it follows the rest of a reason. The string clause
%% is the exception: atomic/1 is not on that list. A DataGrout cell stores text
%% as atoms, so strings only arrive on standalone SWI.

bom_today(Day) :-
    attribute(today, date, Value),
    bom_day(Value, Day).

bom_day(Value, Value) :-
    number(Value).
bom_day(Value, Day) :-
    atom(Value),
    atom_chars(Value, Chars),
    bom_iso_day(Chars, Day).
bom_day(Value, Day) :-
    Value = [_|_],
    bom_iso_day(Value, Day).
%% A string, on an engine that has them apart from atoms and character lists.
bom_day(Value, Day) :-
    atomic(Value),
    \+ atom(Value),
    \+ number(Value),
    atom_chars(Value, Chars),
    bom_iso_day(Chars, Day).

bom_iso_day([Y1, Y2, Y3, Y4, '-', M1, M2, '-', D1, D2], Day) :-
    bom_digits([Y1, Y2, Y3, Y4], 0, Y),
    bom_digits([M1, M2], 0, M),
    bom_digits([D1, D2], 0, D),
    bom_month_days(Y, M, Len),
    D >= 1,
    D =< Len,
    bom_days_from_civil(Y, M, D, Day).

%% A rule rather than a fact, so why/2 does not list it among the evidence.
bom_digits([], N0, N) :-
    N = N0.
bom_digits([C|Cs], N0, N) :-
    member(C-V, ['0'-0, '1'-1, '2'-2, '3'-3, '4'-4, '5'-5, '6'-6, '7'-7, '8'-8, '9'-9]),
    N1 is N0 * 10 + V,
    bom_digits(Cs, N1, N).

bom_month_days(Y, 2, 29) :-
    bom_leap_year(Y).
bom_month_days(Y, 2, 28) :-
    \+ bom_leap_year(Y).
bom_month_days(_, M, Len) :-
    member(M-Len, [1-31, 3-31, 4-30, 5-31, 6-30, 7-31, 8-31, 9-30, 10-31, 11-30, 12-31]).

bom_leap_year(Y) :-
    Y mod 400 =:= 0.
bom_leap_year(Y) :-
    Y mod 4 =:= 0,
    Y mod 100 =\= 0.

%% Days from 1970-01-01 in the proleptic Gregorian calendar, counting years from
%% March so the leap day ends one. The 400 years added up front, one full cycle
%% of 146097 days taken off at the end, keep every operand of // non-negative
%% for years 0000 to 9999.
bom_days_from_civil(Y, M, D, Day) :-
    Y0 is Y - (14 - M) // 12 + 400,
    Era is Y0 // 400,
    YoE is Y0 - Era * 400,
    DoY is (153 * ((M + 9) mod 12) + 2) // 5 + D - 1,
    DoE is YoE * 365 + YoE // 4 - YoE // 100 + DoY,
    Day is Era * 146097 + DoE - 719468 - 146097.

%% ── source_count/2 ────────────────────────────────────────────────────────────

source_count(Part, N) :-
    findall(S, relation(Part, sourced_from, S), Ss),
    sort(Ss, Distinct),
    length(Distinct, N).

%% ── Reasons, by severity ──────────────────────────────────────────────────────
%%
%% blocking_reason/3 and warning_reason/3 are the whole rule set; every export
%% is a view over them. A reason is a term the caller can match on.

bom_blocking_reason(Part, Policy, lifecycle(Stage)) :-
    attribute(Part, lifecycle, Stage),
    bom_policy_blocks(Policy, Stage).

bom_blocking_reason(Part, Policy, missing(Flag)) :-
    relation(Policy, requires, Flag),
    \+ bom_flag_met(Part, Flag).

bom_blocking_reason(Part, _Policy, ltb_passed(Days)) :-
    attribute(Part, ltb_day, Ltb0),
    bom_day(Ltb0, Ltb),
    bom_today(Today),
    Today > Ltb,
    Days is Today - Ltb.

bom_warning_reason(Part, Policy, lifecycle(Stage)) :-
    attribute(Part, lifecycle, Stage),
    bom_policy_warns(Policy, Stage),
    \+ bom_policy_blocks(Policy, Stage).

bom_warning_reason(Part, _Policy, lifecycle(unknown)) :-
    \+ attribute(Part, lifecycle, _).

bom_warning_reason(Part, Policy, eol_within(Days)) :-
    attribute(Part, eol_day, Eol0),
    bom_day(Eol0, Eol),
    bom_today(Today),
    bom_policy_horizon(Policy, Horizon),
    Days is Eol - Today,
    Days >= 0,
    Days =< Horizon.

bom_warning_reason(Part, Policy, ltb_within(Days)) :-
    attribute(Part, ltb_day, Ltb0),
    bom_day(Ltb0, Ltb),
    bom_today(Today),
    bom_policy_horizon(Policy, Horizon),
    Days is Ltb - Today,
    Days >= 0,
    Days =< Horizon.

bom_warning_reason(Part, Policy, sources(N, Min)) :-
    bom_policy_min_sources(Policy, Min),
    source_count(Part, N),
    N < Min.

bom_flag_met(Part, Flag) :-
    attribute(Part, Flag, Value),
    bom_flag_ok_name(Name),
    bom_text_equal(Value, Name).

bom_flag_ok_name(compliant).
bom_flag_ok_name(true).
bom_flag_ok_name(yes).
bom_flag_ok_name(qualified).

%% A flag value arrives as whatever the feed and the host made of it: an atom,
%% a string on a host that keeps true/false as strings, a char list on an
%% engine without strings. Compare as text.
bom_text_equal(Value, Name) :-
    Value == Name, !.
bom_text_equal(Value, Name) :-
    atom_chars(Name, Chars),
    Value == Chars, !.
bom_text_equal(Value, Name) :-
    atom_codes(Name, Codes),
    catch(atom_codes(Value, Codes0), _, fail),
    Codes0 == Codes.

%% ── bom_violation/4 ───────────────────────────────────────────────────────────

bom_violation(Bom, Policy, Part, Reason) :-
    relation(Bom, includes, Part),
    \+ part_exempt(Bom, Part),
    ( bom_blocking_reason(Part, Policy, Reason)
    ; bom_warning_reason(Part, Policy, Reason)
    ).

%% ── bom_compliant/2 ───────────────────────────────────────────────────────────
%%
%% Warnings do not make a BOM non-compliant; blocking reasons do.

bom_compliant(Bom, Policy) :-
    \+ ( relation(Bom, includes, Part),
         \+ part_exempt(Bom, Part),
         bom_blocking_reason(Part, Policy, _) ).

%% ── part_risk/3 ───────────────────────────────────────────────────────────────

%% Cut-free on purpose: the provenance meta-interpreters (why/2, explain/2)
%% do not honour cuts, and a level decided by a cut explained as `ok` for a
%% blocked part. Negation is explained faithfully. Double negation keeps one
%% solution when several reasons hold.

part_risk(Part, Policy, blocked) :-
    \+ \+ bom_blocking_reason(Part, Policy, _).
part_risk(Part, Policy, warn) :-
    \+ bom_blocking_reason(Part, Policy, _),
    \+ \+ bom_warning_reason(Part, Policy, _).
part_risk(Part, Policy, ok) :-
    \+ bom_blocking_reason(Part, Policy, _),
    \+ bom_warning_reason(Part, Policy, _).

%% ── part_alternate/3 ──────────────────────────────────────────────────────────

part_alternate(Part, Policy, Alt) :-
    relation(Part, cross, Alt),
    \+ bom_blocking_reason(Alt, Policy, _).

%% ── last_time_buy_due/4 ───────────────────────────────────────────────────────
%%
%% The parts to act on: a last-time-buy date inside the horizon (or already
%% passed), else an end-of-life date inside the horizon with no usable
%% last-time-buy date of its own. DaysLeft is negative once the date has passed.

last_time_buy_due(Bom, Policy, Part, DaysLeft) :-
    relation(Bom, includes, Part),
    \+ part_exempt(Bom, Part),
    bom_today(Today),
    bom_policy_horizon(Policy, Horizon),
    (   attribute(Part, ltb_day, Ltb0),
        bom_day(Ltb0, Ltb)
    ->  DaysLeft is Ltb - Today
    ;   attribute(Part, eol_day, Eol0),
        bom_day(Eol0, Eol),
        DaysLeft is Eol - Today
    ),
    DaysLeft =< Horizon.

%% ── bom_risk_summary/5 ────────────────────────────────────────────────────────

bom_risk_summary(Bom, Policy, Blocked, Warned, Ok) :-
    findall(P, relation(Bom, includes, P), Ps0),
    sort(Ps0, Parts),
    bom_count_level(Parts, Bom, Policy, blocked, Blocked),
    bom_count_level(Parts, Bom, Policy, warn, Warned),
    bom_count_level(Parts, Bom, Policy, ok, Ok).

bom_count_level(Parts, Bom, Policy, Level, N) :-
    findall(P, ( member(P, Parts), \+ part_exempt(Bom, P), part_risk(P, Policy, Level) ), Ls),
    length(Ls, N).
