:- use_module(library(plunit)).

:- consult('../../modules/engineering/release_gate/release_gate').

%% A sample repository whose main branch requires ci/test and lint, one
%% approval, and 80% coverage. Unknown on the platform (no required list, no
%% results, no day during a freeze) shows here as a failure: the rules cannot
%% tell "no" from "not loaded", which battery_needs/4 and the conditional
%% facts declare.

rgt(S, A, V) :- assertz(attribute(S, A, V)).
rgt_drop(S, A, V) :- retract(attribute(S, A, V)).

rgt_setup_gate :-
    rgt(rc_test, requires_check, 'ci/test'),
    rgt(rc_lint, requires_check, lint),
    rgt(gate, min_coverage, 80).

rgt_change(C, Head, Coverage) :-
    rgt(C, head, Head),
    rgt(C, coverage, Coverage).

rgt_check(Id, C, Name, Outcome, Sha) :-
    rgt(Id, check_of, C),
    rgt(Id, check_name, Name),
    rgt(Id, outcome, Outcome),
    rgt(Id, on_commit, Sha).

rgt_review(Id, C, Who, Verdict, Order) :-
    rgt(Id, review_of, C),
    rgt(Id, reviewer, Who),
    rgt(Id, verdict, Verdict),
    rgt(Id, order, Order).

rgt_green(C, Head) :-
    rgt_check(k_test, C, 'ci/test', success, Head),
    rgt_check(k_lint, C, lint, success, Head).

rgt_setup_ready :-
    rgt_setup_gate, rgt_change(pr_1, h1, 86.5), rgt_green(pr_1, h1),
    rgt_review(v1, pr_1, ana, approved, 1).

rgt_setup_failing :-
    rgt_setup_gate, rgt_change(pr_2, h2, 90),
    rgt_check(k_test, pr_2, 'ci/test', failure, h2),
    rgt_check(k_lint, pr_2, lint, success, h2),
    rgt_review(v1, pr_2, ana, approved, 1).

rgt_setup_rerun :-
    rgt_setup_failing,
    rgt_check(k_test2, pr_2, 'ci/test', success, h2),
    rgt(k_test, order, 1),
    rgt(k_test2, order, 2).

rgt_setup_stale :-
    rgt_setup_gate, rgt_change(pr_3, h3_new, 90),
    rgt_check(k_test, pr_3, 'ci/test', success, h3_old),
    rgt_check(k_lint, pr_3, lint, success, h3_new),
    rgt_review(v1, pr_3, ana, approved, 1).

rgt_setup_changes_requested :-
    rgt_setup_gate, rgt_change(pr_4, h4, 90), rgt_green(pr_4, h4),
    rgt_review(v1, pr_4, ana, approved, 1),
    rgt_review(v2, pr_4, raj, changes_requested, 2),
    rgt_review(v3, pr_4, raj, commented, 3).

rgt_setup_low_coverage :-
    rgt_setup_gate, rgt_change(pr_5, h5, 71.2), rgt_green(pr_5, h5),
    rgt_review(v1, pr_5, ana, approved, 1).

rgt_setup_freeze :-
    rgt_setup_ready,
    rgt(f_q4, freeze_from, 20810),
    rgt(f_q4, freeze_until, 20820).

rgt_setup_no_required :-
    rgt_change(pr_6, h6, 90), rgt_green(pr_6, h6), rgt_review(v1, pr_6, ana, approved, 1).

rgt_setup_no_coverage :-
    rgt_setup_gate, rgt(pr_7, head, h7), rgt_green(pr_7, h7),
    rgt_review(v1, pr_7, ana, approved, 1).

rgt_blockers(C, Bs) :- findall(B, gate_blocker(C, B), Bs0), sort(Bs0, Bs).

:- begin_tests(release_gate).

