%% Battery: release_gate v1.0.0
%% Requires: (nothing)
%% Exports: release_ready/1, gate_blocker/2, check_outcome/3, approval_count/2,
%%          approved_by/2, in_freeze/2

:- dynamic(attribute/3).

battery_module(release_gate, '1.0.0', auto).

battery_export(release_gate, 'release_ready/1',
    'release_ready(Change) — every required check passed on the change''s head, it has the approvals the gate asks for and no outstanding request for changes, its coverage meets the minimum, and it is outside any change freeze').
battery_export(release_gate, 'gate_blocker/2',
    'gate_blocker(Change, Reason) — why the change cannot ship yet: check_failed(Check), check_pending(Check), check_missing(Check), approvals_short(Have, Need), changes_requested(Reviewer), coverage_below(Have, Min) or change_freeze(Freeze)').
battery_export(release_gate, 'check_outcome/3',
    'check_outcome(Change, Check, Outcome) — the latest result of a required check on the change: passed, failed, pending or missing').
battery_export(release_gate, 'approval_count/2',
    'approval_count(Change, N) — how many reviewers'' latest reviews approve the change').
battery_export(release_gate, 'approved_by/2',
    'approved_by(Change, Reviewer) — Reviewer''s latest review approves the change').
battery_export(release_gate, 'in_freeze/2',
    'in_freeze(Change, Freeze) — today falls inside Freeze and the change is not an emergency').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). A change is a pull
%% or merge request. Each check result and each review is its own subject
%% pointing at the change, so re-runs and second reviews keep their history:
%% the latest one counts. Required checks and freezes are records, the way a
%% branch protection rule and a release calendar hold them.

battery_input(release_gate, change, attribute(number), integer, key,
    'The change''s number in its repository.').
battery_input(release_gate, change, attribute(head), atom, required,
    'The commit the change would merge (its head SHA). Results and approvals for another commit are stale, and without it none can be told fresh.').
battery_input(release_gate, change, attribute(coverage), number, conditional,
    'Test coverage of the head commit, in percent. Needed when the gate sets min_coverage.').
battery_input(release_gate, change, attribute(emergency), bool, default(false),
    'true for a change cleared to ship through a change freeze.').
battery_input(release_gate, check, attribute(check_of), ref(change), key,
    'The change the result is for.').
battery_input(release_gate, check, attribute(check_name), atom, required,
    'The check''s name as the required list spells it (ci/test, lint).').
battery_input(release_gate, check, attribute(outcome),
    enum([success, failure, neutral, skipped, cancelled, timed_out, action_required, stale, pending]), required,
    'How it ended; pending while queued or running. success, neutral and skipped pass.').
battery_input(release_gate, check, attribute(on_commit), atom, required,
    'The commit it ran on. Only a result for the change''s head counts.').
battery_input(release_gate, check, attribute(order), integer, optional,
    'Position among results of the same check; the highest is the latest re-run.').
battery_input(release_gate, check, attribute(app_id), integer, optional,
    'The app that reported the result. Counts against a required check limited to an app.').
battery_input(release_gate, review, attribute(review_of), ref(change), key,
    'The change the review is of.').
battery_input(release_gate, review, attribute(reviewer), atom, required,
    'Who reviewed.').
battery_input(release_gate, review, attribute(verdict), enum([approved, changes_requested, commented, dismissed]), required,
    'What the review said. A comment-only review leaves the reviewer''s earlier verdict standing.').
battery_input(release_gate, review, attribute(on_commit), atom, optional,
    'The commit reviewed. When the gate dismisses stale approvals, only an approval of the head counts.').
battery_input(release_gate, review, attribute(order), integer, optional,
    'Position among the reviewer''s reviews; the highest is the latest.').
battery_input(release_gate, required_check, attribute(requires_check), atom, key,
    'A check every change must pass.').
battery_input(release_gate, required_check, attribute(requires_app), integer, optional,
    'The app whose result counts for this check; absent, a result from any app counts.').
battery_input(release_gate, freeze, attribute(freeze_from), days, key,
    'The first day of a change freeze.').
battery_input(release_gate, freeze, attribute(freeze_until), days, required,
    'The last day of the freeze, inclusive.').
