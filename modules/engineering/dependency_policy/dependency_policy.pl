%% Battery: dependency_policy v1.0.0
%% Requires: (nothing)
%% Exports: dependency_allowed/1, dependency_violation/2, dependencies_compliant/1,
%%          change_violation/3, major_version/2

:- dynamic(attribute/3).

battery_module(dependency_policy, '1.0.0', auto).

battery_export(dependency_policy, 'dependency_allowed/1',
    'dependency_allowed(Dep) — Dep''s licence is on the allow-list and its version keeps to the major the policy pins it to').
battery_export(dependency_policy, 'dependency_violation/2',
    'dependency_violation(Dep, Reason) — Dep breaks the policy: license_not_allowed(License), major_mismatch(Major, Pinned) or unpinned_major(Version)').
battery_export(dependency_policy, 'dependencies_compliant/1',
    'dependencies_compliant(Change) — every dependency the change adds or updates is allowed').
battery_export(dependency_policy, 'change_violation/3',
    'change_violation(Change, Dep, Reason) — a dependency the change adds or updates breaks the policy, for Reason as in dependency_violation/2').
battery_export(dependency_policy, 'major_version/2',
    'major_version(Dep, Major) — the major version Dep''s version or requirement fixes; none when it fixes none').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). A dependency is a
%% package a change adds, updates or removes, as a dependency review lists
%% them. The allow-list and the pins are records.

battery_input(dependency_policy, dependency, attribute(package), atom, key,
    'The package name as its ecosystem spells it.').
battery_input(dependency_policy, dependency, attribute(dependency_of), ref(change), key,
    'The change that adds, updates or removes it.').
battery_input(dependency_policy, dependency, attribute(license), atom, required,
    'Its licence as an SPDX identifier or expression (MIT, Apache-2.0, MIT OR Apache-2.0). Leave it out when unknown rather than guessing.').
battery_input(dependency_policy, dependency, attribute(version), atom, required,
    'The version, or the requirement the manifest states (4.17.21, ^4.17, ~> 1.7, >= 2).').
battery_input(dependency_policy, dependency, attribute(change_type), enum([added, updated, removed]), default(added),
    'What the change does to it. A removed dependency is not checked.').
battery_input(dependency_policy, change, attribute(dependency_review), enum([true]), key,
    'true once the change''s dependency comparison was fetched, so a change that touches no dependency is compliant rather than unknown. There is no false: a change whose comparison was not fetched has no marker.').
battery_input(dependency_policy, allowed_license, attribute(allows_license), atom, key,
    'A licence identifier dependencies may carry.').
battery_input(dependency_policy, pin, attribute(pins_package), atom, key,
    'A package whose major version is pinned.').
battery_input(dependency_policy, pin, attribute(major), integer, required,
    'The major version it must stay on.').
battery_input(dependency_policy, fixed(dependency_policy), attribute(require_pinned_major), bool, default(true),
    'true when every version must fix its major: an open requirement (*, latest, >= 2) is a violation. A pinned package must fix its major either way.').

battery_needs(dependency_policy, allowed_license, any,
    'The licence allow-list, supplied as records. Without it no licence can be judged.').

%% ── Data model ───────────────────────────────────────────────────────────────
%%
%%   attribute(d1, package, lodash)          attribute(lic_mit, allows_license, 'MIT')
%%   attribute(d1, dependency_of, pr_7)      attribute(lic_apache, allows_license, 'Apache-2.0')
%%   attribute(d1, license, 'MIT')           attribute(pin_react, pins_package, react)
%%   attribute(d1, version, '^4.17.21')      attribute(pin_react, major, 18)
%%   attribute(d1, change_type, added)

%% ── Dependencies ─────────────────────────────────────────────────────────────

dp_target(D) :-
    ( var(D) -> dp_deps(Ds), member(D, Ds) ; true ).

dp_deps(Ds) :-
    findall(D, attribute(D, package, _), Ds0),
    sort(Ds0, Ds).

dp_changes(Cs) :-
    findall(C, dp_change_ref(C), Cs0),
    sort(Cs0, Cs).

dp_change_ref(C) :- attribute(_, dependency_of, C).
dp_change_ref(C) :- attribute(C, dependency_review, true).

%% The change's dependencies were looked at: a comparison marked done, or
%% entries from one.
dp_reviewed(C) :- attribute(C, dependency_review, true), !.
dp_reviewed(C) :- attribute(_, dependency_of, C), !.

dp_change_target(C) :-
    ( var(C) -> dp_changes(Cs), member(C, Cs) ; true ).

