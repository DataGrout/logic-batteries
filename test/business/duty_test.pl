:- use_module(library(plunit)).

:- consult('../../modules/business/duty/duty').

%% Time unit in these tests: minutes. Day N starts at N*1440.
%% Scene: a ward roster. Two nurses, one orderly, one delivery van.

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_roster :-
    assertz(attribute(alvarez, role, nurse)),
    assertz(attribute(chen, role, nurse)),
    assertz(attribute(okafor, role, orderly)).

setup_global_policy :-
    assertz(attribute(duty_policy, max_duty, 840)),      %% 14 h
    assertz(attribute(duty_policy, min_rest, 600)).      %% 10 h

setup_nurse_rolling_policy :-
    assertz(attribute(nurse, rolling_window, 10080)),   %% 7 days
    assertz(attribute(nurse, rolling_limit, 3600)).     %% 60 h

setup_alvarez_override :-
    assertz(attribute(alvarez, max_duty, 720)).          %% 12 h, beats global

%% alvarez worked 08:00–18:00 on day 0 (480–1080).
setup_alvarez_day0_duty :-
    assertz(relation(alvarez, duty_period, d_a0)),
    assertz(attribute(d_a0, start, 480)),
    assertz(attribute(d_a0, end, 1080)).

%% chen has a committed shift on day 1, 06:00–14:00 (1800–2280).
setup_chen_day1_duty :-
    assertz(relation(chen, duty_period, d_c1)),
    assertz(attribute(d_c1, start, 1800)),
    assertz(attribute(d_c1, end, 2280)).

%% chen on leave day 2 (2880–4320).
setup_chen_leave_day2 :-
    assertz(relation(chen, unavailable_during, w_leave)),
    assertz(attribute(w_leave, start, 2880)),
    assertz(attribute(w_leave, end, 4320)),
    assertz(attribute(w_leave, reason, leave)).

%% delivery van_3 in the shop day 1 06:00–14:00.
setup_van_maintenance :-
    assertz(relation(van_3, unavailable_during, w_mx)),
    assertz(attribute(w_mx, start, 1800)),
    assertz(attribute(w_mx, end, 2280)),
    assertz(attribute(w_mx, reason, maintenance)).

%% alvarez near the rolling cap: 3300 min of duty inside the 7-day window
%% ending at 10080 (three 1100-minute shifts), plus one 600-minute shift that
%% straddles the window start at 0 (half in, half out → 300 counts).
setup_alvarez_heavy_week :-
    assertz(relation(alvarez, duty_period, d_h1)),
    assertz(attribute(d_h1, start, 1000)), assertz(attribute(d_h1, end, 2100)),
    assertz(relation(alvarez, duty_period, d_h2)),
    assertz(attribute(d_h2, start, 3000)), assertz(attribute(d_h2, end, 4100)),
    assertz(relation(alvarez, duty_period, d_h3)),
    assertz(attribute(d_h3, start, 5000)), assertz(attribute(d_h3, end, 6100)),
    assertz(relation(alvarez, duty_period, d_h0)),
    assertz(attribute(d_h0, start, -300)), assertz(attribute(d_h0, end, 300)).

setup_icu_task :-
    assertz(relation(t_icu, requires, icu_cert)),
    assertz(relation(t_icu, requires, acls)),
    assertz(attribute(t_icu, needs_role, nurse)).

setup_ward_task :-
    assertz(relation(t_ward, requires, acls)).

setup_alvarez_quals :-
    assertz(relation(alvarez, holds, q_a_icu)),
    assertz(attribute(q_a_icu, kind, icu_cert)),
    assertz(attribute(q_a_icu, expires, 20000)),
    assertz(relation(alvarez, holds, q_a_acls)),
    assertz(attribute(q_a_acls, kind, acls)).          %% no expiry

setup_chen_quals_icu_expired :-
    assertz(relation(chen, holds, q_c_icu)),
    assertz(attribute(q_c_icu, kind, icu_cert)),
    assertz(attribute(q_c_icu, expires, 1000)),        %% lapsed before day 1
    assertz(relation(chen, holds, q_c_acls)),
    assertz(attribute(q_c_acls, kind, acls)).

setup_base :-
    setup_roster,
    setup_global_policy,
    setup_nurse_rolling_policy.

setup_full_scene :-
    setup_base,
    setup_alvarez_day0_duty,
    setup_chen_day1_duty,
    setup_chen_leave_day2,
    setup_van_maintenance,
    setup_icu_task,
    setup_ward_task,
    setup_alvarez_quals,
    setup_chen_quals_icu_expired.

