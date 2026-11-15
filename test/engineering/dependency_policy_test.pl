:- use_module(library(plunit)).

:- consult('../../modules/engineering/dependency_policy/dependency_policy').

%% A sample repository that allows MIT, Apache-2.0 and BSD-3-Clause and pins
%% react to major 18. Unknown on the platform (no allow-list, no licence)
%% shows here as a failure.

dpt(S, A, V) :- assertz(attribute(S, A, V)).

dpt_setup_policy :-
    dpt(lic_mit, allows_license, 'MIT'),
    dpt(lic_apache, allows_license, 'Apache-2.0'),
    dpt(lic_bsd, allows_license, 'BSD-3-Clause'),
    dpt(pin_react, pins_package, react),
    dpt(pin_react, major, 18).

dpt_dep(Id, C, Package, License, Version) :-
    dpt(Id, dependency_of, C),
    dpt(Id, package, Package),
    dpt(Id, license, License),
    dpt(Id, version, Version).

dpt_setup_clean :-
    dpt_setup_policy,
    dpt_dep(d1, pr_1, lodash, 'MIT', '^4.17.21'),
    dpt_dep(d2, pr_1, react, 'MIT', '18.3.1').

dpt_setup_gpl :-
    dpt_setup_policy,
    dpt_dep(d1, pr_2, readline, 'GPL-3.0-only', '8.2.0').

dpt_setup_major :-
    dpt_setup_policy,
    dpt_dep(d1, pr_3, react, 'MIT', '^19.0.0').

dpt_setup_unpinned :-
    dpt_setup_policy,
    dpt_dep(d1, pr_4, left_pad, 'MIT', '*'),
    dpt_dep(d2, pr_4, chalk, 'MIT', '>= 4').

dpt_setup_no_license :-
    dpt_setup_policy,
    dpt(d1, dependency_of, pr_5),
    dpt(d1, package, mystery),
    dpt(d1, version, '1.0.0').

dpt_setup_no_allow_list :-
    dpt_dep(d1, pr_6, lodash, 'MIT', '4.17.21').

dpt_setup_removed :-
    dpt_setup_policy,
    dpt_dep(d1, pr_7, readline, 'GPL-3.0-only', '8.2.0'),
    dpt(d1, change_type, removed),
    dpt_dep(d2, pr_7, lodash, 'MIT', '4.17.21').

dpt_violations(D, Rs) :- findall(R, dependency_violation(D, R), Rs0), sort(Rs0, Rs).

:- begin_tests(dependency_policy).

test(clean_change, [setup(dpt_setup_clean), cleanup(clear_facts)]) :-
    assertion(dependencies_compliant(pr_1)),
    assertion(major_version(d1, 4)).

test(licence_not_allowed, [setup(dpt_setup_gpl), cleanup(clear_facts)]) :-
    assertion(\+ dependencies_compliant(pr_2)),
    assertion(change_violation(pr_2, d1, license_not_allowed('GPL-3.0-only'))).

test(pinned_major_crossed, [setup(dpt_setup_major), cleanup(clear_facts)]) :-
    assertion(dpt_violations(d1, [major_mismatch(19, 18)])).

test(open_requirements, [setup(dpt_setup_unpinned), cleanup(clear_facts)]) :-
    assertion(dpt_violations(d1, [unpinned_major('*')])),
    assertion(dpt_violations(d2, [unpinned_major('>= 4')])),
    dpt(dependency_policy, require_pinned_major, false),
    assertion(dependencies_compliant(pr_4)).

test(pinned_package_must_fix_its_major, [setup(dpt_setup_policy), cleanup(clear_facts)]) :-
    dpt(dependency_policy, require_pinned_major, false),
    dpt_dep(d1, pr_11, react, 'MIT', '*'),
    assertion(dpt_violations(d1, [unpinned_major('*')])).

