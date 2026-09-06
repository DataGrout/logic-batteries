:- use_module(library(plunit)).

:- consult('../../modules/reasoning/assign/assign').
:- consult('../../modules/business/duty/duty').

%% ── Hook management ──────────────────────────────────────────────────────────
%% Hooks are open predicates with a failing base clause. Tests add clauses in
%% setup and reset to the base clause in cleanup.

reset_hooks :-
    retractall(assign_reject(_, _)),
    retractall(assign_reject_pair(_, _, _, _)),
    retractall(assign_cost(_, _, _)),
    assertz((assign_reject(_, _) :- fail)),
    assertz((assign_reject_pair(_, _, _, _) :- fail)),
    assertz((assign_cost(_, _, _) :- fail)).

cleanup_all :-
    clear_facts,
    reset_hooks.

%% ── Setup predicates ─────────────────────────────────────────────────────────

%% Three slots, three candidates, all on one day (must be distinct).
setup_three_slots :-
    assertz(attribute(s1, domain, [a, b, c])),
    assertz(attribute(s2, domain, [a, b, c])),
    assertz(attribute(s3, domain, [a, b, c])),
    assertz(relation(day, distinct, s1)),
    assertz(relation(day, distinct, s2)),
    assertz(relation(day, distinct, s3)).

%% Three slots, only two candidates: unsatisfiable under distinct.
setup_three_slots_two_values :-
    assertz(attribute(s1, domain, [a, b])),
    assertz(attribute(s2, domain, [a, b])),
    assertz(attribute(s3, domain, [a, b])),
    assertz(relation(day, distinct, s1)),
    assertz(relation(day, distinct, s2)),
    assertz(relation(day, distinct, s3)).

setup_reject_s1_a :-
    assertz(assign_reject(s1, a)).

setup_reject_all_s1 :-
    assertz(assign_reject(s1, a)),
    assertz(assign_reject(s1, b)),
    assertz(assign_reject(s1, c)).

setup_pair_s1a_s2b :-
    assertz(assign_reject_pair(s1, a, s2, b)).

setup_costs_s1 :-
    assertz(assign_cost(s1, a, 5)),
    assertz(assign_cost(s1, b, 1)),
    assertz(assign_cost(s1, c, 3)).

%% Composition with duty: two adjacent shifts, two workers, a rest rule
%% between assigned shifts via the pair hook, and fitness via the unary hook.
setup_duty_scene :-
    assertz(attribute(alvarez, role, nurse)),
    assertz(attribute(chen, role, nurse)),
    assertz(attribute(duty_policy, max_duty, 840)),
    assertz(attribute(duty_policy, min_rest, 600)),
    %% shifts as slots: am 08:00–18:00, pm 19:00–05:00 (gap 60 < min_rest)
    assertz(attribute(am, domain, [alvarez, chen])),
    assertz(attribute(pm, domain, [alvarez, chen])),
    assertz(attribute(am, start, 480)),  assertz(attribute(am, end, 1080)),
    assertz(attribute(pm, start, 1140)), assertz(attribute(pm, end, 1740)),
    %% pm needs an ICU-certified nurse; only alvarez holds it
    assertz(relation(pm, requires, icu_cert)),
    assertz(relation(alvarez, holds, q_a)),
    assertz(attribute(q_a, kind, icu_cert)),
    %% unary: a worker must be fit for the slot on their own record
    assertz((assign_reject(Slot, W) :-
                attribute(Slot, start, S), attribute(Slot, end, E),
                \+ fit_for_duty(W, Slot, S, E))),
    %% pairwise: the same worker on two slots needs min_rest between them
    assertz((assign_reject_pair(S1, W, S2, W) :-
                S1 \== S2,
                attribute(S1, end, E1), attribute(S2, start, St2),
                St2 >= E1,
                duty_limit(W, min_rest, Min),
                St2 - E1 < Min)).

%% ── assign_domain/2 ──────────────────────────────────────────────────────────

:- begin_tests(assign_domain).

test(domain_unfiltered, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_domain(s1, D), assertion(D == [a, b, c]).

test(domain_filtered_by_reject, [setup((setup_three_slots, setup_reject_s1_a)), cleanup(cleanup_all)]) :-
    assign_domain(s1, D), assertion(D == [b, c]).

:- end_tests(assign_domain).

%% ── assign_solve/2,3 ─────────────────────────────────────────────────────────

:- begin_tests(assign_solve).

test(all_distinct_solution, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], R),
    assertion(R = solution(_, _)),
    R = solution(A, N),
    findall(X, member(_-X, A), Xs), msort(Xs, Sorted),
    assertion(Sorted == [a, b, c]),
    assertion(N > 0).

