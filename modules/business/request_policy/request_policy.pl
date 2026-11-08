%% Battery: request_policy v1.0.0
%% Requires: (nothing)
%% Exports: request_compliant/1, request_violation/2, needs_receipt/1,
%%          needs_preapproval/1

:- dynamic(attribute/3).

battery_module(request_policy, '1.0.0', auto).

battery_export(request_policy, 'request_compliant/1',
    'request_compliant(Request) — Request breaks none of the policy''s rules').
battery_export(request_policy, 'request_violation/2',
    'request_violation(Request, Reason) — Request breaks a rule; Reason is over_limit, missing_receipt, needs_preapproval or late_submission').
battery_export(request_policy, 'needs_receipt/1',
    'needs_receipt(Request) — Request''s amount is above the receipt threshold for its category').
battery_export(request_policy, 'needs_preapproval/1',
    'needs_preapproval(Request) — Request''s amount is above the pre-approval threshold for its category').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). A request is an
%% expense or purchase request with an amount. Thresholds are data: a limit row
%% per category, falling back to the policy, falling back to the defaults here.

battery_input(request_policy, request, attribute(amount), number, key,
    'The amount requested.').
battery_input(request_policy, request, attribute(category), atom, optional,
    'The kind of request, matched against a limit row''s applies_to.').
battery_input(request_policy, request, attribute(receipt), bool, default(false),
    'true when a receipt is attached.').
battery_input(request_policy, request, attribute(pre_approved), bool, default(false),
    'true when the spend was approved before it was made. A host can set it from an approval decision about the same request.').
battery_input(request_policy, request, attribute(incurred_on), days, optional,
    'The day the cost was incurred.').
battery_input(request_policy, request, attribute(submitted_on), days, optional,
    'The day the request was submitted.').
battery_input(request_policy, limit, attribute(applies_to), atom, key,
    'The category these limits apply to.').
battery_input(request_policy, limit, attribute(max_amount), number, optional,
    'The most a request in this category may be.').
battery_input(request_policy, limit, attribute(receipt_over), number, optional,
    'A receipt is needed above this amount in this category.').
battery_input(request_policy, limit, attribute(preapproval_over), number, optional,
    'Pre-approval is needed above this amount in this category.').
battery_input(request_policy, fixed(policy), attribute(max_amount), number, optional,
    'The most any request may be, unless its category says otherwise.').
battery_input(request_policy, fixed(policy), attribute(receipt_over), number, default(25),
    'A receipt is needed above this amount, unless its category says otherwise.').
battery_input(request_policy, fixed(policy), attribute(preapproval_over), number, default(1000),
    'Pre-approval is needed above this amount, unless its category says otherwise.').
battery_input(request_policy, fixed(policy), attribute(submit_within_days), integer, default(30),
    'Days after incurred_on within which a request must be submitted.').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%%   attribute(r1, amount, 120)               attribute(lim_meals, applies_to, meals)
%%   attribute(r1, category, meals)           attribute(lim_meals, max_amount, 75)
%%   attribute(r1, receipt, true)             attribute(lim_meals, receipt_over, 25)
%%   attribute(r1, incurred_on, 20762)        attribute(policy, preapproval_over, 1000)
%%   attribute(r1, submitted_on, 20762)

%% ── Requests and thresholds ──────────────────────────────────────────────────

rp_target(R) :-
    ( var(R) -> rp_requests(Rs), member(R, Rs) ; attribute(R, amount, _), ! ).

rp_requests(Rs) :-
    findall(R, attribute(R, amount, _), Rs0),
    sort(Rs0, Rs).

%% rp_setting(+Request, +Name, +Default, -Value): the request's category row,
%% then the policy, then Default (none: no value).
rp_setting(R, Name, _, Value) :-
    attribute(R, category, Cat),
    attribute(Row, applies_to, Cat),
    attribute(Row, Name, Value), !.
rp_setting(_, Name, _, Value) :-
    attribute(policy, Name, Value), !.
rp_setting(_, _, Default, Default) :-
    Default \== none.

rp_amount(R, A) :- attribute(R, amount, A).

%% ── Exports ──────────────────────────────────────────────────────────────────

%% needs_receipt(?Request)
needs_receipt(R) :-
    rp_target(R),
    rp_amount(R, A),
    rp_setting(R, receipt_over, 25, Over),
    A > Over.

%% needs_preapproval(?Request)
needs_preapproval(R) :-
    rp_target(R),
    rp_amount(R, A),
    rp_setting(R, preapproval_over, 1000, Over),
    A > Over.

%% request_violation(?Request, ?Reason)
request_violation(R, over_limit) :-
    rp_target(R),
    rp_amount(R, A),
    rp_setting(R, max_amount, none, Max),
    A > Max.
request_violation(R, missing_receipt) :-
    needs_receipt(R),
    \+ attribute(R, receipt, true).
request_violation(R, needs_preapproval) :-
    needs_preapproval(R),
    \+ attribute(R, pre_approved, true).
request_violation(R, late_submission) :-
    rp_target(R),
    attribute(R, incurred_on, Incurred),
    attribute(R, submitted_on, Submitted),
    ( attribute(policy, submit_within_days, W0) -> W = W0 ; W = 30 ),
    Submitted - Incurred > W.

%% request_compliant(?Request)
request_compliant(R) :-
    rp_target(R),
    \+ request_violation(R, _).
