# Module: permissions v1.0.0

Role-based access control with inheritance, ownership checks, and public resource handling. Works for both game-level permissions (admin tools, moderation) and in-game systems (guild ranks, party leader).

## Install


**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["permissions"],
    "namespace": "my-namespace"
})
```

**Lua / Roblox** — via [Tether](https://github.com/datagrout/tether):

```lua
dg:batteries().install("permissions", "my-game", function(result)
  print("Installed " .. result.predicate_count .. " predicates")
end)
```
## Exported Predicates

| Predicate | Description |
|---|---|
| `has_role(Entity, Role)` | Entity holds Role |
| `role_grants(Role, Permission)` | Role grants Permission (follows `inherits_from` chains) |
| `is_owner(Entity, Resource)` | Entity owns Resource |
| `permission_granted(Entity, Permission)` | Entity has Permission via any role |
| `can_access(Entity, Resource)` | Entity may access Resource (public, owner, or permission) |

## Access Hierarchy

`can_access` resolves in this order:
1. Resource is `public` → always accessible
2. Entity is the owner → accessible
3. Entity has the required permission via a role → accessible

## Setup

### Role assignment

```lua
local ns = "my-game"

dg:assert(ns, { type="relation", subject="alice", relation="has_role", object="admin"  })
dg:assert(ns, { type="relation", subject="bob",   relation="has_role", object="editor" })
```

### Role permissions

```lua
dg:assert(ns, { type="relation", subject="admin",  relation="grants_permission", object="delete_posts"  })
dg:assert(ns, { type="relation", subject="admin",  relation="grants_permission", object="manage_users"  })
dg:assert(ns, { type="relation", subject="editor", relation="grants_permission", object="edit_posts"    })
```

### Role inheritance

```lua
-- admin inherits all editor permissions
dg:assert(ns, { type="relation", subject="admin", relation="inherits_from", object="editor" })
```

### Ownership

```lua
dg:assert(ns, { type="attribute", entity="post_123", attribute="owner", value="alice" })
```

### Resource gates

```lua
-- Public resource
dg:assert(ns, { type="attribute", entity="landing_page", attribute="public", value=true })

-- Permission-gated resource
dg:assert(ns, { type="attribute", entity="admin_panel", attribute="requires_permission", value="manage_users" })
```

## Querying

```lua
-- Check access before showing a UI element
dg:query(ns, "can_access(alice, admin_panel)", function(result)
  if result then showAdminPanel() end
end)

-- List all permissions an entity holds
dg:query_all(ns, "permission_granted(alice, P)", function(results)
  for _, r in ipairs(results) do print(r.P) end
end)
```

## Game Use Cases

**Guild ranks**: A guild_leader role inherits from officer, which inherits from member. Each rank gates different actions (kick, invite, deposit to vault).

**Party system**: The party_leader has `kick_member` and `set_destination` permissions; others only have `leave_party`.

**Admin tools**: Server admins get `teleport`, `ban`, `spawn_item`. Moderators inherit a subset. New staff start as moderator and get promoted by asserting the admin role.
