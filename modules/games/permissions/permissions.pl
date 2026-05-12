%% Tether Module: permissions v1.0.0
%% Exports: has_role/2, role_grants/2, is_owner/2, permission_granted/2, can_access/2

tether_module(permissions, '1.0.0', auto).

tether_export(permissions, 'has_role/2',           'has_role(Entity, Role) — Entity holds Role').
tether_export(permissions, 'role_grants/2',        'role_grants(Role, Permission) — Role grants Permission (including inherited)').
tether_export(permissions, 'is_owner/2',           'is_owner(Entity, Resource) — Entity owns Resource').
tether_export(permissions, 'permission_granted/2', 'permission_granted(Entity, Permission) — Entity has Permission via role or ownership').
tether_export(permissions, 'can_access/2',         'can_access(Entity, Resource) — Entity may access Resource').

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
role_grants(Role, Permission) :-
    relation(Role, grants_permission, Permission).
role_grants(Role, Permission) :-
    relation(Role, inherits_from, Parent),
    role_grants(Parent, Permission).

%% is_owner(+Entity, +Resource)
is_owner(Entity, Resource) :-
    attribute(Resource, owner, Entity).

%% permission_granted(+Entity, ?Permission)
permission_granted(Entity, Permission) :-
    has_role(Entity, Role),
    role_grants(Role, Permission).

%% can_access(+Entity, +Resource)
can_access(_Entity, Resource) :-
    attribute(Resource, public, true), !.
can_access(Entity, Resource) :-
    is_owner(Entity, Resource), !.
can_access(Entity, Resource) :-
    attribute(Resource, requires_permission, Permission),
    permission_granted(Entity, Permission).
