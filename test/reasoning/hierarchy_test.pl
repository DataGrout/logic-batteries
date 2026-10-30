:- use_module(library(plunit)).

:- consult('../../modules/reasoning/hierarchy/hierarchy').

:- dynamic relation/3.
:- dynamic metric/3.

%% A small chart of accounts, three levels deep under Expenses:
%%   Expenses
%%     Utilities           (own 0)  <- Gas (100.50), Phone (50.25)
%%     Job Expenses        (own 10) <- Job Materials (own 5) <- Pipe (20), Valves (30.75)
%%     Rent                (own 400)
hier_t_setup :-
    hier_t_clear,
    forall(member(C-P, [ 'Utilities'-'Expenses', 'Job Expenses'-'Expenses',
                         'Rent'-'Expenses', 'Gas'-'Utilities', 'Phone'-'Utilities',
                         'Job Materials'-'Job Expenses', 'Pipe'-'Job Materials',
                         'Valves'-'Job Materials' ]),
           assertz(relation(C, child_of, P))),
    forall(member(N-V, [ 'Gas'-100.50, 'Phone'-50.25, 'Job Expenses'-10,
                         'Job Materials'-5, 'Pipe'-20, 'Valves'-30.75, 'Rent'-400 ]),
           assertz(metric(N, amount, V))).

hier_t_clear :-
    retractall(relation(_, _, _)),
    retractall(metric(_, _, _)).

close_to(X, Y) :- abs(X - Y) < 1.0e-6.

:- begin_tests(hierarchy, [setup(hier_t_setup), cleanup(hier_t_clear)]).

test(subtotals_roll_every_level) :-
    hier_subtotal('Utilities', U), assertion(close_to(U, 150.75)),
    hier_subtotal('Job Materials', M), assertion(close_to(M, 55.75)),
    hier_subtotal('Job Expenses', J), assertion(close_to(J, 65.75)),
    hier_subtotal('Expenses', E), assertion(close_to(E, 616.50)),
    hier_subtotal('Pipe', P), assertion(close_to(P, 20)).

test(every_node_at_once) :-
    hier_subtotals(Pairs),
    length(Pairs, 9),
    memberchk('Expenses'-E, Pairs), assertion(close_to(E, 616.50)),
    memberchk('Gas'-G, Pairs), assertion(close_to(G, 100.50)).

test(unknown_node_fails_rather_than_zero) :-
    assertion(\+ hier_subtotal('Marketing', _)).

test(structure) :-
    hier_children('Job Expenses', ['Job Materials']),
    hier_descendants('Job Expenses', ['Job Materials', 'Pipe', 'Valves']),
    hier_roots(['Expenses']),
    hier_leaves(['Gas', 'Phone', 'Pipe', 'Rent', 'Valves']),
    hier_depth('Pipe', 3), hier_depth('Expenses', 0),
    findall(A, hier_rolls_up('Valves', A), As), msort(As, ['Expenses', 'Job Expenses', 'Job Materials']),
    hier_path('Pipe', 'Expenses', ['Pipe', 'Job Materials', 'Job Expenses', 'Expenses']),
    hier_problems([]).

test(other_metric) :-
    assertz(user:metric('Gas', budget, 90)), assertz(user:metric('Phone', budget, 60)),
    hier_subtotal('Utilities', budget, B), assertion(close_to(B, 150)),
    hier_own('Utilities', budget, 0),
    retractall(user:metric(_, budget, _)).

:- end_tests(hierarchy).

:- begin_tests(hierarchy_bad_data, [setup(hier_t_setup), cleanup(hier_t_clear)]).

%% A loop: Expenses child_of Pipe closes Expenses -> ... -> Pipe -> Expenses.
%% Every query must still terminate; the loop is reported, and nothing is
%% counted twice.
test(loop_terminates_and_is_reported) :-
    assertz(user:relation('Expenses', child_of, 'Pipe')),
    hier_subtotal('Expenses', E), assertion(close_to(E, 616.50)),
    hier_subtotal('Pipe', P), assertion(close_to(P, 616.50)),
    hier_cycle('Expenses'),
    hier_problems(Ps), memberchk(cycle('Pipe'), Ps),
    \+ hier_path('Pipe', 'Pipe', _),
    retract(user:relation('Expenses', child_of, 'Pipe')).

test(double_parent_and_bad_amount_are_problems) :-
    assertz(user:relation('Phone', child_of, 'Rent')),
    assertz(user:metric('Rent', amount, 'n/a')),
    hier_problems(Ps),
    memberchk(multi_parent('Phone'), Ps),
    memberchk(non_numeric('Rent', 'n/a'), Ps),
    hier_subtotal('Rent', R), assertion(close_to(R, 450.25)),
    retract(user:relation('Phone', child_of, 'Rent')),
    retract(user:metric('Rent', amount, 'n/a')).

:- end_tests(hierarchy_bad_data).
