:- use_module(library(plunit)).

:- consult('../../modules/business/request_policy/request_policy').

%% Cases from the synthetic set with planted answers (P1-P9). Limits: meals at
%% most 75 with a receipt over 25; travel at most 2,000 with pre-approval over
%% 1,000. Everything else uses the policy defaults (receipt over 25,
%% pre-approval over 1,000, submit within 30 days).

setup_limits :-
    assertz(attribute(lim_meals,  applies_to, meals)),
    assertz(attribute(lim_meals,  max_amount, 75)),
    assertz(attribute(lim_meals,  receipt_over, 25)),
    assertz(attribute(lim_travel, applies_to, travel)),
    assertz(attribute(lim_travel, max_amount, 2000)),
    assertz(attribute(lim_travel, preapproval_over, 1000)).

req(R, Pairs) :- setup_limits, rp_assert(R, Pairs).

rp_assert(_, []).
rp_assert(R, [A-V|T]) :- assertz(attribute(R, A, V)), rp_assert(R, T).

setup_p1 :- req(p1, [amount-60, category-meals, receipt-true, incurred_on-20762, submitted_on-20762]).
setup_p2 :- req(p2, [amount-120, category-meals, receipt-true, submitted_on-20762]).
setup_p3 :- req(p3, [amount-1500, category-travel, receipt-true]).
setup_p4 :- req(p4, [amount-300, category-software]).
setup_p5 :- req(p5, [amount-40, category-travel, receipt-true, incurred_on-20711, submitted_on-20762]).
setup_p6 :- req(p6, [amount-1800, category-travel, receipt-true, pre_approved-true]).
setup_p7 :- req(p7, [category-meals, receipt-true]).
setup_p8 :- req(p8, [amount-1200, category-hardware, pre_approved-true, receipt-true]).
setup_p9 :- req(p9, [amount-2500, category-travel, receipt-true]).
setup_policy :- setup_p4, assertz(attribute(policy, receipt_over, 500)).

violations(R, Rs) :- findall(X, request_violation(R, X), Rs0), sort(Rs0, Rs).

:- begin_tests(request_policy).

test(p1_compliant, [setup(setup_p1), cleanup(clear_facts)]) :-
    assertion(request_compliant(p1)).

test(p2_over_category_limit, [setup(setup_p2), cleanup(clear_facts)]) :-
    assertion(violations(p2, [over_limit])).

test(p3_preapproval_not_mentioned, [setup(setup_p3), cleanup(clear_facts)]) :-
    assertion(violations(p3, [needs_preapproval])).

test(p4_receipt_not_mentioned, [setup(setup_p4), cleanup(clear_facts)]) :-
    assertion(violations(p4, [missing_receipt])).

test(p5_late_submission, [setup(setup_p5), cleanup(clear_facts)]) :-
    assertion(violations(p5, [late_submission])).

test(p6_preapproved_from_an_approval, [setup(setup_p6), cleanup(clear_facts)]) :-
    assertion(request_compliant(p6)).

%% Unknown on the platform: no amount, so p7 is not a request.
test(p7_no_amount, [setup(setup_p7), cleanup(clear_facts)]) :-
    assertion(\+ request_compliant(p7)).

test(p8_no_category_row_uses_defaults, [setup(setup_p8), cleanup(clear_facts)]) :-
    assertion(needs_preapproval(p8)),
    assertion(request_compliant(p8)).

test(p9_two_violations, [setup(setup_p9), cleanup(clear_facts)]) :-
    assertion(violations(p9, [needs_preapproval, over_limit])).

test(policy_overrides_the_default, [setup(setup_policy), cleanup(clear_facts)]) :-
    assertion(\+ needs_receipt(p4)),
    assertion(request_compliant(p4)).

:- end_tests(request_policy).
