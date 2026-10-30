%% Battery: permissions v1.0.1
%% Exports: has_role/2, role_grants/2, is_owner/2, permission_granted/2, can_access/2

battery_module(permissions, '1.0.1', auto).

battery_export(permissions, 'has_role/2',           'has_role(Entity, Role) — Entity holds Role').
battery_export(permissions, 'role_grants/2',        'role_grants(Role, Permission) — Role grants Permission (including inherited)').
battery_export(permissions, 'is_owner/2',           'is_owner(Entity, Resource) — Entity owns Resource').
battery_export(permissions, 'permission_granted/2', 'permission_granted(Entity, Permission) — Entity has Permission via role or ownership').
battery_export(permissions, 'can_access/2',         'can_access(Entity, Resource) — Entity may access Resource').

%% ── Input contract ───────────────────────────────────────────────────────────
%%
%% What the rules read (see CONTRIBUTING, "Input contract"). An entity holds
%% roles, a role grants or inherits permissions, and a resource is anything
%% with an owner, a public flag or a required permission. Permissions are plain
%% names: the object of grants_permission and requires_permission.

battery_input(permissions, entity, relation(has_role), ref(role), key,
    'A role this entity holds; an entity may hold several.').
battery_input(permissions, role, relation(grants_permission), atom, key,
    'A permission this role grants directly.').
battery_input(permissions, role, relation(inherits_from), ref(role), key,
    'A parent role whose permissions this role also grants, transitively; a cycle is tolerated.').
battery_input(permissions, resource, attribute(owner), ref(entity), key,
    'The entity that owns the resource and may always access it.').
battery_input(permissions, resource, attribute(public), bool, key,
    'true opens the resource to anyone; any other value counts as not public.').
battery_input(permissions, resource, attribute(requires_permission), atom, key,
    'A permission whose holders may access the resource; with no owner, public or requires_permission, nobody may.').

%% ── Permissions Data Model ────────────────────────────────────────────────────
%%
%% Role assignment:
%%   relation(alice,  has_role,         admin)
%%   relation(bob,    has_role,         editor)
%%
%% Role permissions:
%%   relation(admin,  grants_permission, delete_posts)
%%   relation(editor, grants_permission, edit_posts)
%%
%% Role inheritance:
%%   relation(admin,  inherits_from,    editor)
%%
%% Ownership:
%%   attribute(post_123, owner, alice)
%%
%% Resource access gate:
%%   attribute(admin_panel, requires_permission, manage_users)
%%   attribute(public_page, public, true)

%% has_role(+Entity, +Role)
has_role(Entity, Role) :-
    relation(Entity, has_role, Role).

%% role_grants(+Role, ?Permission)  — follows inherits_from chains
%% Visited-set walk: an inheritance cycle (a inherits_from b, b inherits_from a)
%% terminates instead of looping. Directives are stripped at install, so
%% tabling is not available for this.
role_grants(Role, Permission) :-
    role_grants_(Role, Permission, [Role]).

role_grants_(Role, Permission, _) :-
    relation(Role, grants_permission, Permission).
role_grants_(Role, Permission, Seen) :-
    relation(Role, inherits_from, Parent),
    \+ member(Parent, Seen),
    role_grants_(Parent, Permission, [Parent|Seen]).

%% is_owner(+Entity, +Resource)
is_owner(Entity, Resource) :-
    attribute(Resource, owner, Entity).

%% permission_granted(+Entity, ?Permission)
permission_granted(Entity, Permission) :-
    has_role(Entity, Role),
    role_grants(Role, Permission).

%% can_access(?Entity, ?Resource)
%% Unbound Resource ranges over every resource with a `public`, `owner` or
%% `requires_permission` fact. A public resource is open to anyone, so it
%% leaves an unbound Entity unbound; otherwise an unbound Entity ranges over
%% the owner and every holder of the permission, each once. Bound, it
%% succeeds at most once.
can_access(Entity, Resource) :-
    ( var(Resource) -> permissions_resource(Resource) ; true ),
    (   attribute(Resource, public, true) -> true
    ;   var(Entity)
    ->  setof(E, permissions_grantee(E, Resource), Entities),
        member(Entity, Entities)
    ;   permissions_grantee(Entity, Resource) -> true
    ).

permissions_grantee(Entity, Resource) :-
    is_owner(Entity, Resource).
permissions_grantee(Entity, Resource) :-
    attribute(Resource, requires_permission, Permission),
    permission_granted(Entity, Permission).

permissions_resource(Resource) :-
    setof(R, permissions_resource_named(R), Resources),
    member(Resource, Resources).

permissions_resource_named(R) :- attribute(R, public, true).
permissions_resource_named(R) :- attribute(R, owner, _).
permissions_resource_named(R) :- attribute(R, requires_permission, _).
