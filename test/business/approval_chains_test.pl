:- use_module(library(plunit)).

:- consult('../../modules/business/approval_chains/approval_chains').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_two_step_chain :-
    assertz(attribute(req_001_step1, request,  req_001)),
    assertz(attribute(req_001_step1, approver, manager)),
    assertz(attribute(req_001_step1, step,     1)),
    assertz(attribute(req_001_step2, request,  req_001)),
    assertz(attribute(req_001_step2, approver, finance)),
    assertz(attribute(req_001_step2, step,     2)).

setup_manager_approved :-
    assertz(relation(req_001, approved_by, manager)).

setup_both_approved :-
    assertz(relation(req_001, approved_by, manager)),
    assertz(relation(req_001, approved_by, finance)).

setup_finance_rejected :-
    assertz(relation(req_001, rejected_by, finance)),
    assertz(attribute(req_001, rejection_reason, "Budget exceeded")).

setup_delegation :-
    assertz(relation(manager, delegated_to, deputy)),
    assertz(relation(req_001, approved_by, deputy)).

setup_amount_threshold :-
    assertz(attribute(high_value_rule, threshold, 10000)),
    assertz(attribute(high_value_rule, approver,  cfo)),
    assertz(attribute(req_002, amount, 15000)).

setup_amount_below_threshold :-
    assertz(attribute(high_value_rule, threshold, 10000)),
    assertz(attribute(high_value_rule, approver,  cfo)),
    assertz(attribute(req_002, amount, 5000)).

setup_fully_approved :-
    setup_two_step_chain,
    setup_both_approved.

setup_chain_with_manager_approved :-
    setup_two_step_chain,
    setup_manager_approved.

setup_chain_rejected :-
    setup_two_step_chain,
    setup_finance_rejected.

setup_delegation_chain :-
    setup_two_step_chain,
    setup_delegation.

%% ── approval_required/2 ──────────────────────────────────────────────────────

:- begin_tests(approval_required).

test(manager_required, [setup(setup_two_step_chain), cleanup(clear_facts)]) :-
    assertion(approval_required(req_001, manager)).

test(finance_required, [setup(setup_two_step_chain), cleanup(clear_facts)]) :-
    assertion(approval_required(req_001, finance)).

test(amount_triggers_cfo, [setup(setup_amount_threshold), cleanup(clear_facts)]) :-
    assertion(approval_required(req_002, cfo)).

test(amount_below_threshold_no_cfo, [setup(setup_amount_below_threshold), cleanup(clear_facts)]) :-
    assertion(\+ approval_required(req_002, cfo)).

:- end_tests(approval_required).

%% ── approval_granted/2 ───────────────────────────────────────────────────────

:- begin_tests(approval_granted).

test(direct_grant, [setup((setup_two_step_chain, setup_manager_approved)), cleanup(clear_facts)]) :-
    assertion(approval_granted(req_001, manager)).

test(not_granted_unapproved, [setup(setup_two_step_chain), cleanup(clear_facts)]) :-
    assertion(\+ approval_granted(req_001, manager)).

test(delegated_grant, [setup(setup_delegation_chain), cleanup(clear_facts)]) :-
    assertion(approval_granted(req_001, manager)).

:- end_tests(approval_granted).

%% ── fully_approved/1 ─────────────────────────────────────────────────────────

:- begin_tests(fully_approved).

test(fully_approved_when_all_approve, [setup(setup_fully_approved), cleanup(clear_facts)]) :-
    assertion(fully_approved(req_001)).

test(not_fully_approved_pending, [setup(setup_chain_with_manager_approved), cleanup(clear_facts)]) :-
    assertion(\+ fully_approved(req_001)).

test(not_fully_approved_when_rejected, [setup(setup_chain_rejected), cleanup(clear_facts)]) :-
    assertion(\+ fully_approved(req_001)).

:- end_tests(fully_approved).

%% ── next_approver/2 ──────────────────────────────────────────────────────────

:- begin_tests(next_approver).

test(first_approver_when_none_granted, [setup(setup_two_step_chain), cleanup(clear_facts)]) :-
    next_approver(req_001, A), assertion(A == manager).

test(next_approver_after_manager, [setup(setup_chain_with_manager_approved), cleanup(clear_facts)]) :-
    next_approver(req_001, A), assertion(A == finance).

:- end_tests(next_approver).

%% ── approval_blocked/2 ───────────────────────────────────────────────────────

:- begin_tests(approval_blocked).

test(blocked_awaiting, [setup(setup_two_step_chain), cleanup(clear_facts)]) :-
    approval_blocked(req_001, Reason),
    assertion(Reason == awaiting(manager)).

test(blocked_by_rejection, [setup(setup_chain_rejected), cleanup(clear_facts)]) :-
    approval_blocked(req_001, Reason),
    assertion(Reason == rejected(finance, "Budget exceeded")).

:- end_tests(approval_blocked).
