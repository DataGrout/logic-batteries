#!/usr/bin/env python3
"""Every fact a battery reads must be documented in its README.

A battery's exports are declared (`battery_export/3`) and tabled in its README.
The facts it *consumes* — the `attribute/3` and `relation/3` names its clauses
look up — were declared nowhere: not in the manifest, not in `battery_export`,
and in only 7 of 48 files as comment blocks. A user who wanted to know which
`*_threshold` attributes `faction` honours had to read the source. On
2026-09-10, 16 of 46 READMEs omitted at least one name their own code reads,
and the omissions were systematically the tunables.

This script reads the names out of the clauses and checks that each appears,
as `` `name` ``, inside the README's `## Facts this battery reads` section.
That is the whole contract: no consumed name undocumented. The table itself is
hand-curated — the "on" and "value" columns need a human — so the check is
deliberately not "table equals extraction".

  scripts/check_readme_vocab.py --check              # lint all batteries (exit 1 on any gap)
  scripts/check_readme_vocab.py --check quests       # one battery
  scripts/check_readme_vocab.py --draft quests       # a starting table to paste and curate

Names built at runtime (`atom_concat`, `atomic_list_concat`, `format(atom(_)…)`)
cannot be seen here; batteries that do that are flagged and their extracted
list is a floor, not the whole vocabulary.
"""

import argparse
import glob
import os
import re
import sys
from collections import defaultdict

MODULES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "modules")
SECTION = "## Facts this battery reads"

# attribute(Entity, name, Value) / relation(Subject, name, Object) / metric / tag —
# name must be a literal lowercase atom. A variable in the name position is a
# generic read (e.g. an inspector iterating every attribute) and is not vocabulary.
READ = re.compile(r"\b(attribute|relation|metric|tag)\(\s*([^,()]+?)\s*,\s*([a-z][a-z0-9_]*)\s*(?:,\s*([^,()]*?)\s*)?\)")
HEAD = re.compile(r"^([a-z][A-Za-z0-9_]*)\s*(?:\(|:-|\.)", re.M)
DYNAMIC = re.compile(r"\batom_concat\b|\batomic_list_concat\b|format\(\s*atom\(")
FENCE = re.compile(r"`([a-z][a-z0-9_]*)`")


def strip_comments(src):
    # Line comments only. A `%` inside a quoted atom would be misread; none of
    # the batteries do that today, and a false strip only loses a read.
    return "\n".join(l for l in src.splitlines() if not l.lstrip().startswith("%"))


def battery_dirs(only=None):
    for pl in sorted(glob.glob(os.path.join(MODULES, "*", "*", "*.pl"))):
        d = os.path.dirname(pl)
        bid = os.path.basename(d)
        if only and bid not in only:
            continue
        yield bid, d


def read_names(battery_dir):
    """{(kind, name): {"on": set(), "values": set(), "by": set()}} plus a dynamic flag."""
    out = defaultdict(lambda: {"on": set(), "values": set(), "by": set()})
    dynamic = False
    for pl in sorted(glob.glob(os.path.join(battery_dir, "*.pl"))):
        code = strip_comments(open(pl, encoding="utf-8", errors="replace").read())
        if "battery_export(" not in code and len(glob.glob(os.path.join(battery_dir, "*.pl"))) > 1:
            continue  # helper file, not the battery's own clauses
        dynamic = dynamic or bool(DYNAMIC.search(code))
        heads = [(m.start(), m.group(1)) for m in HEAD.finditer(code)]
        for m in READ.finditer(code):
            kind, first, name, third = m.group(1), m.group(2), m.group(3), m.group(4)
            entry = out[(kind, name)]
            entry["on"].add(first if first[:1].isupper() else f"`{first}`")
            if third is not None and re.fullmatch(r"true|false|-?\d+(\.\d+)?|[a-z][a-z0-9_]*", third):
                entry["values"].add(third)
            head = None
            for pos, h in heads:
                if pos <= m.start():
                    head = h
                else:
                    break
            if head and head != "battery_export":
                entry["by"].add(head)
    return out, dynamic