test(solution_lists_vars_in_given_order, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], solution(A, _)),
    findall(V, member(V-_, A), Vs),
    assertion(Vs == [s1, s2, s3]).

test(unary_reject_respected, [setup((setup_three_slots, setup_reject_s1_a)), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], solution(A, _)),
    assertion(\+ memberchk(s1-a, A)).

test(empty_domain_reported, [setup((setup_three_slots, setup_reject_all_s1)), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], R),
    assertion(R == unsat(empty_domain(s1))).

test(undeclared_domain_is_empty, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_solve([s1, zz], R),
    assertion(R == unsat(empty_domain(zz))).

test(unsat_after_exhaustive_search, [setup(setup_three_slots_two_values), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], R),
    assertion(R = unsat(N)), R = unsat(N), assertion(integer(N)), assertion(N > 0).

test(pair_reject_respected, [setup((setup_three_slots, setup_pair_s1a_s2b)), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], solution(A, _)),
    assertion(\+ (memberchk(s1-a, A), memberchk(s2-b, A))),
    assign_violations(A, Vs), assertion(Vs == []).

test(budget_exhausted, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_solve([s1, s2, s3], 1, R),
    assertion(R == budget_exhausted(1)).

test(empty_problem_is_trivially_solved, [cleanup(cleanup_all)]) :-
    assign_solve([], R),
    assertion(R == solution([], 0)).

:- end_tests(assign_solve).

%% ── assign_best/3 ────────────────────────────────────────────────────────────

:- begin_tests(assign_best).

test(best_picks_cheapest, [setup((setup_three_slots, setup_costs_s1)), cleanup(cleanup_all)]) :-
    assign_best([s1, s2, s3], 1000, R),
    assertion(R = best(_, 1, _, complete)),
    R = best(A, _, _, _),
    assertion(memberchk(s1-b, A)).

test(best_without_costs_is_zero, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_best([s1, s2, s3], 1000, best(_, C, _, Flag)),
    assertion(C == 0), assertion(Flag == complete).

test(best_unsat, [setup(setup_three_slots_two_values), cleanup(cleanup_all)]) :-
    assign_best([s1, s2, s3], 1000, R),
    assertion(R = unsat(_)).

test(best_budget_exhausted_with_incumbent, [setup((setup_three_slots, setup_costs_s1)), cleanup(cleanup_all)]) :-
    %% enough budget to reach one leaf, not enough to prove optimality
    assign_best([s1, s2, s3], 4, R),
    assertion(( R = best(_, _, _, budget_exhausted) ; R = budget_exhausted(_) )).

:- end_tests(assign_best).

%% ── assign_violations/2 ──────────────────────────────────────────────────────

:- begin_tests(assign_violations).

test(consistent_assignment_has_no_violations, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_violations([s1-a, s2-b, s3-c], Vs), assertion(Vs == []).

test(distinct_violation, [setup(setup_three_slots), cleanup(cleanup_all)]) :-
    assign_violations([s1-a, s2-a, s3-b], Vs),
    assertion(memberchk(distinct(day, s1, s2), Vs)),
    assertion(length(Vs, 1)).

test(rejected_and_pair_violations, [setup((setup_three_slots, setup_reject_s1_a, setup_pair_s1a_s2b)), cleanup(cleanup_all)]) :-
    assign_violations([s1-a, s2-b, s3-c], Vs),
    assertion(memberchk(rejected(s1, a), Vs)),
    assertion(memberchk(pair(s1, a, s2, b), Vs)).

:- end_tests(assign_violations).

%% ── Composition with duty ────────────────────────────────────────────────────

:- begin_tests(assign_over_duty).

test(fill_two_shifts_respecting_fitness_and_rest, [setup(setup_duty_scene), cleanup(cleanup_all)]) :-
    %% pm needs icu_cert → alvarez; am then cannot be alvarez (60 min rest) → chen
    assign_solve([am, pm], R),
    assertion(R = solution([am-chen, pm-alvarez], _)).

test(unary_hook_removes_unqualified, [setup(setup_duty_scene), cleanup(cleanup_all)]) :-
    assign_domain(pm, D), assertion(D == [alvarez]).

test(violations_explain_a_bad_roster, [setup(setup_duty_scene), cleanup(cleanup_all)]) :-
    assign_violations([am-alvarez, pm-alvarez], Vs),
    assertion(memberchk(pair(am, alvarez, pm, alvarez), Vs)).

:- end_tests(assign_over_duty).
