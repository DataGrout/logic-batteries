:- use_module(library(plunit)).

:- consult('../../modules/engineering/change_risk/change_risk').

%% A sample repository: checkout and invoices call billing's charge, the API
%% calls checkout, and nothing calls util. Billing has its own owners and a
%% catch-all owns the rest, except docs, which nobody owns. Unknown on the
%% platform (no code graph, no owner rules) shows here as a failure.

crt(S, A, V) :- assertz(attribute(S, A, V)).

crt_setup_graph :-
    crt(charge_1, defined_in, 'lib/billing/charge.ex'),
    crt(checkout_2, defined_in, 'lib/checkout.ex'),
    crt(invoice_1, defined_in, 'lib/invoices.ex'),
    crt(show_1, defined_in, 'lib/api.ex'),
    crt(used_0, defined_in, 'lib/util.ex'),
    crt(checkout_2, calls, charge_1),
    crt(invoice_1, calls, charge_1),
    crt(show_1, calls, checkout_2),
    crt(charge_1, calls, used_0).

crt_setup_owners :-
    crt(o1, owns_pattern, '*'),
    crt(o1, owner, '@acme/core'),
    crt(o1, line, 1),
    crt(o2, owns_pattern, '/lib/billing/'),
    crt(o2, owner, '@acme/billing'),
    crt(o2, line, 2),
    crt(o3, owns_pattern, 'docs/'),
    crt(o3, line, 3).

crt_changed(C, Paths) :- crt_files(Paths, C, 1).

crt_files([], _, _).
crt_files([P|Ps], C, N) :-
    atom_concat(C, '_f', B), number_codes(N, Ds), atom_codes(Suffix, Ds),
    atom_concat(B, Suffix, F),
    crt(F, file_of, C),
    crt(F, path, P),
    N1 is N + 1,
    crt_files(Ps, C, N1).

crt_setup_all :- crt_setup_graph, crt_setup_owners.

:- begin_tests(change_risk).

test(billing_change_reaches_three_units, [setup(crt_setup_all), cleanup(clear_facts)]) :-
    crt_changed(pr_1, ['lib/billing/charge.ex']),
    assertion(change_blast_radius(pr_1, 3)),
    findall(U, affected_unit(pr_1, U), Us),
    assertion(Us == [checkout_2, invoice_1, show_1]),
    assertion(low_risk(pr_1)),
    findall(O, owners_of(pr_1, O), Os),
    assertion(Os == ['@acme/billing']).

test(leaf_change_has_no_blast_radius, [setup(crt_setup_all), cleanup(clear_facts)]) :-
    crt_changed(pr_2, ['lib/api.ex']),
    assertion(change_blast_radius(pr_2, 0)).

test(callers_inside_the_change_do_not_count, [setup(crt_setup_all), cleanup(clear_facts)]) :-
    crt_changed(pr_3, ['lib/billing/charge.ex', 'lib/checkout.ex']),
    assertion(change_blast_radius(pr_3, 2)).

test(wide_blast_radius, [setup(crt_setup_all), cleanup(clear_facts)]) :-
    crt_changed(pr_1, ['lib/billing/charge.ex']),
    crt(risk_policy, max_blast_radius, 2),
    assertion(\+ low_risk(pr_1)),
    assertion(risk_reason(pr_1, wide_blast_radius(3, 2))).

test(unowned_docs, [setup(crt_setup_all), cleanup(clear_facts)]) :-
    crt_changed(pr_4, ['lib/util.ex', 'docs/guide/setup.md']),
    assertion(unowned_file(pr_4, 'docs/guide/setup.md')),
    assertion(owner_coverage(pr_4, 1, 2)),
    assertion(risk_reason(pr_4, unowned_files(1))),
    assertion(\+ low_risk(pr_4)).

test(owners_not_required, [setup(crt_setup_graph), cleanup(clear_facts)]) :-
    crt_changed(pr_5, ['lib/util.ex']),
    crt(risk_policy, require_owners, false),
    assertion(low_risk(pr_5)).

test(patterns, [setup(crt_setup_all), cleanup(clear_facts)]) :-
    crt(o4, owns_pattern, '*.md'),
    crt(o4, owner, '@acme/docs'),
    crt(o4, line, 4),
    crt_changed(pr_6, ['docs/guide/setup.md', 'README.md']),
    assertion(owner_coverage(pr_6, 2, 2)).

test(single_star_is_one_level, [setup(crt_setup_graph), cleanup(clear_facts)]) :-
    crt(o1, owns_pattern, '/docs/*'),
    crt(o1, owner, '@acme/docs'),
    crt(o2, owns_pattern, 'lib/**'),
    crt(o2, owner, '@acme/core'),
    crt(o3, owns_pattern, 'fixtures/'),
    crt(o3, owner, '@acme/qa'),
    crt_changed(pr_9, ['docs/index.md', 'docs/guides/setup.md', 'lib/a/b.ex',
                       'test/fixtures/x.json', 'fixtures']),
    findall(P, unowned_file(pr_9, P), Ps),
    assertion(Ps == ['docs/guides/setup.md', fixtures]).

test(wildcards_and_anchoring, [setup(crt_setup_graph), cleanup(clear_facts)]) :-
    crt(o1, owns_pattern, '*'),
    crt(o1, owner, '@acme/core'),
    crt(o1, line, 1),
    crt(o2, owns_pattern, '/lib/*.ex'),
    crt(o2, line, 2),
    crt(o3, owns_pattern, 'docs/*'),
    crt(o3, line, 3),
    crt(o4, owns_pattern, '**/logs/'),
    crt(o4, line, 4),
    crt_changed(pr_10, ['lib/billing.ex', 'lib/sub/deep.ex', 'docs/a.md', 'tools/docs/readme.md',
                        'var/app/logs/x.log', 'lib/notes.txt']),
    findall(P, unowned_file(pr_10, P), Ps),
    assertion(Ps == ['docs/a.md', 'lib/billing.ex', 'var/app/logs/x.log']).

%% Unknown on the platform: no code graph.
test(no_code_graph, [setup(crt_setup_owners), cleanup(clear_facts)]) :-
    crt_changed(pr_7, ['lib/billing/charge.ex']),
    assertion(\+ change_blast_radius(pr_7, _)),
    assertion(\+ low_risk(pr_7)).

%% Unknown on the platform: owners required and no owner rules.
test(no_owner_rules, [setup(crt_setup_graph), cleanup(clear_facts)]) :-
    crt_changed(pr_8, ['lib/api.ex']),
    assertion(change_blast_radius(pr_8, 0)),
    assertion(\+ low_risk(pr_8)).

:- end_tests(change_risk).
