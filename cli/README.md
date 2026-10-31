# `battery` — the Logic Batteries installer

Install [Logic Batteries](https://github.com/datagrout/logic-batteries) —
pre-built, composable Prolog rule modules (state machines, probabilistic
reasoning, provenance/why-explanations, game and business rules) — into any
SWI-Prolog or Scryer Prolog project. No server, no account: batteries are
plain ISO Prolog files copied into your project.

```console
$ cargo install logic-batteries      # installs the `battery` binary

$ battery install prob-core-iso prob-decide --dir my-app/
✓ installed prob-core-iso 1.0.0 (2 files)
✓ installed prob-decide 1.0.0 (1 file)

$ battery installed --dir my-app/
prob-core-iso 1.0.0
prob-decide 1.0.0

$ battery remove prob-decide --dir my-app/
✓ removed prob_decide.pl
✓ removed prob-decide
```

Then in your app, load them all through the generated `batteries.pl`:

```prolog
:- consult('batteries.pl').
% assert your model, query eu/2, best_action/2, psuccess/2, ...
```

`install` and `remove` rewrite `batteries.pl` to include every installed
battery, and delete it with the last one. Every battery file states its own
manifest (`battery_module/3`, `battery_export/3`) and input contract
(`battery_input/6`); consulted one by one, each file redefines those
predicates and the earlier batteries' clauses are lost. Included into one file
and declared discontiguous, they are all kept, in SWI-Prolog and in Scryer.
Scryer resolves `include/1` against the working directory, so start it from
the install directory. A `batteries.pl` you wrote yourself is never
overwritten.

## Where batteries come from

The CLI installs from a local checkout of the
[logic-batteries repository](https://github.com/datagrout/logic-batteries):

```console
$ git clone https://github.com/datagrout/logic-batteries
$ export LB_REPO=/path/to/logic-batteries   # or pass --repo per command
$ battery list
```

Repo discovery order: `--repo` flag → `$LB_REPO` → walking up from the
current directory. (A remote-fetch mode that needs no checkout is on the
roadmap.)

## Checksummed removal

Every installed file's SHA-256 lands in `batteries.lock.json` next to the
files. `battery remove` deletes only files whose current hash still matches
what was installed — anything you've modified is kept and warned about
unless you pass `-f`. `battery installed` flags modified batteries.
Similarly, `install` refuses to overwrite an unrelated file that happens to
share a battery's filename unless you pass `-f`.

## Commands

| Command | Description |
|---|---|
| `battery install <id>... [--dir D] [--repo R] [-f]` | Copy battery files into a project, record checksums |
| `battery remove <id>... [--dir D] [-f]` | Delete a battery's unmodified files, update the lock |
| `battery installed [--dir D]` | What's installed here, with modification flags |
| `battery list [--repo R]` | All batteries in the registry |
| `battery version` | Print the CLI's version |

## License

The CLI is MIT. The batteries it installs carry their own licenses — see the
[repository license table](https://github.com/datagrout/logic-batteries#license)
(Elastic License 2.0 for content batteries, Apache-2.0 for the prob-core-iso
runtime).
