# Module: permissions v1.0.1

Roles that grant permissions and inherit from one another, ownership, public
resources, and a single access check that combines them. Fits game systems
(guild ranks, party leader) and game-level tooling (admin, moderation) alike.

## Install

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["permissions"],
    "namespace": "my-game"
})
```

From Tether: `dg:batteries().install("permissions", "my-game", cb)`.

## Exported Predicates

| Predicate | Description |
|---|---|
| `has_role(Entity, Role)` | The relation, as a predicate |
| `role_grants(Role, Permission)` | Granted directly, or by any role reached through `inherits_from` |
| `is_owner(Entity, Resource)` | The resource's `owner` is the entity |
| `permission_granted(Entity, Permission)` | Some role the entity holds grants it |
| `can_access(Entity, Resource)` | Public, or owned by the entity, or the entity holds the resource's `requires_permission` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `owner` | resource | an entity id | The owner can always access the resource |
| `public` | resource | `true` | Anyone can access it |
| `requires_permission` | resource | a permission id | Access needs a role granting this. A resource with none of the three is accessible to nobody |

**Relations**

| Name | Subject → Object | Description |
|---|---|---|
| `has_role` | entity → role | Role assignment; an entity may hold several |
| `grants_permission` | role → permission | What the role allows |
| `inherits_from` | role → role | The role also grants everything its parent grants, transitively. A cycle is tolerated: the walk remembers where it has been |

## Access Order

`can_access` tries, in order: `public`, then ownership, then permission. The
first that holds wins; a resource with none of them is closed.

## Setup

```
# Roles
{ type="relation", subject="alice", relation="has_role", object="admin" }
{ type="relation", subject="bob",   relation="has_role", object="editor" }

# What roles grant
{ type="relation", subject="admin",  relation="grants_permission", object="delete_posts" }
{ type="relation", subject="admin",  relation="grants_permission", object="manage_users" }
{ type="relation", subject="editor", relation="grants_permission", object="edit_posts" }

# admin gets everything editor has
{ type="relation", subject="admin", relation="inherits_from", object="editor" }

# Resources
{ type="attribute", entity="post_123",     attribute="owner",               value="bob" }
{ type="attribute", entity="landing_page", attribute="public",              value=true }
{ type="attribute", entity="admin_panel",  attribute="requires_permission", value="manage_users" }
```

## Querying

```
# Before showing the panel
can_access(alice, admin_panel)
can_access(bob, admin_panel)
   false

# bob owns his post; alice can edit posts but does not own it
can_access(bob, post_123)
can_access(alice, post_123)
   false

# Everything alice may do, inherited included
permission_granted(alice, P)
   P = delete_posts ; P = manage_users ; P = edit_posts
```

From Tether, in a loop that already speaks it:

```lua
dg:query("my-game", "can_access(" .. player.Name .. ", admin_panel)", function(r) if #r > 0 then showAdminPanel() end end)
```

## Semantics worth knowing

**Inheritance may cycle.** `role_grants` walks `inherits_from` with a visited
set, so `a inherits_from b` together with `b inherits_from a` simply means the
two roles grant the same permissions. Ranks are usually a chain, but a mistake
in the data no longer hangs a query.

**Ownership is not a permission.** `is_owner` opens `can_access` on that
resource only; it grants nothing `permission_granted` can see. A resource with
`requires_permission` is still open to its owner.

**Closed by default.** No `public`, no `owner`, no `requires_permission` —
`can_access` fails for everyone, including admins. Every resource needs at
least one of the three.

## Game Use Cases

**Guild ranks** — `guild_leader inherits_from officer inherits_from member`,
each granting its own actions (kick, invite, vault). **Party** — the leader
holds `kick_member` and `set_destination`; everyone holds `leave_party`.
**Staff** — moderators inherit a subset of admin; promotion is one `has_role`
assert.

## Changes

**1.0.1** — `role_grants` carries a visited set; an inheritance cycle
terminates instead of looping forever.
