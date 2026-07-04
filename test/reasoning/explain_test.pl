:- use_module(library(plunit)).

:- consult('../../modules/reasoning/explain/explain').

%% Test predicates are expl_t_-prefixed to keep the shared user-module
%% namespace clean, and dynamic so clause/2 can walk them (mirrors LC
%% cells, where everything is asserted).
:- dynamic expl_t_discount/2.
:- dynamic expl_t_age/2.
:- dynamic expl_t_years/2.
:- dynamic expl_t_flagged/1.
:- dynamic expl_t_premium/1.
:- dynamic expl_t_route/2.
:- dynamic expl_t_grade/2.
:- dynamic expl_t_verdict/2.
:- dynamic expl_t_super/1.

setup_discounts :-
    assertz((expl_t_discount(C, senior) :- expl_t_age(C, A), A >= 65)),
    assertz((expl_t_discount(C, loyalty) :-
                 expl_t_years(C, Y), Y >= 5, \+ expl_t_flagged(C))),
    assertz(expl_t_age(mona, 71)),
    assertz(expl_t_age(zed, 30)),
    assertz(expl_t_years(zed, 7)),
    assertz(expl_t_years(mona, 2)),
    % vip qualifies for BOTH discounts
    assertz(expl_t_age(vip, 80)),
    assertz(expl_t_years(vip, 10)).

setup_base_facts :-
    assertz((expl_t_premium(X) :- attribute(X, tier, gold))),
    assertz(attribute(acme, tier, gold)).

setup_disjunction :-
    assertz((expl_t_route(X, scenic) :-
                 ( expl_t_grade(X, a) ; expl_t_grade(X, b) ))),
    assertz(expl_t_grade(r1, b)),
    % r2 satisfies BOTH branches — two alternative proofs
    assertz(expl_t_grade(r2, a)),
    assertz(expl_t_grade(r2, b)).

setup_ifthenelse :-
    assertz((expl_t_verdict(X, V) :-
                 ( expl_t_grade(X, a) -> V = pass ; V = fail ))),
    assertz(expl_t_grade(s1, a)).

setup_chain :-
    setup_discounts,
    assertz((expl_t_super(X) :- expl_t_discount(X, senior))).

%% NOTE: asserts live in setup predicates (defined in `user`), never in test
%% bodies — plunit compiles bodies into a per-unit module, so an in-body
%% assertz lands in the wrong module and stored rules can't see the facts.
setup_flagged :-
    setup_discounts,
    assertz(expl_t_years(cheater, 9)),
    assertz(expl_t_flagged(cheater)).

cleanup_expl :-
    retractall(expl_t_discount(_, _)),
    retractall(expl_t_age(_, _)),
    retractall(expl_t_years(_, _)),
    retractall(expl_t_flagged(_)),
    retractall(expl_t_premium(_)),
    retractall(expl_t_route(_, _)),
    retractall(expl_t_grade(_, _)),
    retractall(expl_t_verdict(_, _)),
    retractall(expl_t_super(_)),
    retractall(attribute(_, _, _)).

%% ── why/2 — the everyday provenance API ─────────────────────────────────────

:- begin_tests(explain_why).

