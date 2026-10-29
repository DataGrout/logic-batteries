:- use_module(library(plunit)).

:- consult('../../modules/business/bom_policy/bom_policy').

%% ── Hook management ──────────────────────────────────────────────────────────

bom_reset_hooks :-
    retractall(part_exempt(_, _)),
    assertz((part_exempt(_, _) :- fail)).

bom_cleanup_all :-
    clear_facts,
    bom_reset_hooks.

%% ── Setup predicates ─────────────────────────────────────────────────────────

%% Day numbers, not calendar dates: today is day 20000.
setup_today :-
    assertz(attribute(today, date, 20000)).

%% A policy for an automotive board: rohs and aec_qualified required, two
%% sources, a two-year horizon; lifecycle defaults (obsolete blocks, nrnd and
%% eol warn).
setup_auto_policy :-
    assertz(relation(auto, requires, rohs)),
    assertz(relation(auto, requires, aec_qualified)),
    assertz(attribute(auto, min_sources, 2)),
    assertz(attribute(auto, eol_horizon_days, 730)).

%% A clean part: active, dual sourced, both flags, no dates.
setup_clean_part :-
    assertz(relation(board, includes, mcu_ok)),
    assertz(attribute(mcu_ok, lifecycle, active)),
    assertz(attribute(mcu_ok, rohs, compliant)),
    assertz(attribute(mcu_ok, aec_qualified, true)),
    assertz(relation(mcu_ok, sourced_from, dist_a)),
    assertz(relation(mcu_ok, sourced_from, dist_b)).

%% Obsolete, with a cross that is itself fine.
setup_obsolete_part :-
    assertz(relation(board, includes, reg_old)),
    assertz(attribute(reg_old, lifecycle, obsolete)),
    assertz(attribute(reg_old, rohs, compliant)),
    assertz(attribute(reg_old, aec_qualified, true)),
    assertz(relation(reg_old, sourced_from, dist_a)),
    assertz(relation(reg_old, sourced_from, dist_b)),
    assertz(relation(reg_old, cross, reg_new)),
    assertz(attribute(reg_new, lifecycle, active)),
    assertz(attribute(reg_new, rohs, compliant)),
    assertz(attribute(reg_new, aec_qualified, true)).

%% Active but missing the automotive qualification and single sourced.
setup_unqualified_part :-
    assertz(relation(board, includes, cap_x)),
    assertz(attribute(cap_x, lifecycle, active)),
    assertz(attribute(cap_x, rohs, compliant)),
    assertz(relation(cap_x, sourced_from, dist_a)).

%% End of life 400 days out, last-time-buy 100 days out.
setup_eol_soon_part :-
    assertz(relation(board, includes, fet_eol)),
    assertz(attribute(fet_eol, lifecycle, eol)),
    assertz(attribute(fet_eol, rohs, compliant)),
    assertz(attribute(fet_eol, aec_qualified, true)),
    assertz(relation(fet_eol, sourced_from, dist_a)),
    assertz(relation(fet_eol, sourced_from, dist_b)),
    assertz(attribute(fet_eol, eol_day, 20400)),
    assertz(attribute(fet_eol, ltb_day, 20100)).

%% Last-time-buy already passed.
setup_ltb_passed_part :-
    assertz(relation(board, includes, osc_late)),
    assertz(attribute(osc_late, lifecycle, eol)),
    assertz(attribute(osc_late, rohs, compliant)),
    assertz(attribute(osc_late, aec_qualified, true)),
    assertz(relation(osc_late, sourced_from, dist_a)),
    assertz(relation(osc_late, sourced_from, dist_b)),
    assertz(attribute(osc_late, ltb_day, 19900)).

setup_waiver :-
    assertz(part_exempt(board, reg_old)).

%% No lifecycle attribute at all.
setup_mystery_part :-
    assertz(relation(board, includes, mystery)),
    assertz(attribute(mystery, rohs, compliant)),
    assertz(attribute(mystery, aec_qualified, true)),
    assertz(relation(mystery, sourced_from, a)),
    assertz(relation(mystery, sourced_from, b)).

%% A strict policy blocks eol as well; a lax one warns on obsolete only and
%% blocks no stage.
setup_strict_and_lax :-
    assertz(relation(strict, blocks_lifecycle, obsolete)),
    assertz(relation(strict, blocks_lifecycle, eol)),
    assertz(relation(lax, warns_lifecycle, obsolete)),
    assertz(relation(lax, blocks_lifecycle, none)).

