%% Battery: approval v1.0.0
%% Requires: (nothing)
%% Exports: approved/1, approved_by/3, conditions/2, withdrawn/1, rejected/1,
%%          authorized/2, unauthorized_approval/2, unauthorized_withdrawal/2,
%%          limited_approval/3

:- dynamic(attribute/3).

battery_module(approval, '1.0.0', auto).

battery_export(approval, 'approved/1',
    'approved(Item) — a standing approval: the latest decision from someone with authority approves Item within its own limit, and its approver has not withdrawn it').
battery_export(approval, 'approved_by/3',
    'approved_by(Item, Person, Day) — Person''s approval of Item, made on Day, is standing').
battery_export(approval, 'conditions/2',
    'conditions(Item, Condition) — a standing approval of Item is subject to Condition').
battery_export(approval, 'withdrawn/1',
    'withdrawn(Item) — Item was approved, and its approver withdrew the approval with none standing since').
battery_export(approval, 'rejected/1',
    'rejected(Item) — the latest decision from someone with authority rejects Item').
battery_export(approval, 'authorized/2',
    'authorized(Person, Item) — Person has the authority to approve Item: their role or name, Item''s category and its amount are covered').
battery_export(approval, 'unauthorized_approval/2',
    'unauthorized_approval(Item, Person) — Person approved Item without the authority to').
battery_export(approval, 'unauthorized_withdrawal/2',
    'unauthorized_withdrawal(Item, Person) — Person withdrew an approval of Item they never gave, which does not count').
battery_export(approval, 'limited_approval/3',
    'limited_approval(Item, Person, Limit) — Person approved Item only up to Limit, below its amount, so it does not stand').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). Each statement is
%% its own subject: who said what, about which item, on which day. A thread is
%% not a subject. Authority (who may approve what) is supplied as records and
%% never read from the statements themselves.

battery_input(approval, statement, attribute(about), ref(item), key,
    'The item the statement is about.').
battery_input(approval, statement, attribute(act), enum([approve, reject, withdraw]), required,
    'What the statement does. A question ("approved, pending legal?") is not an approval, and statements that only ask or discuss are not supplied.').
battery_input(approval, statement, attribute(by), ref(person), required,
    'Who made the statement.').
battery_input(approval, statement, attribute(on), days, required,
    'The day it was made.').
battery_input(approval, statement, attribute(order), integer, optional,
    'Position in the thread, for statements made on the same day; the later one wins.').
battery_input(approval, statement, attribute(limit), number, optional,
    'An amount the approval is limited to ("approved up to 5,000").').
battery_input(approval, statement, attribute(condition), atom, optional,
    'A condition the approval is subject to, in a few words ("after legal review"). A question is not a condition.').
battery_input(approval, item, attribute(title), atom, key,
    'What is being approved, in a few words.').
battery_input(approval, item, attribute(amount), number, key,
    'The amount at stake, checked against the approver''s and the statement''s limits.').
battery_input(approval, item, attribute(category), atom, key,
    'The kind of item, matched against an authority''s covers_category.').
battery_input(approval, person, attribute(role), atom, key,
    'The person''s role, matched against an authority''s approver_role.').
battery_input(approval, authority, attribute(approver_role), atom, key,
    'A role whose holders may approve.').
battery_input(approval, authority, attribute(approver), ref(person), key,
    'Or one named person who may approve.').
battery_input(approval, authority, attribute(covers_category), atom, optional,
    'The kind of item this authority covers; absent covers every kind.').
battery_input(approval, authority, attribute(up_to), number, optional,
    'The largest amount this authority covers; absent means no limit.').

%% A decision needs both of these loaded. Without an authority list no
%% approval can be judged, and an item no statement is about has not been
%% decided; either way the answer is unknown, not "not approved".
battery_needs(approval, authority, any,
    'Who may approve what, supplied as records. Without it no approval can be judged.').