test(spdx_expressions, [setup(dpt_setup_policy), cleanup(clear_facts)]) :-
    dpt_dep(a, pr_8, x, 'MIT OR GPL-2.0-only', '1.0.0'),
    dpt_dep(b, pr_8, y, 'MIT AND GPL-2.0-only', '1.0.0'),
    dpt_dep(c, pr_8, z, '(MIT OR Apache-2.0) AND BSD-3-Clause', '1.0.0'),
    dpt_dep(d, pr_8, w, 'mit', '1.0.0'),
    dpt_dep(e, pr_8, v, '(MIT OR GPL-3.0-only)', '1.0.0'),
    dpt_dep(f, pr_8, u, '(GPL-3.0-only OR LGPL-2.1-only) AND MIT', '1.0.0'),
    dpt_dep(g, pr_8, t, 'Apache-2.0 WITH LLVM-exception', '1.0.0'),
    dpt_dep(h, pr_8, s, 'MIT OR (BSD-3-Clause AND GPL-3.0-only)', '1.0.0'),
    dpt_dep(i, pr_8, r, '(MIT', '1.0.0'),
    dpt_dep(j, pr_8, q, 'OR MIT GPL-3.0-only', '1.0.0'),
    dpt_dep(k, pr_8, p, 'MIT GPL-3.0-only OR', '1.0.0'),
    dpt_dep(l, pr_8, o, 'MIT WITH', '1.0.0'),
    dpt_dep(m, pr_8, n, 'MIT OR', '1.0.0'),
    assertion(dependency_allowed(a)),
    assertion(\+ dependency_allowed(b)),
    assertion(dependency_allowed(c)),
    assertion(dependency_allowed(d)),
    assertion(dependency_allowed(e)),
    assertion(\+ dependency_allowed(f)),
    assertion(dependency_allowed(g)),
    assertion(dependency_allowed(h)),
    assertion(\+ dependency_allowed(i)),
    assertion(\+ dependency_allowed(j)),
    assertion(\+ dependency_allowed(k)),
    assertion(\+ dependency_allowed(l)),
    assertion(\+ dependency_allowed(m)).

test(version_forms, [setup(dpt_setup_policy), cleanup(clear_facts)]) :-
    dpt_dep(a, pr_9, a, 'MIT', '~> 1.7'),
    dpt_dep(b, pr_9, b, 'MIT', 'v2.0.1'),
    dpt_dep(c, pr_9, c, 'MIT', '^1.0 || ^2.0'),
    dpt_dep(d, pr_9, d, 'MIT', '3.x'),
    assertion(major_version(a, 1)),
    assertion(major_version(b, 2)),
    assertion(major_version(c, none)),
    assertion(major_version(d, 3)).

test(removed_dependency_not_checked, [setup(dpt_setup_removed), cleanup(clear_facts)]) :-
    assertion(dependencies_compliant(pr_7)).

%% Unknown on the platform: the dependency's licence is not known.
test(no_license, [setup(dpt_setup_no_license), cleanup(clear_facts)]) :-
    assertion(\+ dependency_allowed(d1)),
    assertion(dpt_violations(d1, [])),
    assertion(\+ dependencies_compliant(pr_5)).

%% Unknown on the platform: no allow-list.
test(no_allow_list, [setup(dpt_setup_no_allow_list), cleanup(clear_facts)]) :-
    assertion(\+ dependencies_compliant(pr_6)).

test(reviewed_change_with_no_dependencies, [setup(dpt_setup_policy), cleanup(clear_facts)]) :-
    dpt(pr_10, dependency_review, true),
    assertion(dependencies_compliant(pr_10)).

%% Unknown on the platform: no comparison was fetched (false is not a value
%% the marker takes).
test(unreviewed_change, [setup(dpt_setup_policy), cleanup(clear_facts)]) :-
    dpt(pr_12, dependency_review, false),
    assertion(\+ dependencies_compliant(pr_12)),
    assertion(\+ dependencies_compliant(pr_13)).

:- end_tests(dependency_policy).
