:- use_module(library(plunit)).

:- consult('../../modules/business/duty/duty').
:- consult('../../modules/reasoning/assign/assign').
:- consult('../../modules/business/rostering/rostering').

%% Time unit: minutes. Day N starts at N*1440.
%% Scene: a ward. Three nurses, one orderly, three shifts.

ro_reset_hooks :-
    retractall(assign_reject(_, _)),
    retractall(assign_reject_pair(_, _, _, _)),
    retractall(assign_cost(_, _, _)),
    assertz((assign_reject(_, _) :- fail)),
    assertz((assign_reject_pair(_, _, _, _) :- fail)),
    assertz((assign_cost(_, _, _) :- fail)).

ro_cleanup :- clear_facts, ro_reset_hooks.

%% ── Setup ────────────────────────────────────────────────────────────────────

ro_roster :-
    assertz(attribute(alvarez, role, nurse)),
    assertz(attribute(chen, role, nurse)),
    assertz(attribute(diaz, role, nurse)),
    assertz(attribute(okafor, role, orderly)),
    assertz(attribute(alvarez, seniority, 9)),
    assertz(attribute(chen, seniority, 3)),
    assertz(attribute(diaz, seniority, 5)).

ro_policy :-
    assertz(attribute(duty_policy, max_duty, 840)),
    assertz(attribute(duty_policy, min_rest, 600)),
    assertz(attribute(nurse, rolling_window, 10080)),
    assertz(attribute(nurse, rolling_limit, 3600)).

ro_quals :-
    assertz(relation(alvarez, holds, q_a)), assertz(attribute(q_a, kind, acls)),
    assertz(relation(chen, holds, q_c)),    assertz(attribute(q_c, kind, acls)),
    assertz(relation(diaz, holds, q_d)),    assertz(attribute(q_d, kind, acls)),
    assertz(relation(okafor, holds, q_o)),  assertz(attribute(q_o, kind, acls)).

%% sh_am: day 0 08:00–18:00, needs 2 nurses + 1 orderly, requires acls.
%% sh_pm: day 0 19:00–05:00 (1140–1740), needs 1 nurse. 60 min after sh_am.
%% sh_next: day 1 08:00–18:00 (1920–2520), needs 1 nurse. 840 after sh_am,
%%          180 after sh_pm.
ro_shifts :-
    assertz(attribute(sh_am, start, 480)),  assertz(attribute(sh_am, end, 1080)),
    assertz(relation(sh_am, needs, r_am_n)), assertz(attribute(r_am_n, seat, nurse)),   assertz(attribute(r_am_n, count, 2)),
    assertz(relation(sh_am, needs, r_am_o)), assertz(attribute(r_am_o, seat, orderly)), assertz(attribute(r_am_o, count, 1)),
    assertz(relation(sh_am, requires, acls)),
    assertz(attribute(sh_pm, start, 1140)), assertz(attribute(sh_pm, end, 1740)),
    assertz(relation(sh_pm, needs, r_pm_n)), assertz(attribute(r_pm_n, seat, nurse)),   assertz(attribute(r_pm_n, count, 1)),
    assertz(attribute(sh_next, start, 1920)), assertz(attribute(sh_next, end, 2520)),
    assertz(relation(sh_next, needs, r_nx_n)), assertz(attribute(r_nx_n, seat, nurse)), assertz(attribute(r_nx_n, count, 1)).

ro_prefs :-
    assertz(relation(alvarez, prefers, sh_am)),
    assertz(relation(chen, avoids, sh_am)).

ro_base :- ro_roster, ro_policy, ro_quals, ro_shifts, ro_prefs.

ro_assign(Shift, W) :- assertz(relation(Shift, assigned, W)).

ro_base_alvarez_am :- ro_base, ro_assign(sh_am, alvarez).

ro_full_valid :-
    ro_base,
    ro_assign(sh_am, alvarez), ro_assign(sh_am, diaz), ro_assign(sh_am, okafor),
    ro_assign(sh_pm, chen),
    ro_assign(sh_next, alvarez).