battery_needs(approval, statement, attribute(about),
    'At least one statement about the item. An item nobody has decided on is unknown, not unapproved.').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%%   attribute(s1, about, laptop_order)     attribute(laptop_order, title, 'laptop order')
%%   attribute(s1, act, approve)            attribute(laptop_order, amount, 3200)
%%   attribute(s1, by, priya)               attribute(priya, role, manager)
%%   attribute(s1, on, 20754)               attribute(auth_mgr, approver_role, manager)
%%   attribute(s1, condition, 'after legal review')
%%                                          attribute(auth_mgr, up_to, 5000)
%%
%% Statements about an item are taken in time order (on, then order). An
%% approval counts when its author has authority over the item and the item's
%% amount is within the statement's own limit. A rejection from someone with
%% authority clears every approval before it; a later approval supersedes it.
%% A withdrawal counts only from someone whose approval is standing, and
%% removes that approval.

%% ── Items ────────────────────────────────────────────────────────────────────

%% With Item unbound, the items to consider: those a statement is about, and
%% those named by title.
appr_target(Item) :-
    ( var(Item) -> appr_items(Items), member(Item, Items) ; true ).

appr_items(Items) :-
    findall(X, appr_item_ref(X), Xs),
    sort(Xs, Items).

appr_item_ref(X) :- attribute(_, about, X).
appr_item_ref(X) :- attribute(X, title, _).

%% ── Authority ────────────────────────────────────────────────────────────────

appr_authority(A) :- attribute(A, approver_role, _).
appr_authority(A) :- attribute(A, approver, _), \+ attribute(A, approver_role, _).

appr_holds(A, Person) :- attribute(A, approver, Person).
appr_holds(A, Person) :- attribute(A, approver_role, Role), attribute(Person, role, Role).

%% appr_cover(+A, +Item, -Verdict): yes, no, or unknown when the item lacks the
%% category or amount the authority's scope turns on.
appr_cover(A, Item, Verdict) :-
    appr_category_cover(A, Item, C),
    appr_amount_cover(A, Item, L),
    appr_both(C, L, Verdict).

appr_category_cover(A, Item, V) :-
    (   attribute(A, covers_category, Cat)
    ->  (   attribute(Item, category, Cat) -> V = yes
        ;   attribute(Item, category, _) -> V = no
        ;   V = unknown
        )
    ;   V = yes
    ).

appr_amount_cover(A, Item, V) :-
    (   attribute(A, up_to, Limit)
    ->  (   attribute(Item, amount, Amount)
        ->  ( Amount =< Limit -> V = yes ; V = no )
        ;   V = unknown
        )
    ;   V = yes
    ).

appr_both(no, _, no) :- !.
appr_both(_, no, no) :- !.
appr_both(yes, yes, yes) :- !.
appr_both(_, _, unknown).

%% authorized(+Person, ?Item)
authorized(Person, Item) :-
    appr_target(Item),
    appr_authorized(Person, Item).

%% The verdict is computed unbound and compared after: appr_both/3 cuts on
%% its first argument, so asking for `unknown` directly would match its last
%% clause whatever the scope said.
appr_authorized(Person, Item) :-
    appr_authority(A),
    appr_holds(A, Person),
    appr_cover(A, Item, V),
    V == yes,
    !.

appr_maybe_authorized(Person, Item) :-
    appr_authority(A),
    appr_holds(A, Person),
    appr_cover(A, Item, V),
    V == unknown,
    !.

%% ── Statements in order ──────────────────────────────────────────────────────

appr_key(S, k(On, Order)) :-
    attribute(S, on, On),
    ( attribute(S, order, Order) -> true ; Order = 0 ).

appr_event(Item, Key-ev(Act, Person, S)) :-
    attribute(S, about, Item),
    attribute(S, act, Act),
    attribute(S, by, Person),
    appr_key(S, Key).

appr_over_statement_limit(S, Item) :-
    attribute(S, limit, Limit),
    attribute(Item, amount, Amount),
    Amount > Limit.