def readme_section(battery_dir):
    path = os.path.join(battery_dir, "README.md")
    if not os.path.exists(path):
        return None, None
    text = open(path, encoding="utf-8").read()
    if SECTION not in text:
        return text, None
    start = text.index(SECTION) + len(SECTION)
    rest = text[start:]
    nxt = re.search(r"^## ", rest, re.M)
    return text, rest[: nxt.start()] if nxt else rest


def check(only):
    failures = 0
    for bid, d in battery_dirs(only):
        names, dynamic = read_names(d)
        if not names:
            continue
        text, section = readme_section(d)
        if text is None:
            print(f"{bid}: no README.md")
            failures += 1
            continue
        if section is None:
            print(f"{bid}: README has no '{SECTION}' section ({len(names)} names read)")
            failures += 1
            continue
        documented = set(FENCE.findall(section))
        missing = sorted(n for (_, n) in names if n not in documented)
        if missing:
            print(f"{bid}: {len(missing)} read but not in the facts table: {', '.join(missing)}")
            failures += 1
    if failures:
        print(f"\n{failures} batter{'y' if failures == 1 else 'ies'} with undocumented facts.", file=sys.stderr)
    return 1 if failures else 0


def humanise(var):
    # Player -> player, ReqItem -> req item, Obj -> obj. Curators rename.
    return re.sub(r"(?<!^)(?=[A-Z])", " ", var).lower()


def draft(bid):
    matches = [d for b, d in battery_dirs([bid])]
    if not matches:
        print(f"no battery named {bid}", file=sys.stderr)
        return 1
    names, dynamic = read_names(matches[0])
    print(SECTION)
    print()
    if dynamic:
        # atom_concat and friends may be building entity keys (quests joins
        # player and quest ids) or fact names (combat builds `resist_<type>`).
        # Static reading cannot tell which, so say only what is known.
        print("<!-- This battery uses atom_concat/atomic_list_concat/format(atom). If any of those build a fact NAME (not an entity key), that name is not in this list; add it by hand. -->")
        print()
    # Attributes and relations in separate tables so the kinds are not
    # interleaved, and a Description column for the curator rather than a
    # "read by" column: which predicates consume a fact is useful to know but
    # made the table the thing you had to read around. The clause names are
    # left in an HTML comment per row so the curator has them while writing.
    by_kind = defaultdict(list)
    for (kind, name), e in sorted(names.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        by_kind[kind].append((name, e))

    if by_kind.get("attribute"):
        print("**Attributes**")
        print()
        print("| Name | On | Value | Description |")
        print("|---|---|---|---|")
        for name, e in by_kind["attribute"]:
            on = ", ".join(sorted(humanise(o) if not o.startswith("`") else o for o in e["on"]))
            vals = " \\| ".join(f"`{v}`" for v in sorted(e["values"])) if e["values"] else ""
            by = ", ".join(sorted(e["by"]))
            print(f"| `{name}` | {on} | {vals} |  <!-- read by: {by} --> |")
        print()

    for kind in ("relation", "metric", "tag"):
        if not by_kind.get(kind):
            continue
        print(f"**{kind.capitalize()}s**")
        print()
        print("| Name | Subject → Object | Description |")
        print("|---|---|---|")
        for name, e in by_kind[kind]:
            on = ", ".join(sorted(humanise(o) if not o.startswith("`") else o for o in e["on"]))
            by = ", ".join(sorted(e["by"]))
            print(f"| `{name}` | {on} → … |  <!-- read by: {by} --> |")
        print()
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", nargs="*", metavar="BATTERY", help="lint every battery, or the named ones")
    g.add_argument("--draft", metavar="BATTERY", help="print a starting facts table for one battery")
    args = ap.parse_args()
    if args.draft:
        sys.exit(draft(args.draft))
    sys.exit(check(set(args.check) if args.check else None))


if __name__ == "__main__":
    main()