ro_diaz_without_acls :-
    ro_roster, ro_policy, ro_shifts, ro_prefs,
    assertz(relation(alvarez, holds, q_a)), assertz(attribute(q_a, kind, acls)),
    assertz(relation(chen, holds, q_c)),    assertz(attribute(q_c, kind, acls)),
    assertz(relation(okafor, holds, q_o)),  assertz(attribute(q_o, kind, acls)).

ro_shift_x :-
    assertz(attribute(sh_x, start, 600)), assertz(attribute(sh_x, end, 700)),
    assertz(relation(sh_x, needs, r_x)), assertz(attribute(r_x, seat, nurse)), assertz(attribute(r_x, count, 1)).

ro_shift_o :-
    assertz(attribute(sh_o, start, 600)), assertz(attribute(sh_o, end, 700)),
    assertz(relation(sh_o, needs, r_o)), assertz(attribute(r_o, seat, orderly)), assertz(attribute(r_o, count, 1)).

%% ── coverage ─────────────────────────────────────────────────────────────────

:- begin_tests(rostering_coverage).

test(coverage_counts_role, [setup(ro_base_alvarez_am), cleanup(ro_cleanup), nondet]) :-
    coverage(sh_am, nurse, N), assertion(N == 1),
    coverage(sh_am, orderly, O), assertion(O == 0).

test(gaps_per_role, [setup(ro_base_alvarez_am), cleanup(ro_cleanup)]) :-
    findall(R-M, coverage_gap(sh_am, R, M), Gs), msort(Gs, S),
    assertion(S == [nurse-1, orderly-1]).

test(understaffed_and_not, [setup(ro_full_valid), cleanup(ro_cleanup)]) :-
    assertion(\+ understaffed(sh_am)),
    assertion(\+ understaffed(sh_pm)).

test(understaffed_when_gap, [setup(ro_base_alvarez_am), cleanup(ro_cleanup)]) :-
    assertion(understaffed(sh_am)).

test(overstaffed, [setup((ro_base, ro_assign(sh_pm, chen), ro_assign(sh_pm, diaz))), cleanup(ro_cleanup), nondet]) :-
    overstaffed(sh_pm, nurse, E), assertion(E == 1).

:- end_tests(rostering_coverage).

%% ── incompatibility ──────────────────────────────────────────────────────────

:- begin_tests(rostering_incompatible).

test(short_rest_is_incompatible, [setup(ro_base), cleanup(ro_cleanup)]) :-
    assertion(incompatible_shifts(alvarez, sh_am, sh_pm)),
    assertion(incompatible_shifts(alvarez, sh_pm, sh_am)).

test(enough_rest_is_compatible, [setup(ro_base), cleanup(ro_cleanup)]) :-
    assertion(\+ incompatible_shifts(alvarez, sh_am, sh_next)).

test(overlap_is_incompatible_without_policy, [setup((ro_roster, ro_shifts, ro_shift_x)), cleanup(ro_cleanup)]) :-
    assertion(incompatible_shifts(alvarez, sh_am, sh_x)).

test(no_policy_no_rest_rule, [setup((ro_roster, ro_shifts)), cleanup(ro_cleanup)]) :-
    %% without min_rest configured, adjacent non-overlapping shifts are compatible
    assertion(\+ incompatible_shifts(alvarez, sh_am, sh_pm)).

:- end_tests(rostering_incompatible).

%% ── violations and validity ──────────────────────────────────────────────────

:- begin_tests(rostering_violations).

test(clash_reported_both_ways, [setup((ro_base, ro_assign(sh_am, alvarez), ro_assign(sh_pm, alvarez))), cleanup(ro_cleanup)]) :-
    findall(R, roster_violation(sh_am, alvarez, R), Rs), assertion(memberchk(clash(sh_pm), Rs)),
    findall(R2, roster_violation(sh_pm, alvarez, R2), Rs2), assertion(memberchk(clash(sh_am), Rs2)).