%% appr_state(+Item, -st(Standing, Rejected, Withdrawn)): the statements folded
%% in time order. Standing is a list of Person-Statement for the approvals that
%% stand; Rejected and Withdrawn are true or false.
appr_state(Item, State) :-
    findall(E, appr_event(Item, E), Events0),
    keysort(Events0, Events),
    foldl(appr_step(Item), Events, st([], false, false), State).

appr_step(Item, _-ev(approve, P, S), st(St0, R0, W), st(St, R, W)) :-
    (   appr_authorized(P, Item), \+ appr_over_statement_limit(S, Item)
    ->  appr_drop(P, St0, St1), St = [P-S|St1], R = false
    ;   St = St0, R = R0
    ).
appr_step(Item, _-ev(reject, P, _), st(St0, R0, W), st(St, R, W)) :-
    (   appr_authorized(P, Item)
    ->  St = [], R = true
    ;   St = St0, R = R0
    ).
appr_step(_, _-ev(withdraw, P, _), st(St0, R, W0), st(St, R, W)) :-
    (   memberchk(P-_, St0)
    ->  appr_drop(P, St0, St), W = true
    ;   St = St0, W = W0
    ).
appr_step(_, _-ev(Act, _, _), State, State) :-
    \+ memberchk(Act, [approve, reject, withdraw]).

appr_drop(_, [], []).
appr_drop(P, [P-_|T], T1) :- !, appr_drop(P, T, T1).
appr_drop(P, [H|T], [H|T1]) :- appr_drop(P, T, T1).

%% ── Decisions ────────────────────────────────────────────────────────────────

%% approved(?Item)
approved(Item) :-
    appr_target(Item),
    appr_state(Item, st(Standing, _, _)),
    Standing \== [].

%% approved_by(?Item, ?Person, ?Day)
approved_by(Item, Person, Day) :-
    appr_target(Item),
    appr_state(Item, st(Standing, _, _)),
    member(Person-S, Standing),
    attribute(S, on, Day).

%% conditions(?Item, ?Condition)
conditions(Item, Condition) :-
    appr_target(Item),
    appr_state(Item, st(Standing, _, _)),
    member(_-S, Standing),
    attribute(S, condition, Condition).

%% withdrawn(?Item)
withdrawn(Item) :-
    appr_target(Item),
    appr_state(Item, st([], _, true)).

%% rejected(?Item)
rejected(Item) :-
    appr_target(Item),
    appr_state(Item, st(_, true, _)).

%% unauthorized_approval(?Item, ?Person): no authority covers the item for the
%% person. When one might, but the item lacks the amount or category to tell,
%% this does not hold: that is a gap, not a lack of authority.
unauthorized_approval(Item, Person) :-
    appr_target(Item),
    findall(P, appr_approver(Item, P), Ps0),
    sort(Ps0, Ps),
    member(Person, Ps),
    \+ appr_authorized(Person, Item),
    \+ appr_maybe_authorized(Person, Item).

appr_approver(Item, Person) :-
    attribute(S, about, Item),
    attribute(S, act, approve),
    attribute(S, by, Person).

%% unauthorized_withdrawal(?Item, ?Person): a withdrawal from someone who never
%% approved the item. It is ignored when deciding approved/1.
unauthorized_withdrawal(Item, Person) :-
    appr_target(Item),
    findall(P, appr_withdrawer(Item, P), Ps0),
    sort(Ps0, Ps),
    member(Person, Ps),
    \+ appr_approver(Item, Person).

appr_withdrawer(Item, Person) :-
    attribute(S, about, Item),
    attribute(S, act, withdraw),
    attribute(S, by, Person).

%% limited_approval(?Item, ?Person, ?Limit)
limited_approval(Item, Person, Limit) :-
    appr_target(Item),
    attribute(S, about, Item),
    attribute(S, act, approve),
    attribute(S, by, Person),
    appr_over_statement_limit(S, Item),
    attribute(S, limit, Limit).