%% The dependencies a change adds or updates.
dp_checked_of(C, D) :-
    attribute(D, dependency_of, C),
    attribute(D, package, _),
    \+ attribute(D, change_type, removed).

dp_pinned(D) :-
    attribute(D, package, P),
    attribute(Pin, pins_package, P),
    attribute(Pin, major, _),
    !.

dp_require_pinned :-
    \+ attribute(dependency_policy, require_pinned_major, false).

%% ── Text ─────────────────────────────────────────────────────────────────────

dp_codes(V, Cs) :- number(V), !, number_codes(V, Cs).
dp_codes(V, Cs) :- atom_codes(V, Cs).

dp_lower([], []).
dp_lower([C|Cs], [L|Ls]) :-
    ( C >= 65, C =< 90 -> L is C + 32 ; L = C ),
    dp_lower(Cs, Ls).

%% dp_tokens(+Codes, -Tokens): words split on spaces, with each parenthesis a
%% token of its own; OR, AND and WITH in any case become or, and, with.
dp_tokens(Cs, Ts) :- dp_tokens(Cs, [], Ts).

dp_tokens([], Acc, Ts) :- dp_flush(Acc, [], Ts).
dp_tokens([C|Cs], Acc, Ts) :-
    (   C =:= 32
    ->  dp_flush(Acc, Rest, Ts), dp_tokens(Cs, [], Rest)
    ;   ( C =:= 40 ; C =:= 41 )
    ->  atom_codes(P, [C]),
        dp_flush(Acc, [P|Rest], Ts),
        dp_tokens(Cs, [], Rest)
    ;   dp_tokens(Cs, [C|Acc], Ts)
    ).

dp_flush([], Rest, Rest) :- !.
dp_flush(Acc, Rest, [T|Rest]) :-
    reverse(Acc, W),
    dp_lower(W, Lower),
    atom_codes(L, Lower),
    (   memberchk(L, [or, and, with]) -> T = L ; atom_codes(T, W) ).

%% ── Licences ─────────────────────────────────────────────────────────────────

dp_allowed_id(Id) :-
    atom_codes(Id, Codes),
    dp_lower(Codes, Lower),
    attribute(_, allows_license, A),
    dp_codes(A, Cs),
    dp_lower(Cs, Lower),
    !.

%% An SPDX expression, read with its precedence: WITH binds tightest, then
%% AND, then OR, and parentheses group. An identifier with an exception is
%% judged by the identifier, since an exception only grants more. An
%% expression that does not parse is not allowed.
%%
%% Evaluated by shunting-yard over a value stack and an operator stack: a
%% recursive-descent reader would need rules that call each other in a cycle,
%% which a cell refuses.
dp_license_allowed(License) :-
    dp_codes(License, Cs),
    dp_tokens(Cs, Ts0),
    dp_operands(Ts0, Ts),
    dp_yard(Ts, operand, [], [], true).

%% dp_operands(+Tokens, -Items): identifiers (with any exception) become
%% v(true) or v(false); parentheses and operators pass through.
dp_operands([], []).
dp_operands([Id, with, Exception|Ts], [v(V)|Rest]) :-
    dp_id(Id),
    dp_id(Exception),
    !,
    dp_id_value(Id, V),
    dp_operands(Ts, Rest).
dp_operands([T|Ts], [Item|Rest]) :-
    (   dp_id(T) -> dp_id_value(T, V), Item = v(V) ; Item = T ),
    dp_operands(Ts, Rest).

dp_id(Id) :- \+ memberchk(Id, ['(', ')', or, and, with]).

dp_id_value(Id, V) :- ( dp_allowed_id(Id) -> V = true ; V = false ).

%% dp_yard(+Items, +Expect, +Values, +Operators, -Value): Expect is operand
%% at the start, after ( and after an operator, and operator after an
%% operand or ); anything out of place fails, so a malformed expression is
%% not allowed.
dp_yard([], operator, Vals, Ops, V) :-
    dp_unwind(Ops, Vals, [V]).
dp_yard([v(B)|Ts], operand, Vals, Ops, V) :-
    !,
    dp_yard(Ts, operator, [B|Vals], Ops, V).
dp_yard(['('|Ts], operand, Vals, Ops, V) :-
    !,
    dp_yard(Ts, operand, Vals, ['('|Ops], V).
dp_yard([')'|Ts], operator, Vals, Ops, V) :-
    !,
    dp_to_paren(Ops, Vals, Ops1, Vals1),
    dp_yard(Ts, operator, Vals1, Ops1, V).