%% ── duty_conflict/3 and unavailable/3 ────────────────────────────────────────

:- begin_tests(duty_conflicts).

test(overlap_is_conflict, [setup(setup_chen_day1_duty), cleanup(clear_facts)]) :-
    assertion(duty_conflict(chen, 2000, 2400)).

test(adjacent_is_not_conflict, [setup(setup_chen_day1_duty), cleanup(clear_facts)]) :-
    %% half-open: a shift starting exactly when the other ends does not overlap
    assertion(\+ duty_conflict(chen, 2280, 2700)).

test(disjoint_is_not_conflict, [setup(setup_chen_day1_duty), cleanup(clear_facts)]) :-
    assertion(\+ duty_conflict(chen, 2400, 2700)).

test(leave_is_unavailable, [setup(setup_chen_leave_day2), cleanup(clear_facts)]) :-
    assertion(unavailable(chen, 3000, 3300)).

test(equipment_maintenance_is_unavailable, [setup(setup_van_maintenance), cleanup(clear_facts)]) :-
    assertion(unavailable(van_3, 2000, 2100)),
    assertion(\+ unavailable(van_3, 2280, 2400)).

:- end_tests(duty_conflicts).

%% ── duty_limit/3 and policy_gap/2 ────────────────────────────────────────────

:- begin_tests(duty_policy).

test(global_policy_resolves, [setup(setup_base), cleanup(clear_facts)]) :-
    duty_limit(chen, max_duty, Max), assertion(Max == 840).

test(role_policy_resolves, [setup(setup_base), cleanup(clear_facts)]) :-
    duty_limit(chen, rolling_limit, L), assertion(L == 3600).

test(worker_override_beats_global, [setup((setup_base, setup_alvarez_override)), cleanup(clear_facts)]) :-
    duty_limit(alvarez, max_duty, Max), assertion(Max == 720).

test(orderly_has_no_rolling_policy, [setup(setup_base), cleanup(clear_facts)]) :-
    assertion(\+ duty_limit(okafor, rolling_limit, _)),
    assertion(policy_gap(okafor, rolling_limit)),
    assertion(\+ policy_gap(okafor, max_duty)).

test(nurse_has_no_policy_gap, [setup(setup_base), cleanup(clear_facts)]) :-
    assertion(\+ policy_gap(alvarez, _)).

:- end_tests(duty_policy).

%% ── duty_length_ok/3 ─────────────────────────────────────────────────────────

:- begin_tests(duty_length).

test(within_max, [setup(setup_base), cleanup(clear_facts)]) :-
    assertion(duty_length_ok(chen, 0, 840)).

test(over_max, [setup(setup_base), cleanup(clear_facts)]) :-
    assertion(\+ duty_length_ok(chen, 0, 841)).

test(override_applies, [setup((setup_base, setup_alvarez_override)), cleanup(clear_facts)]) :-
    assertion(\+ duty_length_ok(alvarez, 0, 800)),
    assertion(duty_length_ok(chen, 0, 800)).

test(no_policy_is_vacuous, [setup(setup_roster), cleanup(clear_facts)]) :-
    assertion(duty_length_ok(chen, 0, 5000)).

:- end_tests(duty_length).

%% ── rest_before/3 and rest_satisfied/2 ───────────────────────────────────────

:- begin_tests(duty_rest).

test(rest_measured_from_latest_end, [setup((setup_base, setup_alvarez_day0_duty)), cleanup(clear_facts)]) :-
    rest_before(alvarez, 1500, Rest), assertion(Rest == 420).

test(insufficient_rest, [setup((setup_base, setup_alvarez_day0_duty)), cleanup(clear_facts)]) :-
    assertion(\+ rest_satisfied(alvarez, 1500)).     %% 7 h < 10 h

test(sufficient_rest, [setup((setup_base, setup_alvarez_day0_duty)), cleanup(clear_facts)]) :-
    assertion(rest_satisfied(alvarez, 1680)).        %% exactly 10 h

test(no_prior_duty_is_rested, [setup(setup_base), cleanup(clear_facts)]) :-
    assertion(\+ rest_before(chen, 1500, _)),
    assertion(rest_satisfied(chen, 1500)).

test(running_duty_is_not_rest, [setup((setup_base, setup_chen_day1_duty)), cleanup(clear_facts)]) :-
    %% a period ending after Start is a conflict, not a rest reference
    assertion(\+ rest_before(chen, 2000, _)).

:- end_tests(duty_rest).

%% ── cumulative_duty/4, rolling_limit_ok/3, duty_headroom/3 ───────────────────

:- begin_tests(duty_rolling).

