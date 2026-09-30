%% Battery: bom-policy v1.0.0
%% Exports: bom_violation/4, bom_compliant/2, part_risk/3, part_alternate/3,
%%          last_time_buy_due/4, bom_risk_summary/5, source_count/2, part_exempt/2

:- dynamic(part_exempt/2).

battery_module('bom-policy', '1.0.0', auto).

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
%%   attribute(mcu_1, eol_day,   20500)           %% estimated end-of-life, as a day number
%%   attribute(mcu_1, ltb_day,   20400)           %% last-time-buy date, as a day number
%%   attribute(mcu_1, rohs,      compliant)       %% any flag a policy may require
%%   attribute(mcu_1, reach,     compliant)
%%   attribute(mcu_1, aec_qualified, true)
%%   relation(mcu_1, sourced_from, supplier_x)    %% one per distinct supplier
%%   relation(mcu_1, cross, mcu_1b)               %% a form-fit-function alternate
%%
%% The clock:
%%   attribute(today, date, 20000)                %% same day unit as eol_day / ltb_day
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
    attribute(Part, ltb_day, Ltb),
    attribute(today, date, Today),
    Today > Ltb,
    Days is Today - Ltb.

bom_warning_reason(Part, Policy, lifecycle(Stage)) :-
    attribute(Part, lifecycle, Stage),
    bom_policy_warns(Policy, Stage),
    \+ bom_policy_blocks(Policy, Stage).

bom_warning_reason(Part, _Policy, lifecycle(unknown)) :-
    \+ attribute(Part, lifecycle, _).

bom_warning_reason(Part, Policy, eol_within(Days)) :-
    attribute(Part, eol_day, Eol),
    attribute(today, date, Today),
    bom_policy_horizon(Policy, Horizon),
    Days is Eol - Today,
    Days >= 0,
    Days =< Horizon.

bom_warning_reason(Part, Policy, ltb_within(Days)) :-
    attribute(Part, ltb_day, Ltb),
    attribute(today, date, Today),
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
%% passed), else an end-of-life date inside the horizon with no last-time-buy
%% date of its own. DaysLeft is negative once the date has passed.

last_time_buy_due(Bom, Policy, Part, DaysLeft) :-
    relation(Bom, includes, Part),
    \+ part_exempt(Bom, Part),
    attribute(today, date, Today),
    bom_policy_horizon(Policy, Horizon),
    (   attribute(Part, ltb_day, Ltb)
    ->  DaysLeft is Ltb - Today
    ;   attribute(Part, eol_day, Eol),
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
