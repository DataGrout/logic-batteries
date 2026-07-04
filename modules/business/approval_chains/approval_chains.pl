%% Battery: approval_chains v1.0.0
%% Exports: approval_required/2, approval_granted/2, fully_approved/1,
%%          next_approver/2, approval_blocked/2

battery_module(approval_chains, '1.0.0', auto).

battery_export(approval_chains, 'approval_required/2', 'approval_required(Request, Approver) — Approver must approve Request').
battery_export(approval_chains, 'approval_granted/2',  'approval_granted(Request, Approver) — Approver has approved Request').
battery_export(approval_chains, 'fully_approved/1',    'fully_approved(Request) — all required approvals have been received').
battery_export(approval_chains, 'next_approver/2',     'next_approver(Request, Approver) — Approver is the next pending approver in sequence').
battery_export(approval_chains, 'approval_blocked/2',  'approval_blocked(Request, Reason) — approval cannot proceed; Reason explains why').

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
approval_granted(Request, Approver) :-
    relation(Request, approved_by, Approver), !.
approval_granted(Request, Approver) :-
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
    msort(Pairs, Sorted),
    member(_-Approver, Sorted),
    \+ approval_granted(Request, Approver), !.

%% approval_blocked(+Request, -Reason)
approval_blocked(Request, rejected(By, Reason)) :-
    relation(Request, rejected_by, By),
    ( attribute(Request, rejection_reason, Reason) -> true ; Reason = unspecified ), !.
approval_blocked(Request, awaiting(Approver)) :-
    next_approver(Request, Approver).