dp_yard([Op|Ts], operator, Vals, Ops, V) :-
    memberchk(Op, [and, or]),
    dp_reduce(Op, Ops, Vals, Ops1, Vals1),
    dp_yard(Ts, operand, Vals1, [Op|Ops1], V).

dp_prec(and, 2).
dp_prec(or, 1).

%% Apply the operators on top that bind at least as tightly as Op.
dp_reduce(Op, [Top|Ops], [B, A|Vals], Ops1, Vals1) :-
    Top \== '(',
    dp_prec(Top, PT),
    dp_prec(Op, PO),
    PT >= PO,
    !,
    dp_apply(Top, A, B, R),
    dp_reduce(Op, Ops, [R|Vals], Ops1, Vals1).
dp_reduce(_, Ops, Vals, Ops, Vals).

%% Apply operators down to the matching open parenthesis.
dp_to_paren(['('|Ops], Vals, Ops, Vals) :- !.
dp_to_paren([Op|Ops], [B, A|Vals], Ops1, Vals1) :-
    Op \== '(',
    dp_apply(Op, A, B, R),
    dp_to_paren(Ops, [R|Vals], Ops1, Vals1).

%% Apply what is left; an unclosed parenthesis fails.
dp_unwind([], Vals, Vals).
dp_unwind([Op|Ops], [B, A|Vals], Out) :-
    Op \== '(',
    dp_apply(Op, A, B, R),
    dp_unwind(Ops, [R|Vals], Out).

dp_apply(and, A, B, R) :- ( A == true, B == true -> R = true ; R = false ).
dp_apply(or, A, B, R) :- ( ( A == true ; B == true ) -> R = true ; R = false ).

%% ── Versions ─────────────────────────────────────────────────────────────────

%% dp_major(+Version, -Major): the major a version or requirement fixes. An
%% open lower bound, a wildcard, a range or alternatives fix none.
dp_major(V, Major) :-
    dp_codes(V, Cs0),
    dp_trim(Cs0, Cs),
    \+ dp_has(Cs, '||'),
    \+ dp_has(Cs, ' - '),
    dp_strip_prefix(Cs, Rest0),
    dp_trim(Rest0, Rest),
    dp_digits(Rest, [D|Ds], _),
    number_codes(Major, [D|Ds]).

dp_has(Cs, Text) :-
    atom_codes(Text, Sub),
    append(_, Tail, Cs),
    append(Sub, _, Tail),
    !.

dp_trim([32|Cs], T) :- !, dp_trim(Cs, T).
dp_trim(Cs, Cs).

dp_strip_prefix(Cs, Rest) :-
    member(Text, ['~>', '==', '=', '^', '~', v, 'V']),
    atom_codes(Text, P),
    append(P, Rest, Cs),
    !.
dp_strip_prefix(Cs, Cs).

dp_digits([C|Cs], [C|Ds], Rest) :-
    C >= 48, C =< 57, !,
    dp_digits(Cs, Ds, Rest).
dp_digits(Cs, [], Cs).

%% ── Exports ──────────────────────────────────────────────────────────────────

%% major_version(?Dep, ?Major)
major_version(D, Major) :-
    dp_target(D),
    attribute(D, version, V),
    (   dp_major(V, M) -> Major = M ; Major = none ).

%% dependency_violation(?Dep, ?Reason)
dependency_violation(D, license_not_allowed(L)) :-
    dp_target(D),
    attribute(D, license, L),
    \+ dp_license_allowed(L).
dependency_violation(D, major_mismatch(Major, Pinned)) :-
    dp_target(D),
    attribute(D, package, P),
    attribute(Pin, pins_package, P),
    attribute(Pin, major, Pinned),
    attribute(D, version, V),
    dp_major(V, Major),
    Major =\= Pinned.
dependency_violation(D, unpinned_major(V)) :-
    dp_target(D),
    ( dp_require_pinned -> true ; dp_pinned(D) ),
    attribute(D, version, V),
    \+ dp_major(V, _).

%% dependency_allowed(?Dep): decided only when its licence and version are
%% known and the allow-list is loaded.
dependency_allowed(D) :-
    dp_target(D),
    attribute(_, allows_license, _),
    attribute(D, license, _),
    attribute(D, version, _),
    \+ dependency_violation(D, _).

%% change_violation(?Change, ?Dep, ?Reason)
change_violation(C, D, Reason) :-
    dp_change_target(C),
    dp_checked_of(C, D),
    dependency_violation(D, Reason).

%% dependencies_compliant(?Change)
dependencies_compliant(C) :-
    dp_change_target(C),
    dp_reviewed(C),
    attribute(_, allows_license, _),
    \+ ( dp_checked_of(C, D), \+ dependency_allowed(D) ).