%% A part for a policy with no tunables declared.
setup_plain_part :-
    assertz(relation(board, includes, p)),
    assertz(attribute(p, lifecycle, active)),
    assertz(relation(p, sourced_from, only)),
    assertz(attribute(p, eol_day, 20500)).

%% A cross that is itself obsolete.
setup_dead_cross :-
    assertz(relation(reg_old, cross, reg_dead)),
    assertz(attribute(reg_dead, lifecycle, obsolete)).

setup_bad_part :-
    assertz(relation(board, includes, bad)),
    assertz(attribute(bad, lifecycle, obsolete)).

%% ── bom_violation/4 and part_risk/3 ─────────────────────────────────────────

:- begin_tests(bom_policy_violations).

test(clean_part_has_no_violation, [setup((setup_today, setup_auto_policy, setup_clean_part)), cleanup(bom_cleanup_all)]) :-
    assertion(\+ bom_violation(board, auto, mcu_ok, _)),
    assertion(part_risk(mcu_ok, auto, ok)).

test(obsolete_is_blocked, [setup((setup_today, setup_auto_policy, setup_obsolete_part)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_violation(board, auto, reg_old, lifecycle(obsolete))),
    assertion(part_risk(reg_old, auto, blocked)).

test(missing_flag_and_single_source, [setup((setup_today, setup_auto_policy, setup_unqualified_part)), cleanup(bom_cleanup_all)]) :-
    findall(R, bom_violation(board, auto, cap_x, R), Rs),
    assertion(memberchk(missing(aec_qualified), Rs)),
    assertion(memberchk(sources(1, 2), Rs)),
    assertion(part_risk(cap_x, auto, blocked)).

test(eol_inside_horizon_warns, [setup((setup_today, setup_auto_policy, setup_eol_soon_part)), cleanup(bom_cleanup_all)]) :-
    findall(R, bom_violation(board, auto, fet_eol, R), Rs),
    assertion(memberchk(lifecycle(eol), Rs)),
    assertion(memberchk(eol_within(400), Rs)),
    assertion(memberchk(ltb_within(100), Rs)),
    assertion(part_risk(fet_eol, auto, warn)).

test(ltb_passed_is_blocked, [setup((setup_today, setup_auto_policy, setup_ltb_passed_part)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_violation(board, auto, osc_late, ltb_passed(100))),
    assertion(part_risk(osc_late, auto, blocked)).

test(no_lifecycle_data_is_a_warning, [setup((setup_today, setup_auto_policy, setup_mystery_part)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_violation(board, auto, mystery, lifecycle(unknown))),
    assertion(part_risk(mystery, auto, warn)).

test(waived_part_has_no_violations, [setup((setup_today, setup_auto_policy, setup_obsolete_part, setup_waiver)), cleanup(bom_cleanup_all)]) :-
    assertion(\+ bom_violation(board, auto, reg_old, _)),
    assertion(bom_compliant(board, auto)).

:- end_tests(bom_policy_violations).

%% ── Policy tunables ──────────────────────────────────────────────────────────

:- begin_tests(bom_policy_tunables).

test(lifecycle_lists_override_defaults, [setup((setup_today, setup_eol_soon_part, setup_strict_and_lax)), cleanup(bom_cleanup_all)]) :-
    assertion(part_risk(fet_eol, strict, blocked)),
    %% eol is neither blocked nor warned under lax, but the dates inside the
    %% default horizon still warn.
    assertion(\+ bom_violation(board, lax, fet_eol, lifecycle(_))),
    assertion(part_risk(fet_eol, lax, warn)).

test(default_min_sources_is_two_and_horizon_a_year, [setup((setup_today, setup_plain_part)), cleanup(bom_cleanup_all)]) :-
    findall(R, bom_violation(board, plain, p, R), Rs),
    assertion(memberchk(sources(1, 2), Rs)),
    assertion(\+ memberchk(eol_within(_), Rs)).

:- end_tests(bom_policy_tunables).

%% ── part_alternate/3, last_time_buy_due/4, bom_risk_summary/5 ───────────────

:- begin_tests(bom_policy_actions).

test(alternate_must_not_be_blocked, [setup((setup_today, setup_auto_policy, setup_obsolete_part, setup_dead_cross)), cleanup(bom_cleanup_all)]) :-
    assertion(part_alternate(reg_old, auto, reg_new)),
    %% A cross that is itself obsolete is no alternate.
    assertion(\+ part_alternate(reg_old, auto, reg_dead)).

test(last_time_buy_due_lists_dates_in_horizon, [setup((setup_today, setup_auto_policy, setup_clean_part, setup_eol_soon_part, setup_ltb_passed_part)), cleanup(bom_cleanup_all)]) :-
    findall(P-D, last_time_buy_due(board, auto, P, D), Due0),
    sort(Due0, Due),
    assertion(Due == [fet_eol-100, osc_late-(-100)]).

test(summary_counts_each_part_once, [setup((setup_today, setup_auto_policy, setup_clean_part, setup_obsolete_part, setup_unqualified_part, setup_eol_soon_part)), cleanup(bom_cleanup_all)]) :-
    bom_risk_summary(board, auto, B, W, O),
    assertion(B-W-O == 2-1-1).

test(bom_compliant_ignores_warnings, [setup((setup_today, setup_auto_policy, setup_clean_part, setup_eol_soon_part)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_compliant(board, auto)).

test(bom_compliant_fails_on_a_blocked_part, [setup((setup_today, setup_auto_policy, setup_clean_part, setup_bad_part)), cleanup(bom_cleanup_all)]) :-
    assertion(\+ bom_compliant(board, auto)).

:- end_tests(bom_policy_actions).

%% ── Dates: ISO YYYY-MM-DD and day numbers ───────────────────────────────────

%% The eol-soon part with ISO dates: today 2024-10-04 is day 20000, so the
%% end-of-life and last-time-buy dates are the same 400 and 100 days out.
setup_iso_today :-
    assertz(attribute(today, date, '2024-10-04')).

setup_iso_eol_soon_part :-
    assertz(relation(board, includes, fet_iso)),
    assertz(attribute(fet_iso, lifecycle, eol)),
    assertz(attribute(fet_iso, rohs, compliant)),
    assertz(attribute(fet_iso, aec_qualified, true)),
    assertz(relation(fet_iso, sourced_from, dist_a)),
    assertz(relation(fet_iso, sourced_from, dist_b)),
    assertz(attribute(fet_iso, eol_day, '2025-11-08')),
    assertz(attribute(fet_iso, ltb_day, '2025-01-12')).

%% Last-time-buy 2024-06-26, day 19900, against an integer today.
setup_iso_ltb_passed_part :-
    assertz(relation(board, includes, osc_iso)),
    assertz(attribute(osc_iso, lifecycle, eol)),
    assertz(attribute(osc_iso, rohs, compliant)),
    assertz(attribute(osc_iso, aec_qualified, true)),
    assertz(relation(osc_iso, sourced_from, dist_a)),
    assertz(relation(osc_iso, sourced_from, dist_b)),
    assertz(attribute(osc_iso, ltb_day, '2024-06-26')).

%% Across February in a leap year: two days from the 28th to March 1st.
setup_leap_today :-
    assertz(attribute(today, date, '2024-02-28')).

setup_leap_part :-
    assertz(relation(board, includes, leap)),
    assertz(attribute(leap, lifecycle, active)),
    assertz(attribute(leap, ltb_day, '2024-03-01')).

%% A string today and a character-list end-of-life date, as SWI and Scryer
%% hand text over.
setup_text_dates :-
    assertz(attribute(today, date, "2024-10-04")),
    atom_chars('2025-11-08', Chars),
    assertz(relation(board, includes, chars_part)),
    assertz(attribute(chars_part, lifecycle, active)),
    assertz(attribute(chars_part, eol_day, Chars)).

%% An unparseable last-time-buy date beside a good end-of-life date.
setup_bad_date_part :-
    assertz(relation(board, includes, garbled)),
    assertz(attribute(garbled, lifecycle, active)),
    assertz(attribute(garbled, rohs, compliant)),
    assertz(attribute(garbled, aec_qualified, true)),
    assertz(relation(garbled, sourced_from, dist_a)),
    assertz(relation(garbled, sourced_from, dist_b)),
    assertz(attribute(garbled, ltb_day, '2024-02-30')),
    assertz(attribute(garbled, eol_day, '2025-11-08')).

setup_bad_today :-
    assertz(attribute(today, date, soon)).

:- begin_tests(bom_policy_dates).

test(iso_converts_to_days_since_1970) :-
    assertion(bom_day('1970-01-01', 0)),
    assertion(bom_day('2024-10-04', 20000)),
    assertion(bom_day('2000-02-29', 11016)),
    assertion(bom_day('2100-03-01', 47541)),
    assertion(bom_day(20000, 20000)),
    %% Exclusive clauses: one day per date, so no reason is reported twice.
    findall(D, bom_day('2000-02-29', D), Ds),
    assertion(Ds == [11016]).

test(month_year_and_leap_boundaries, [nondet]) :-
    bom_day('2024-10-31', Oct31), bom_day('2024-11-01', Nov1),
    assertion(Nov1 - Oct31 =:= 1),
    bom_day('2025-12-31', Dec31), bom_day('2026-01-01', Jan1),
    assertion(Jan1 - Dec31 =:= 1),
    bom_day('2024-02-28', Feb28), bom_day('2024-02-29', Feb29), bom_day('2024-03-01', Mar1),
    assertion(Feb29 - Feb28 =:= 1),
    assertion(Mar1 - Feb28 =:= 2),
    bom_day('2023-02-28', Feb28b), bom_day('2023-03-01', Mar1b),
    assertion(Mar1b - Feb28b =:= 1).

test(invalid_dates_do_not_convert) :-
    assertion(\+ bom_day('2024-02-30', _)),
    assertion(\+ bom_day('2023-02-29', _)),
    assertion(\+ bom_day('2100-02-29', _)),
    assertion(\+ bom_day('2024-13-01', _)),
    assertion(\+ bom_day('2024-00-10', _)),
    assertion(\+ bom_day('2024-10-00', _)),
    assertion(\+ bom_day('2024-1-5', _)),
    assertion(\+ bom_day('2024/10/04', _)),
    assertion(\+ bom_day('2024-10-04T00:00:00Z', _)),
    assertion(\+ bom_day(soon, _)),
    assertion(\+ bom_day(date(2024, 10, 4), _)).

test(iso_dates_match_day_numbers, [setup((setup_iso_today, setup_auto_policy, setup_iso_eol_soon_part)), cleanup(bom_cleanup_all)]) :-
    findall(R, bom_violation(board, auto, fet_iso, R), Rs),
    assertion(memberchk(eol_within(400), Rs)),
    assertion(memberchk(ltb_within(100), Rs)),
    assertion(part_risk(fet_iso, auto, warn)),
    findall(P-D, last_time_buy_due(board, auto, P, D), Due),
    assertion(Due == [fet_iso-100]).

test(iso_part_against_integer_today, [setup((setup_today, setup_auto_policy, setup_iso_ltb_passed_part)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_violation(board, auto, osc_iso, ltb_passed(100))),
    assertion(part_risk(osc_iso, auto, blocked)).

test(integer_part_against_iso_today, [setup((setup_iso_today, setup_auto_policy, setup_eol_soon_part, setup_ltb_passed_part)), cleanup(bom_cleanup_all)]) :-
    findall(P-D, last_time_buy_due(board, auto, P, D), Due0),
    sort(Due0, Due),
    assertion(Due == [fet_eol-100, osc_late-(-100)]).

test(leap_day_counts, [setup((setup_leap_today, setup_leap_part)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_violation(board, plain, leap, ltb_within(2))).

test(string_and_char_list_dates, [setup((setup_text_dates, setup_auto_policy)), cleanup(bom_cleanup_all)]) :-
    assertion(bom_violation(board, auto, chars_part, eol_within(400))),
    findall(D, last_time_buy_due(board, auto, chars_part, D), Ds),
    assertion(Ds == [400]).

test(unparseable_date_reads_as_absent, [setup((setup_iso_today, setup_auto_policy, setup_bad_date_part)), cleanup(bom_cleanup_all)]) :-
    findall(R, bom_violation(board, auto, garbled, R), Rs),
    assertion(\+ memberchk(ltb_passed(_), Rs)),
    assertion(\+ memberchk(ltb_within(_), Rs)),
    assertion(memberchk(eol_within(400), Rs)),
    %% No usable last-time-buy date, so the buy list falls back to end of life.
    findall(D, last_time_buy_due(board, auto, garbled, D), Ds),
    assertion(Ds == [400]).

test(unparseable_today_drops_date_reasons, [setup((setup_bad_today, setup_auto_policy, setup_eol_soon_part)), cleanup(bom_cleanup_all)]) :-
    findall(R, bom_violation(board, auto, fet_eol, R), Rs),
    assertion(\+ memberchk(eol_within(_), Rs)),
    assertion(\+ memberchk(ltb_within(_), Rs)),
    assertion(\+ last_time_buy_due(board, auto, fet_eol, _)).

:- end_tests(bom_policy_dates).
