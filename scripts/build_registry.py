#!/usr/bin/env python3
"""Merge per-category registry.json files into the top-level registry.json.

Usage:
    python3 scripts/build_registry.py [--check]

    --check   Verify the top-level registry is up-to-date without writing.
              Exits 1 if it would change (use in CI / pre-commit).
"""

import json
import pathlib
import sys
from datetime import date

ROOT = pathlib.Path(__file__).parent.parent
MODULES_DIR = ROOT / "modules"
TOP_LEVEL = ROOT / "registry.json"

CATEGORY_ORDER = ["reasoning", "games", "business", "probabilistic", "d20"]


def load_category_registries():
    modules = []
    for cat in CATEGORY_ORDER:
        path = MODULES_DIR / cat / "registry.json"
        if not path.exists():
            continue
        data = json.loads(path.read_text())
        if "modules" not in data:
            print(f"warning: {path} has no 'modules' key — skipping", file=sys.stderr)
            continue
        for m in data["modules"]:
            if m.get("category") != cat:
                print(f"warning: {m['id']} has category={m.get('category')!r}, expected {cat!r}", file=sys.stderr)
        modules.extend(data["modules"])

    # Pick up any category directories not in CATEGORY_ORDER
    for path in sorted(MODULES_DIR.iterdir()):
        if not path.is_dir() or path.name in CATEGORY_ORDER:
            continue
        reg = path / "registry.json"
        if reg.exists():
            data = json.loads(reg.read_text())
            if "modules" in data:
                print(f"note: including unlisted category '{path.name}'", file=sys.stderr)
                modules.extend(data["modules"])

    return modules


def build(check=False):
    modules = load_category_registries()

    out = {
        "version": "1",
        "updated_at": str(date.today()),
        "modules": modules,
    }
    text = json.dumps(out, indent=2) + "\n"

    if check:
        current = TOP_LEVEL.read_text() if TOP_LEVEL.exists() else ""
        # Compare ignoring updated_at so a date-only diff doesn't fail CI
        current_data = json.loads(current) if current else {}
        out_data = json.loads(text)
        current_modules = current_data.get("modules", [])
        if current_modules != out_data["modules"]:
            print("FAIL: top-level registry.json is out of date. Run: make registry", file=sys.stderr)
            sys.exit(1)
        print("OK: top-level registry.json is up to date.")
        return

    TOP_LEVEL.write_text(text)
    print(f"wrote {TOP_LEVEL} ({len(modules)} modules across {len(set(m['category'] for m in modules))} categories)")


if __name__ == "__main__":
    check = "--check" in sys.argv
    build(check=check)