test(why_senior_discount, [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    why(expl_t_discount(mona, D), Facts),
    assertion(D == senior),
    assertion(Facts == [expl_t_age(mona, 71)]).

test(why_loyalty_negation_contributes_no_leaf,
     [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    why(expl_t_discount(zed, D), Facts),
    assertion(D == loyalty),
    assertion(Facts == [expl_t_years(zed, 7)]).

test(why_is_deterministic, [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    % vip has two qualifying discounts but why/2 is once/1-wrapped
    findall(D, why(expl_t_discount(vip, D), _), Ds),
    assertion(Ds == [senior]).

test(why_respects_bound_goal, [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    % asking specifically about loyalty skips the senior proof
    why(expl_t_discount(vip, loyalty), Facts),
    assertion(Facts == [expl_t_years(vip, 10)]).

test(why_fails_on_unprovable, [setup(setup_discounts), cleanup(cleanup_expl), fail]) :-
    why(expl_t_discount(nobody, _), _).

test(flagged_customer_blocked, [setup(setup_flagged), cleanup(cleanup_expl), fail]) :-
    why(expl_t_discount(cheater, loyalty), _).

test(unflagged_peer_not_blocked, [setup(setup_flagged), cleanup(cleanup_expl)]) :-
    % control for the test above: same setup, unflagged member still qualifies
    why(expl_t_discount(zed, loyalty), Facts),
    assertion(Facts == [expl_t_years(zed, 7)]).

test(why_through_rule_chain, [setup(setup_chain), cleanup(cleanup_expl)]) :-
    % rule → rule → fact: leaves come from the bottom of the chain
    why(expl_t_super(mona), Facts),
    assertion(Facts == [expl_t_age(mona, 71)]).

test(why_collects_base_facts, [setup(setup_base_facts), cleanup(cleanup_expl)]) :-
    why(expl_t_premium(acme), Facts),
    assertion(Facts == [attribute(acme, tier, gold)]).

:- end_tests(explain_why).

%% ── explain/2 — proof trees ─────────────────────────────────────────────────

:- begin_tests(explain_proof_trees).

test(proof_tree_shape, [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    once(explain(expl_t_discount(mona, senior), Proof)),
    Proof = node(rule(expl_t_discount(mona, senior)),
                 [node(conj, [AgeProof, leaf(71 >= 65, builtin)])]),
    AgeProof = node(rule(expl_t_age(mona, 71)),
                    [leaf(expl_t_age(mona, 71), stored_fact)]).

test(alternative_proofs_on_backtracking,
     [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    findall(P, explain(expl_t_discount(vip, _), P), Proofs),
    assertion(length(Proofs, 2)).

test(base_fact_leaf_class, [setup(setup_base_facts), cleanup(cleanup_expl)]) :-
    once(explain(expl_t_premium(acme), Proof)),
    Proof = node(rule(_), [leaf(attribute(acme, tier, gold), base_fact)]).

test(negation_leaf_class, [setup(setup_discounts), cleanup(cleanup_expl)]) :-
    once(explain(expl_t_discount(zed, loyalty), Proof)),
    Proof = node(rule(_), [node(conj, [_, node(conj, [_, NegLeaf])])]),
    NegLeaf = leaf(\+ expl_t_flagged(zed), negation).

:- end_tests(explain_proof_trees).

%% ── control constructs ──────────────────────────────────────────────────────

:- begin_tests(explain_control).

test(disjunction_proof, [setup(setup_disjunction), cleanup(cleanup_expl)]) :-
    why(expl_t_route(r1, scenic), Facts),
    assertion(Facts == [expl_t_grade(r1, b)]).

test(disjunction_tree_node, [setup(setup_disjunction), cleanup(cleanup_expl)]) :-
    once(explain(expl_t_route(r1, scenic), Proof)),
    Proof = node(rule(_), [node(disj, [_])]).

test(disjunction_both_branches_backtrack,
     [setup(setup_disjunction), cleanup(cleanup_expl)]) :-
    findall(P, explain(expl_t_route(r2, scenic), P), Proofs),
    assertion(length(Proofs, 2)).

test(ifthen_takes_then_branch, [setup(setup_ifthenelse), cleanup(cleanup_expl)]) :-
    why(expl_t_verdict(s1, V), Facts),
    assertion(V == pass),
    assertion(Facts == [expl_t_grade(s1, a)]),
    once(explain(expl_t_verdict(s1, pass), Proof)),
    Proof = node(rule(_), [node(ifthen, [_, _])]).

test(ifthen_takes_else_branch, [setup(setup_ifthenelse), cleanup(cleanup_expl)]) :-
    % s2 has no grade → condition unprovable → else branch, no fact leaves
    why(expl_t_verdict(s2, V), Facts),
    assertion(V == fail),
    assertion(Facts == []),
    once(explain(expl_t_verdict(s2, fail), Proof)),
    Proof = node(rule(_), [node(else, [_])]).

:- end_tests(explain_control).

%% ── expl_leaves/3 ───────────────────────────────────────────────────────────

:- begin_tests(explain_leaves).

test(collects_only_fact_leaves) :-
    Tree = node(conj,
                [leaf(f1, stored_fact),
                 leaf(1 < 2, builtin),
                 node(rule(x), [leaf(f2, base_fact)]),
                 leaf(\+ g, negation)]),
    expl_leaves(Tree, [], Facts),
    msort(Facts, Sorted),
    assertion(Sorted == [f1, f2]).

test(empty_tree_list) :-
    expl_leaves([], [], Facts),
    assertion(Facts == []).

:- end_tests(explain_leaves).