battery_input(release_gate, fixed(today), attribute(absolute_days), days, conditional,
    'Today as a day count from 1970-01-01, the shared convention. Needed when a freeze is recorded.').
battery_input(release_gate, fixed(gate), attribute(min_approvals), integer, default(1),
    'Approving reviewers a change needs.').
battery_input(release_gate, fixed(gate), attribute(min_coverage), number, optional,
    'Coverage, in percent, the head commit must reach. Absent, coverage is not checked.').
battery_input(release_gate, fixed(gate), attribute(dismiss_stale_approvals), bool, default(false),
    'true when an approval of an earlier commit no longer counts once new commits are pushed.').

%% Without the required list nothing says what passing means, and a change
%% none of whose results were loaded has not failed anything.
battery_needs(release_gate, required_check, any,
    'The checks a change must pass, supplied as records (a branch protection rule). Without them no change can be judged ready.').
battery_needs(release_gate, check, attribute(check_of),
    'At least one check result for the change. A change whose results were never loaded is unknown, not failing.').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%%   attribute(pr_7, number, 7)             attribute(rc_test, requires_check, 'ci/test')
%%   attribute(pr_7, head, c0ffee)
%%   attribute(pr_7, coverage, 84.2)        attribute(gate, min_approvals, 2)
%%   attribute(k1, check_of, pr_7)          attribute(gate, min_coverage, 80)
%%   attribute(k1, check_name, 'ci/test')   attribute(f_q4, freeze_from, 20810)
%%   attribute(k1, outcome, success)        attribute(f_q4, freeze_until, 20820)
%%   attribute(k1, on_commit, c0ffee)       attribute(today, absolute_days, 20800)
%%   attribute(r1, review_of, pr_7)
%%   attribute(r1, reviewer, ana)
%%   attribute(r1, verdict, approved)

%% ── Changes ──────────────────────────────────────────────────────────────────

rg_target(C) :-
    ( var(C) -> rg_changes(Cs), member(C, Cs) ; true ).

rg_changes(Cs) :-
    findall(C, rg_change_ref(C), Cs0),
    sort(Cs0, Cs).

rg_change_ref(C) :- attribute(C, number, _).
rg_change_ref(C) :- attribute(C, head, _).
rg_change_ref(C) :- attribute(_, check_of, C).
rg_change_ref(C) :- attribute(_, review_of, C).

rg_order(S, O) :- ( attribute(S, order, O0) -> O = O0 ; O = 0 ).

%% The change's head, when exactly one is recorded. Two heads disagree about
%% which commit would merge, so neither can make a result fresh.
rg_head(C, Head) :-
    findall(H, attribute(C, head, H), Hs0),
    sort(Hs0, [Head]).

%% A result or review is fresh when it is for the change's head. One whose
%% commit is not known cannot be told fresh, and does not count.
rg_fresh(C, S) :-
    rg_head(C, Head),
    attribute(S, on_commit, Head).

rg_setting(Name, Default, Value) :-
    ( attribute(gate, Name, V) -> Value = V ; Value = Default ).

%% ── Checks ───────────────────────────────────────────────────────────────────

rg_required(Names) :-
    findall(N, attribute(_, requires_check, N), Ns),
    sort(Ns, Names).

rg_result(C, Name, O-S) :-
    attribute(S, check_of, C),
    attribute(S, check_name, Name),
    rg_fresh(C, S),
    rg_from_required_app(Name, S),
    rg_order(S, O).

%% A required check limited to an app counts only that app's results: a
%% same-named check from another app does not stand in for it.
rg_from_required_app(Name, S) :-
    (   attribute(R, requires_check, Name), attribute(R, requires_app, _)
    ->  attribute(R2, requires_check, Name),
        attribute(R2, requires_app, App),
        attribute(S, app_id, App),
        !
    ;   true
    ).

%% rg_latest(+C, +Name, -Outcome): the latest fresh result's outcome, or
%% missing. The class is computed unbound and compared after, since
%% rg_outcome_class/2 cuts on its first argument.
rg_latest(C, Name, Outcome) :-
    findall(P, rg_result(C, Name, P), Ps0),
    keysort(Ps0, Ps1),
    reverse(Ps1, Ps),
    (   Ps = [_-S|_], attribute(S, outcome, O)
    ->  rg_outcome_class(O, Class)
    ;   Class = missing
    ),
    Outcome = Class.

