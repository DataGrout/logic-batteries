%% Battery: approval_chains v1.0.0
%% Exports: approval_required/2, approval_granted/2, fully_approved/1,
%%          next_approver/2, approval_blocked/2

battery_module(approval_chains, '1.0.0', auto).

battery_export(approval_chains, 'approval_required/2', 'approval_required(Request, Approver) — Approver must approve Request').
battery_export(approval_chains, 'approval_granted/2',  'approval_granted(Request, Approver) — Approver has approved Request').
battery_export(approval_chains, 'fully_approved/1',    'fully_approved(Request) — all required approvals have been received').
battery_export(approval_chains, 'next_approver/2',     'next_approver(Request, Approver) — Approver is the next pending approver in sequence').
battery_export(approval_chains, 'approval_blocked/2',  'approval_blocked(Request, Reason) — approval cannot proceed; Reason explains why').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). An approval step
%% is its own subject naming a request, an approver and a position; a
%% threshold rule is a subject with a threshold and an approver, and applies to
%% every request. A request is named by its steps and carries an amount when
%% threshold rules should see it; approvals, rejections and delegations are
%% edges.

battery_input(approval_chains, approval_step, attribute(request), ref(request), key,
    'The request this step belongs to.').
battery_input(approval_chains, approval_step, attribute(approver), ref(approver), required,
    'Who must approve at this step.').
battery_input(approval_chains, approval_step, attribute(step), integer, required,
    'Position in the chain; steps are approved in ascending order.').
battery_input(approval_chains, threshold_rule, attribute(threshold), number, key,
    'Amount above which every request also needs this rule''s approver, after the numbered steps.').
battery_input(approval_chains, threshold_rule, attribute(approver), ref(approver), required,
    'Who must approve a request whose amount exceeds the threshold.').
battery_input(approval_chains, request, attribute(amount), number, key,
    'Amount compared against every threshold rule; without one no rule applies.').
battery_input(approval_chains, request, relation(approved_by), ref(approver), optional,
    'An approver (or their delegate) who has approved the request.').
battery_input(approval_chains, request, relation(rejected_by), ref(approver), optional,
    'An approver who rejected the request; any rejection stops the chain.').
battery_input(approval_chains, request, attribute(rejection_reason), atom, default(unspecified),
    'Why the request was rejected, returned by approval_blocked.').
battery_input(approval_chains, approver, relation(delegated_to), ref(approver), key,
    'Someone whose approval counts as this approver''s.').

%% ── Approval Chain Data Model ─────────────────────────────────────────────────
%%
%% Approvers in order (step determines sequence):
%%   attribute(req_001_step1, request,  req_001)
%%   attribute(req_001_step1, approver, manager)
%%   attribute(req_001_step1, step,     1)
%%   attribute(req_001_step2, request,  req_001)
%%   attribute(req_001_step2, approver, finance)
%%   attribute(req_001_step2, step,     2)
%%
%% Granted approvals:
%%   relation(req_001, approved_by, manager)
%%
%% Rejected:
%%   relation(req_001, rejected_by, finance)
%%   attribute(req_001, rejection_reason, "Budget exceeded")
%%
%% Delegation:
%%   relation(manager, delegated_to, deputy)    %% deputy can approve in manager's place
%%
%% Amount-based thresholds (auto-add approver when amount exceeds limit):
%%   attribute(finance_approval, threshold, 10000)
%%   attribute(finance_approval, approver,  cfo)
%%   attribute(req_001, amount, 15000)

%% approval_required(+Request, ?Approver)
approval_required(Request, Approver) :-
    approval_required_step(Request, Approver, _).

approval_required_step(Request, Approver, Step) :-
    attribute(StepKey, request,  Request),
    attribute(StepKey, approver, Approver),
    attribute(StepKey, step,     Step).
approval_required_step(Request, Approver, auto) :-
    attribute(Rule, threshold, Limit),
    attribute(Rule, approver,  Approver),
    attribute(Request, amount, Amt),
    Amt > Limit.

%% approval_granted(+Request, ?Approver)  — including delegated
%% Unbound, Approver ranges over everyone whose approval is on record: each
%% direct approver, and each required approver whose delegate approved. An
%% approver granted both ways is reported once.
approval_granted(Request, Approver) :-
    setof(A, approval_granted_by(Request, A), Approvers),
    member(Approver, Approvers).

approval_granted_by(Request, Approver) :-
    relation(Request, approved_by, Approver).
approval_granted_by(Request, Approver) :-
    approval_required(Request, Approver),
    relation(Approver, delegated_to, Delegate),
    relation(Request, approved_by, Delegate).

%% fully_approved(+Request)
fully_approved(Request) :-
    \+ relation(Request, rejected_by, _),
    \+ ( approval_required(Request, Approver),
         \+ approval_granted(Request, Approver) ).

%% next_approver(+Request, -Approver)
next_approver(Request, Approver) :-
    \+ relation(Request, rejected_by, _),
    findall(Step-App, approval_required_step(Request, App, Step), Pairs),
    sort(Pairs, Sorted),                   %% numbered steps, then auto (atoms sort after numbers)
    member(_-Approver, Sorted),
    \+ approval_granted(Request, Approver), !.

%% approval_blocked(+Request, -Reason)
approval_blocked(Request, rejected(By, Reason)) :-
    relation(Request, rejected_by, By),
    ( attribute(Request, rejection_reason, Reason) -> true ; Reason = unspecified ), !.
approval_blocked(Request, awaiting(Approver)) :-
    next_approver(Request, Approver).
