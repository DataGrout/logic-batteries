# Module: dependency-policy v1.0.0

Checks the dependencies a change adds or updates against a policy held as data: a licence allow-list and pinned major versions. Licences are SPDX identifiers or expressions; version requirements are read in the common forms (`4.17.21`, `^4.17`, `~> 1.7`, `3.x`), and a requirement that fixes no major (`*`, `>= 2`, `^1 || ^2`) can be flagged.

## Install

**MCP** (Claude Code, Conduit SDK, any MCP client):

```python
client.perform("data-grout@1/batteries.install_many@1", {
    "ids": ["dependency-policy"],
    "namespace": "my-namespace"
})
```

## Exported Predicates

| Predicate | Description |
|---|---|
| `dependency_allowed(Dep)` | The licence is allowed and the version keeps to any pinned major |
| `dependency_violation(Dep, Reason)` | Reason is `license_not_allowed(License)`, `major_mismatch(Major, Pinned)` or `unpinned_major(Version)` |
| `dependencies_compliant(Change)` | Every dependency the change adds or updates is allowed |
| `change_violation(Change, Dep, Reason)` | A dependency the change adds or updates breaks the policy |
| `major_version(Dep, Major)` | The major the version fixes, or `none` |

## Facts this battery reads

**Attributes**

| Name | On | Value | Description |
|---|---|---|---|
| `package` | dependency | atom | The package name |
| `dependency_of` | dependency | change id | The change that adds, updates or removes it |
| `license` | dependency | atom | SPDX identifier or expression. Left out when unknown |
| `version` | dependency | atom | The version or the manifest's requirement |
| `change_type` | dependency | `added`, `updated` or `removed` | Default `added`. Removed dependencies are not checked |
| `dependency_review` | change | `true` | Once the change's dependency comparison was fetched. There is no `false`: an unfetched comparison has no marker |
| `allows_license` | allowed licence | atom | A licence identifier dependencies may carry |
| `pins_package` | pin | atom | A package whose major is pinned |
| `major` | pin | integer | The major it must stay on |
| `require_pinned_major` | `dependency_policy` | `true`/`false` | **Tunable.** Default `true`: a requirement fixing no major is a violation. A pinned package must fix its major either way |

## Example

```prolog
attribute(lic_mit, allows_license, 'MIT').
attribute(pin_react, pins_package, react).
attribute(pin_react, major, 18).

attribute(d1, dependency_of, pr_7).
attribute(d1, package, react).
attribute(d1, license, 'MIT').
attribute(d1, version, '^19.0.0').
```

```prolog
?- dependency_violation(d1, Why).
Why = major_mismatch(19, 18).
```

## Notes

- Licences are compared ignoring case. Expressions are read with SPDX precedence: `WITH` binds tightest, then `AND`, then `OR`, and parentheses group. `OR` needs one allowed alternative, `AND` every part. An identifier with an exception (`Apache-2.0 WITH LLVM-exception`) is judged by the identifier. An expression that does not parse is not allowed.
- A dependency with no licence is never allowed and never a violation: on DataGrout, questions about it come back unknown, naming the licence. The same holds with no allow-list loaded.
- A change no dependency refers to is decided only once `dependency_review` is `true` for it; until then nothing says its dependencies were looked at, and on DataGrout the answer is unknown.