rg_outcome_class(O, passed) :- memberchk(O, [success, neutral, skipped]), !.
rg_outcome_class(pending, pending) :- !.
rg_outcome_class(_, failed).

%% ── Reviews ──────────────────────────────────────────────────────────────────

rg_reviewers(C, Rs) :-
    findall(R, ( attribute(V, review_of, C), attribute(V, reviewer, R) ), Rs0),
    sort(Rs0, Rs).

%% rg_standing(+C, +Reviewer, -Verdict, -Review): the reviewer's latest review
%% that settles anything; a comment-only review settles nothing.
rg_standing(C, R, Verdict, V) :-
    findall(O-V0, rg_settling(C, R, O, V0), Ps0),
    keysort(Ps0, Ps1),
    reverse(Ps1, [_-V|_]),
    attribute(V, verdict, Verdict).

rg_settling(C, R, O, V) :-
    attribute(V, review_of, C),
    attribute(V, reviewer, R),
    attribute(V, verdict, Verdict),
    Verdict \== commented,
    rg_order(V, O).

rg_counts_as_approval(C, R) :-
    rg_standing(C, R, approved, V),
    (   rg_setting(dismiss_stale_approvals, false, true)
    ->  rg_fresh(C, V)
    ;   true
    ).

%% ── Freezes ──────────────────────────────────────────────────────────────────

rg_freeze_on(Day, F) :-
    attribute(F, freeze_from, From),
    attribute(F, freeze_until, Until),
    Day >= From,
    Day =< Until.

rg_emergency(C) :- attribute(C, emergency, true).

%% Whether the freeze question is settled: no freeze to fall in, an emergency
%% change, or a known day. Without today a freeze cannot be ruled out.
rg_freeze_settled(C) :- rg_emergency(C), !.
rg_freeze_settled(_) :- \+ attribute(_, freeze_from, _), !.
rg_freeze_settled(_) :- attribute(today, absolute_days, _).

rg_coverage_settled(C) :-
    (   attribute(gate, min_coverage, _)
    ->  attribute(C, coverage, _)
    ;   true
    ).

%% ── Exports ──────────────────────────────────────────────────────────────────

%% check_outcome(?Change, ?Check, ?Outcome)
check_outcome(C, Name, Outcome) :-
    rg_target(C),
    rg_required(Names),
    member(Name, Names),
    rg_latest(C, Name, Outcome).

%% approved_by(?Change, ?Reviewer)
approved_by(C, R) :-
    rg_target(C),
    rg_reviewers(C, Rs),
    member(R, Rs),
    rg_counts_as_approval(C, R).

%% approval_count(?Change, ?N)
approval_count(C, N) :-
    rg_target(C),
    findall(R, approved_by(C, R), Rs),
    length(Rs, N).

%% in_freeze(?Change, ?Freeze)
in_freeze(C, F) :-
    rg_target(C),
    \+ rg_emergency(C),
    attribute(today, absolute_days, Day),
    rg_freeze_on(Day, F).

%% gate_blocker(?Change, ?Reason)
gate_blocker(C, check_failed(Name)) :-
    check_outcome(C, Name, failed).
gate_blocker(C, check_pending(Name)) :-
    check_outcome(C, Name, pending).
gate_blocker(C, check_missing(Name)) :-
    check_outcome(C, Name, missing).
gate_blocker(C, approvals_short(Have, Need)) :-
    approval_count(C, Have),
    rg_setting(min_approvals, 1, Need),
    Have < Need.
gate_blocker(C, changes_requested(R)) :-
    rg_target(C),
    rg_reviewers(C, Rs),
    member(R, Rs),
    rg_standing(C, R, changes_requested, _).
gate_blocker(C, coverage_below(Have, Min)) :-
    rg_target(C),
    attribute(gate, min_coverage, Min),
    attribute(C, coverage, Have),
    Have < Min.
gate_blocker(C, change_freeze(F)) :-
    in_freeze(C, F).

%% release_ready(?Change)
release_ready(C) :-
    rg_target(C),
    rg_head(C, _),
    rg_required([_|_]),
    \+ gate_blocker(C, _),
    rg_freeze_settled(C),
    rg_coverage_settled(C).
