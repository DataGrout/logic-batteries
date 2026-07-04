%% prob-core-iso: reference implementation of the `::` rewrite.
%% License: Apache-2.0 (see LICENSE in this directory).
%%
%% This is the term-level transform the platform applies BEFORE a rule
%% reaches an ISO-pinned cell — in the rule-compile path behind
%% logic.constrain / logic.assert / batteries installs. It is shipped
%% here as executable documentation: the bridge can call it directly
%% (it is pure ISO) or reimplement it host-side; the clause relation
%% below is the specification.
%%
%% Flow (replaces the current "requires SWI, fork the namespace" gate):
%%   1. read_term with `::` declared: op(600, xfx, '::')  [cplint-compatible]
%%   2. if the clause mentions `::`, ensure prob-core-iso is installed in
%%      the namespace (idempotent auto-install), then rewrite via
%%      problog_transform/2 and assert the result
%%   3. preserve the original `::` source in the record's metadata
%%      (source_text) so exports/round-trips show what the author wrote
%%
%% v1 scope: single-head weighted facts and rules. Annotated
%% disjunctions (0.3::a ; 0.7::b :- body) are rejected with a clear
%% error — they need choice-group bookkeeping, planned for v2.

:- op(600, xfx, '::').

%% problog_transform(+ClauseIn, -ClauseOut)
%%
%%   P::Head :- Body   ==>   prob_rule(Head, P) :- Body
%%   P::Fact.          ==>   prob_rule(Fact, P).
%%   anything else     ==>   unchanged
problog_transform((L :- Body), (prob_rule(Head, P) :- Body)) :-
    nonvar(L), L = '::'(P, Head),
    !,
    check_weight(P),
    check_single_head(Head).
problog_transform('::'(P, Head), prob_rule(Head, P)) :-
    !,
    check_weight(P),
    check_single_head(Head).
problog_transform(Clause, Clause).

check_weight(P) :-
    (   number(P), P >= 0.0, P =< 1.0
    ->  true
    ;   throw(error(domain_error(probability, P), problog_transform/2))
    ).

check_single_head(Head) :-
    (   nonvar(Head), Head = (_ ; _)
    ->  throw(error(representation_error(annotated_disjunction_unsupported_v1),
                    problog_transform/2))
    ;   true
    ).
