#!/usr/bin/env python3
"""Normalise the per-category registry.json files and merge them into the
top-level registry.json.

Usage:
    python3 scripts/build_registry.py [--check]

    --check   Verify everything is up to date without writing. Exits 1 if any
              file would change (use in CI / pre-commit). Also lists batteries
              with no `license` and batteries with no test file — those are
              reported, never invented.

Normalisation, per category file:
  * `installs` is dropped. It was a static 0 on every entry that nothing ever
    incremented, and it rendered as "0 installs" on every marketplace page.
  * `tests_file` is filled from `test/<category>/<id>_test.pl` (or
    `test/<id>_test.pl`, with hyphens in the id read as underscores) when that
    file exists, so an agent can tell which batteries are tested.
  * `updated_at` is bumped to today when the category's module list differs
    from what the top-level registry last recorded for it.
"""

import json
import pathlib
import sys
from datetime import date

ROOT = pathlib.Path(__file__).parent.parent
MODULES_DIR = ROOT / "modules"
TEST_DIR = ROOT / "test"
TOP_LEVEL = ROOT / "registry.json"

CATEGORY_ORDER = ["core", "reasoning", "games", "business", "probabilistic", "d20"]
DROPPED_FIELDS = ("installs",)


def category_dirs():
    seen = []
    for cat in CATEGORY_ORDER:
        if (MODULES_DIR / cat / "registry.json").exists():
            seen.append(cat)
    for path in sorted(MODULES_DIR.iterdir()):
        if path.is_dir() and path.name not in seen and (path / "registry.json").exists():
            print(f"note: including unlisted category '{path.name}'", file=sys.stderr)
            seen.append(path.name)
    return seen


def tests_file_for(cat, module_id):
    stem = module_id.replace("-", "_") + "_test.pl"
    for candidate in (TEST_DIR / cat / stem, TEST_DIR / stem):
        if candidate.exists():
            return str(candidate.relative_to(ROOT))
    return None


def normalise(cat, data, previous_modules):
    """Return the normalised category document and its module list."""
    modules = []
    for m in data["modules"]:
        if m.get("category") != cat:
            print(f"warning: {m['id']} has category={m.get('category')!r}, expected {cat!r}", file=sys.stderr)
        m = {k: v for k, v in m.items() if k not in DROPPED_FIELDS}
        tests = tests_file_for(cat, m["id"])
        if tests:
            m["tests_file"] = tests
        else:
            m.pop("tests_file", None)
        modules.append(m)

    out = dict(data)
    out["modules"] = modules
    if modules != previous_modules:
        out["updated_at"] = str(date.today())
    return out, modules


def report(modules):
    no_license = [m["id"] for m in modules if not m.get("license")]
    no_tests = [m["id"] for m in modules if not m.get("tests_file")]
    if no_license:
        print(f"note: {len(no_license)} batteries have no `license`: {', '.join(no_license)}", file=sys.stderr)
    if no_tests:
        print(f"note: {len(no_tests)} batteries have no test file: {', '.join(no_tests)}", file=sys.stderr)


def build(check=False):
    top_current = json.loads(TOP_LEVEL.read_text()) if TOP_LEVEL.exists() else {}
    previous_by_cat = {}
    for m in top_current.get("modules", []):
        previous_by_cat.setdefault(m.get("category"), []).append(m)

    all_modules = []
    stale = []
    for cat in category_dirs():
        path = MODULES_DIR / cat / "registry.json"
        data = json.loads(path.read_text())
        if "modules" not in data:
            print(f"warning: {path} has no 'modules' key — skipping", file=sys.stderr)
            continue
        out, modules = normalise(cat, data, previous_by_cat.get(cat, []))
        text = json.dumps(out, indent=2) + "\n"
        if text != path.read_text():
            stale.append(path)
            if not check:
                path.write_text(text)
        all_modules.extend(modules)

    top = {"version": "1", "updated_at": str(date.today()), "modules": all_modules}
    top_text = json.dumps(top, indent=2) + "\n"
    if top_current.get("modules", []) != all_modules:
        stale.append(TOP_LEVEL)
        if not check:
            TOP_LEVEL.write_text(top_text)

    report(all_modules)

    if check:
        if stale:
            for p in stale:
                print(f"FAIL: {p.relative_to(ROOT)} is out of date. Run: make registry", file=sys.stderr)
            sys.exit(1)
        print("OK: registry files are up to date.")
        return

    cats = len({m["category"] for m in all_modules})
    print(f"wrote {len(stale)} file(s); {len(all_modules)} modules across {cats} categories")


if __name__ == "__main__":
    build(check="--check" in sys.argv)