test(role_not_needed, [setup((ro_base, ro_assign(sh_pm, okafor))), cleanup(ro_cleanup)]) :-
    findall(R, roster_violation(sh_pm, okafor, R), Rs),
    assertion(memberchk(role_not_needed(orderly), Rs)).

test(duty_reasons_surface, [setup((ro_diaz_without_acls, ro_assign(sh_am, diaz))), cleanup(ro_cleanup)]) :-
    findall(R, roster_violation(sh_am, diaz, R), Rs),
    assertion(memberchk(missing_qualification(acls), Rs)).

test(full_roster_valid, [setup(ro_full_valid), cleanup(ro_cleanup)]) :-
    assertion(roster_valid([sh_am, sh_pm, sh_next])).

test(gap_invalidates, [setup(ro_base_alvarez_am), cleanup(ro_cleanup)]) :-
    assertion(\+ roster_valid([sh_am])).

test(clash_invalidates, [setup((ro_full_valid, ro_assign(sh_pm, alvarez))), cleanup(ro_cleanup)]) :-
    assertion(\+ roster_valid([sh_am, sh_pm])).

:- end_tests(rostering_violations).

%% ── candidates and ranking ───────────────────────────────────────────────────

:- begin_tests(rostering_candidates).

test(candidates_exclude_assigned, [setup(ro_base_alvarez_am), cleanup(ro_cleanup)]) :-
    candidates(sh_am, nurse, Ws), assertion(Ws == [chen, diaz]).

test(candidates_exclude_unfit, [setup(ro_diaz_without_acls), cleanup(ro_cleanup)]) :-
    candidates(sh_am, nurse, Ws), assertion(Ws == [alvarez, chen]).

test(candidates_exclude_incompatible, [setup((ro_base, ro_assign(sh_am, alvarez), ro_assign(sh_am, diaz))), cleanup(ro_cleanup)]) :-
    %% alvarez and diaz clash with sh_pm (60 min rest); only chen remains
    candidates(sh_pm, nurse, Ws), assertion(Ws == [chen]).

test(rank_prefers_first_avoids_last, [setup(ro_base), cleanup(ro_cleanup)]) :-
    rank_candidates(sh_am, nurse, R), assertion(R == [alvarez, diaz, chen]).

test(score_shape, [setup(ro_base), cleanup(ro_cleanup), nondet]) :-
    candidate_score(sh_am, alvarez, S),
    assertion(S == k(0, -3600, 0, -9)).

test(seniority_breaks_ties, [setup(ro_base), cleanup(ro_cleanup)]) :-
    %% sh_next: no preferences, equal headroom and load → seniority decides
    rank_candidates(sh_next, nurse, R), assertion(R == [alvarez, diaz, chen]).

:- end_tests(rostering_candidates).

%% ── filling ──────────────────────────────────────────────────────────────────

:- begin_tests(rostering_fill).

test(fill_takes_gap_size, [setup(ro_base), cleanup(ro_cleanup)]) :-
    fill_shift(sh_am, nurse, P), assertion(P == [alvarez, diaz]).

test(fill_empty_when_covered, [setup(ro_full_valid), cleanup(ro_cleanup)]) :-
    fill_shift(sh_am, nurse, P), assertion(P == []).

test(propose_whole_roster, [setup(ro_base), cleanup(ro_cleanup)]) :-
    propose_roster([sh_next, sh_pm, sh_am], Prop, Unf),
    assertion(Prop == [sh_am-alvarez, sh_am-diaz, sh_am-okafor, sh_pm-chen, sh_next-alvarez]),
    assertion(Unf == []).

test(propose_reports_unfilled, [setup((ro_base, ro_assign(sh_am, okafor), ro_shift_o)), cleanup(ro_cleanup)]) :-
    %% okafor already on sh_am; an overlapping shift needing an orderly has no candidate
    propose_roster([sh_o], _, Unf),
    assertion(Unf == [sh_o-orderly-1]).

:- end_tests(rostering_fill).

