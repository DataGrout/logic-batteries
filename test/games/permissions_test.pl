:- use_module(library(plunit)).

:- consult('../../modules/games/permissions/permissions').

%% ── Setup predicates ─────────────────────────────────────────────────────────

setup_alice_admin :-
    assertz(relation(alice, has_role, admin)),
    assertz(relation(admin, grants_permission, delete_posts)),
    assertz(relation(admin, grants_permission, manage_users)).

setup_role_inheritance :-
    assertz(relation(alice, has_role, admin)),
    assertz(relation(admin, inherits_from, editor)),
    assertz(relation(editor, grants_permission, edit_posts)),
    assertz(relation(admin, grants_permission, delete_posts)).

setup_alice_owns_post :-
    assertz(attribute(post_123, owner, alice)).

setup_public_page :-
    assertz(attribute(landing_page, public, true)).

setup_protected_resource :-
    assertz(attribute(admin_panel, requires_permission, manage_users)).

setup_delete_protected_resource :-
    assertz(attribute(editor_panel, requires_permission, delete_posts)).

setup_alice_admin_with_protected :-
    setup_alice_admin,
    setup_protected_resource.

setup_bob_no_perm_with_protected :-
    assertz(relation(bob, has_role, viewer)),
    setup_protected_resource.

%% ── has_role/2 ───────────────────────────────────────────────────────────────

:- begin_tests(permissions_roles).

test(has_role_direct, [setup(setup_alice_admin), cleanup(clear_facts)]) :-
    assertion(has_role(alice, admin)).

test(no_role_not_held, [setup(setup_alice_admin), cleanup(clear_facts)]) :-
    assertion(\+ has_role(alice, editor)).

:- end_tests(permissions_roles).

%% ── role_grants/2 ────────────────────────────────────────────────────────────

:- begin_tests(permissions_role_grants).

test(direct_grant, [setup(setup_alice_admin), cleanup(clear_facts)]) :-
    assertion(role_grants(admin, delete_posts)).

test(inherited_grant, [setup(setup_role_inheritance), cleanup(clear_facts)]) :-
    assertion(role_grants(admin, edit_posts)).

test(no_ungranted_permission, [setup(setup_alice_admin), cleanup(clear_facts)]) :-
    assertion(\+ role_grants(admin, fly)).

:- end_tests(permissions_role_grants).

%% ── is_owner/2 ───────────────────────────────────────────────────────────────

:- begin_tests(permissions_ownership).

test(owner_succeeds, [setup(setup_alice_owns_post), cleanup(clear_facts)]) :-
    assertion(is_owner(alice, post_123)).

test(non_owner_fails, [setup(setup_alice_owns_post), cleanup(clear_facts)]) :-
    assertion(\+ is_owner(bob, post_123)).

:- end_tests(permissions_ownership).

%% ── can_access/2 ─────────────────────────────────────────────────────────────

:- begin_tests(permissions_access).

test(public_resource_always_accessible, [setup(setup_public_page), cleanup(clear_facts)]) :-
    assertion(can_access(anyone, landing_page)).

test(owner_can_access_own_resource, [setup(setup_alice_owns_post), cleanup(clear_facts)]) :-
    assertion(can_access(alice, post_123)).

test(admin_can_access_protected, [setup(setup_alice_admin_with_protected), cleanup(clear_facts)]) :-
    assertion(can_access(alice, admin_panel)).

test(no_perm_cannot_access, [setup(setup_bob_no_perm_with_protected), cleanup(clear_facts)]) :-
    assertion(\+ can_access(bob, admin_panel)).

test(inherited_perm_grants_access, [setup((setup_role_inheritance, setup_delete_protected_resource)), cleanup(clear_facts)]) :-
    %% admin inherits delete_posts from editor via role_grants/2 → can access editor_panel
    assertion(can_access(alice, editor_panel)).

:- end_tests(permissions_access).

%% ── inheritance cycles terminate (v1.0.1) ────────────────────────────────────

setup_perm_fix_cycle :-
    assertz(relation(a_role, inherits_from, b_role)),
    assertz(relation(b_role, inherits_from, a_role)),
    assertz(relation(b_role, grants_permission, wave)),
    assertz(relation(alice, has_role, a_role)).

:- begin_tests(permissions_cycle).

test(grant_found_through_cycle, [setup(setup_perm_fix_cycle), cleanup(clear_facts)]) :-
    assertion(role_grants(a_role, wave)).

test(missing_grant_fails_instead_of_looping, [setup(setup_perm_fix_cycle), cleanup(clear_facts)]) :-
    %% before the visited set this goal never returned
    assertion(\+ role_grants(a_role, fly)).

test(permission_granted_through_cycle, [setup(setup_perm_fix_cycle), cleanup(clear_facts)]) :-
    assertion(permission_granted(alice, wave)).

:- end_tests(permissions_cycle).

%% ── Unbound Entity / Resource: enumerate every match ─────────────────────────

perm_setup_listers :-
    assertz(attribute(home_page, public, true)),
    assertz(attribute(post_9, owner, bob)),
    assertz(attribute(post_9, requires_permission, edit_posts)),
    assertz(attribute(admin_console, requires_permission, manage_users)),
    assertz(relation(alice, has_role, admin)),
    assertz(relation(carol, has_role, editor)),
    assertz(relation(bob,   has_role, viewer)),
    assertz(relation(admin, grants_permission, manage_users)),
    assertz(relation(admin, inherits_from, editor)),
    assertz(relation(editor, grants_permission, edit_posts)).

:- begin_tests(permissions_unbound).

test(can_access_lists_every_resource, [setup(perm_setup_listers), cleanup(clear_facts)]) :-
    findall(R, can_access(alice, R), Rs0),
    msort(Rs0, Rs),
    assertion(Rs == [admin_console, home_page, post_9]),
    findall(R, can_access(bob, R), Bs0),
    msort(Bs0, Bs),
    assertion(Bs == [home_page, post_9]).

test(can_access_lists_every_entity, [setup(perm_setup_listers), cleanup(clear_facts)]) :-
    findall(E, can_access(E, post_9), Es0),
    msort(Es0, Es),
    assertion(Es == [alice, bob, carol]),
    findall(E, can_access(E, admin_console), As),
    assertion(As == [alice]).

test(can_access_public_is_anyone, [setup(perm_setup_listers), cleanup(clear_facts)]) :-
    can_access(E, home_page), assertion(var(E)).

test(can_access_bound_is_deterministic, [setup(perm_setup_listers), cleanup(clear_facts)]) :-
    findall(x, can_access(alice, post_9), Xs),
    assertion(Xs == [x]).

:- end_tests(permissions_unbound).