test(cumulative_clips_at_window_edge, [setup((setup_base, setup_alvarez_heavy_week)), cleanup(clear_facts)]) :-
    cumulative_duty(alvarez, 0, 10080, Total), assertion(Total == 3600).

test(headroom_is_zero_at_cap, [setup((setup_base, setup_alvarez_heavy_week)), cleanup(clear_facts)]) :-
    duty_headroom(alvarez, 10080, H), assertion(H == 0).

test(rolling_limit_blocks_next_duty, [setup((setup_base, setup_alvarez_heavy_week)), cleanup(clear_facts)]) :-
    assertion(\+ rolling_limit_ok(alvarez, 9000, 9600)).

test(rolling_limit_frees_as_window_slides, [setup((setup_base, setup_alvarez_heavy_week)), cleanup(clear_facts)]) :-
    %% ending at 12200 drops d_h0 and d_h1 out of the window: 2200 accrued
    assertion(rolling_limit_ok(alvarez, 11000, 12200)).

test(no_rolling_policy_is_vacuous, [setup((setup_base, setup_alvarez_heavy_week)), cleanup(clear_facts)]) :-
    assertion(rolling_limit_ok(okafor, 9000, 9600)).

:- end_tests(duty_rolling).

%% ── qualified_for/3 and missing_qualification/4 ─────────────────────────────

:- begin_tests(duty_qualifications).

test(all_current_quals, [setup((setup_icu_task, setup_alvarez_quals)), cleanup(clear_facts)]) :-
    assertion(qualified_for(alvarez, t_icu, 1800)).

test(expired_qual_is_missing, [setup((setup_icu_task, setup_chen_quals_icu_expired)), cleanup(clear_facts)]) :-
    assertion(\+ qualified_for(chen, t_icu, 1800)),
    findall(K, missing_qualification(chen, t_icu, 1800, K), Ks),
    assertion(Ks == [icu_cert]).

test(qual_valid_before_expiry, [setup((setup_icu_task, setup_chen_quals_icu_expired)), cleanup(clear_facts)]) :-
    assertion(qualified_for(chen, t_icu, 900)).

test(task_without_requirements, [setup(setup_roster), cleanup(clear_facts)]) :-
    assertion(qualified_for(okafor, t_anything, 0)).

:- end_tests(duty_qualifications).

%% ── fit_for_duty/4, unfit_reason/5, available_staff/4 ────────────────────────

:- begin_tests(duty_verdict).

%% Day 1, 16:00–22:00 = 2400–2760 (6 h).
test(alvarez_fit_day1_evening, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    assertion(fit_for_duty(alvarez, t_icu, 2400, 2760)).

test(chen_unfit_two_reasons, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    %% 14:30 start = 2370: only 90 min rest after d_c1, and icu_cert lapsed
    assertion(\+ fit_for_duty(chen, t_icu, 2370, 2760)),
    findall(R, unfit_reason(chen, t_icu, 2370, 2760, R), Rs),
    assertion(memberchk(insufficient_rest(90, 600), Rs)),
    assertion(memberchk(missing_qualification(icu_cert), Rs)),
    assertion(\+ memberchk(duty_conflict(_), Rs)).

test(chen_conflict_during_shift, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    findall(R, unfit_reason(chen, t_ward, 2000, 2400, R), Rs),
    assertion(memberchk(duty_conflict(d_c1), Rs)).

test(chen_on_leave, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    findall(R, unfit_reason(chen, t_ward, 3000, 3300, R), Rs),
    assertion(memberchk(unavailable(w_leave), Rs)).

test(orderly_role_mismatch_for_nurse_task, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    findall(R, unfit_reason(okafor, t_icu, 2400, 2760, R), Rs),
    assertion(memberchk(role_mismatch(nurse), Rs)).

test(too_long_duty, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    findall(R, unfit_reason(alvarez, t_ward, 2400, 3300, R), Rs),
    assertion(memberchk(duty_too_long(900, 840), Rs)).

test(fit_has_no_reasons, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    assertion(\+ unfit_reason(alvarez, t_icu, 2400, 2760, _)).

test(available_staff_enumerates_only_fit, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    findall(W, available_staff(t_icu, 2400, 2760, W), Ws),
    assertion(Ws == [alvarez]).

test(available_staff_day3_both_nurses, [setup(setup_full_scene), cleanup(clear_facts)]) :-
    %% day 3: chen is back from leave and rested; t_ward requires acls and no
    %% role, and okafor holds no qualifications → excluded
    findall(W, available_staff(t_ward, 4400, 4700, W), Ws),
    assertion(Ws == [alvarez, chen]).

:- end_tests(duty_verdict).