%% ── replacements and swaps ───────────────────────────────────────────────────

:- begin_tests(rostering_changes).

test(replacement_best_first, [setup((ro_base, ro_assign(sh_am, alvarez), ro_assign(sh_am, diaz))), cleanup(ro_cleanup)]) :-
    findall(C, replacement_for(sh_am, alvarez, C), Cs), assertion(Cs == [chen]).

test(swap_valid_between_nurses, [setup((ro_base, ro_assign(sh_am, alvarez), ro_assign(sh_pm, chen))), cleanup(ro_cleanup)]) :-
    assertion(swap_valid(alvarez, sh_am, chen, sh_pm)).

test(swap_invalid_wrong_role, [setup((ro_base, ro_assign(sh_next, alvarez), ro_assign(sh_pm, okafor))), cleanup(ro_cleanup)]) :-
    %% sh_next has no orderly seat, so okafor cannot take it
    assertion(\+ swap_valid(alvarez, sh_next, okafor, sh_pm)).

test(swap_invalid_clash_elsewhere, [setup((ro_base, ro_assign(sh_am, alvarez), ro_assign(sh_next, alvarez), ro_assign(sh_pm, diaz))), cleanup(ro_cleanup)]) :-
    %% alvarez keeps sh_next; taking sh_pm would leave only 180 min before it
    assertion(\+ swap_valid(alvarez, sh_am, diaz, sh_pm)).

:- end_tests(rostering_changes).

%% ── load ─────────────────────────────────────────────────────────────────────

:- begin_tests(rostering_load).

test(assigned_load_clips, [setup(ro_full_valid), cleanup(ro_cleanup)]) :-
    assigned_load(alvarez, 0, 1440, T), assertion(T == 600),
    assigned_load(alvarez, 0, 1000, T2), assertion(T2 == 520),
    assigned_load(alvarez, 0, 2880, T3), assertion(T3 == 1200).

test(load_imbalance, [setup(ro_full_valid), cleanup(ro_cleanup)]) :-
    load_imbalance(nurse, 0, 2880, Max, Min),
    assertion(Max == 1200), assertion(Min == 600).

:- end_tests(rostering_load).

%% ── assign model ─────────────────────────────────────────────────────────────

ro_hooks :-
    assertz((assign_reject_pair(S1, W, S2, W) :-
                relation(S1, slot_of, Sh1), relation(S2, slot_of, Sh2),
                Sh1 \== Sh2, incompatible_shifts(W, Sh1, Sh2))).

ro_assert_all([]).
ro_assert_all([F|Fs]) :- assertz(F), ro_assert_all(Fs).

:- begin_tests(rostering_model).

test(model_slots_and_domains, [setup(ro_base_alvarez_am), cleanup(ro_cleanup)]) :-
    roster_model([sh_am], Facts),
    assertion(length(Facts, 8)),
    assertion(memberchk(attribute(sh_am_nurse_1, domain, [chen, diaz]), Facts)),
    assertion(memberchk(attribute(sh_am_orderly_1, domain, [okafor]), Facts)),
    assertion(memberchk(relation(sh_am, distinct, sh_am_nurse_1), Facts)),
    assertion(memberchk(relation(sh_am_orderly_1, slot_of, sh_am), Facts)).

test(model_solves_with_assign, [setup((ro_base, ro_hooks)), cleanup(ro_cleanup)]) :-
    roster_model([sh_am, sh_pm], Facts),
    ro_assert_all(Facts),
    assign_solve([sh_am_nurse_1, sh_am_nurse_2, sh_am_orderly_1, sh_pm_nurse_1], R),
    assertion(R = solution(_, _)),
    R = solution(A, _),
    memberchk(sh_am_nurse_1-N1, A), memberchk(sh_am_nurse_2-N2, A), memberchk(sh_pm_nurse_1-P, A),
    assertion(N1 \== N2),
    assertion(\+ memberchk(P, [N1, N2])),
    assign_violations(A, Vs), assertion(Vs == []).

:- end_tests(rostering_model).