test(ready, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    assertion(release_ready(pr_1)),
    assertion(approval_count(pr_1, 1)).

test(failed_check_blocks, [setup(rgt_setup_failing), cleanup(clear_facts)]) :-
    assertion(\+ release_ready(pr_2)),
    assertion(rgt_blockers(pr_2, [check_failed('ci/test')])).

test(latest_rerun_counts, [setup(rgt_setup_rerun), cleanup(clear_facts)]) :-
    assertion(check_outcome(pr_2, 'ci/test', passed)),
    assertion(release_ready(pr_2)).

test(result_for_old_commit_is_missing, [setup(rgt_setup_stale), cleanup(clear_facts)]) :-
    assertion(rgt_blockers(pr_3, [check_missing('ci/test')])).

%% Unknown on the platform (on_commit is required): a result whose commit is
%% not known does not count.
test(result_without_commit, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    rgt_drop(k_test, on_commit, h1),
    assertion(rgt_blockers(pr_1, [check_missing('ci/test')])).

test(changes_requested_stands_over_a_comment, [setup(rgt_setup_changes_requested), cleanup(clear_facts)]) :-
    assertion(rgt_blockers(pr_4, [changes_requested(raj)])),
    assertion(approval_count(pr_4, 1)).

test(coverage_below_minimum, [setup(rgt_setup_low_coverage), cleanup(clear_facts)]) :-
    assertion(rgt_blockers(pr_5, [coverage_below(71.2, 80)])).

test(two_approvals_needed, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    rgt(gate, min_approvals, 2),
    assertion(rgt_blockers(pr_1, [approvals_short(1, 2)])).

test(stale_approval_dismissed, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    rgt(v1, on_commit, h0),
    assertion(release_ready(pr_1)),
    rgt(gate, dismiss_stale_approvals, true),
    assertion(rgt_blockers(pr_1, [approvals_short(0, 1)])).

test(inside_a_freeze, [setup(rgt_setup_freeze), cleanup(clear_facts)]) :-
    rgt(today, absolute_days, 20815),
    assertion(rgt_blockers(pr_1, [change_freeze(f_q4)])),
    assertion(\+ release_ready(pr_1)).

test(emergency_ships_through_a_freeze, [setup(rgt_setup_freeze), cleanup(clear_facts)]) :-
    rgt(today, absolute_days, 20815),
    rgt(pr_1, emergency, true),
    assertion(release_ready(pr_1)).

test(outside_the_freeze, [setup(rgt_setup_freeze), cleanup(clear_facts)]) :-
    rgt(today, absolute_days, 20800),
    assertion(release_ready(pr_1)).

%% Unknown on the platform: a freeze is recorded and today is not.
test(freeze_without_today, [setup(rgt_setup_freeze), cleanup(clear_facts)]) :-
    assertion(\+ release_ready(pr_1)),
    assertion(rgt_blockers(pr_1, [])).

%% Unknown on the platform: the head commit is not known, so no result can
%% be told fresh.
test(no_head, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    rgt_drop(pr_1, head, h1),
    assertion(\+ release_ready(pr_1)).

test(conflicting_heads, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    rgt(pr_1, head, h_other),
    assertion(\+ release_ready(pr_1)),
    assertion(rgt_blockers(pr_1, [check_missing('ci/test'), check_missing(lint)])).

test(required_app, [setup(rgt_setup_ready), cleanup(clear_facts)]) :-
    rgt(rc_test, requires_app, 15368),
    assertion(rgt_blockers(pr_1, [check_missing('ci/test')])),
    rgt(k_test, app_id, 999),
    assertion(rgt_blockers(pr_1, [check_missing('ci/test')])),
    rgt(k_test2, check_of, pr_1),
    rgt(k_test2, check_name, 'ci/test'),
    rgt(k_test2, outcome, success),
    rgt(k_test2, app_id, 15368),
    rgt(k_test2, on_commit, h1),
    assertion(release_ready(pr_1)).

%% Unknown on the platform: no required checks.
test(no_required_list, [setup(rgt_setup_no_required), cleanup(clear_facts)]) :-
    assertion(\+ release_ready(pr_6)).

%% Unknown on the platform: a minimum is set and the coverage is not loaded.
test(no_coverage_loaded, [setup(rgt_setup_no_coverage), cleanup(clear_facts)]) :-
    assertion(\+ release_ready(pr_7)),
    assertion(rgt_blockers(pr_7, [])).

:- end_tests(release_gate).
