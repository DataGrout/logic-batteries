#!/usr/bin/env python3
"""Check each battery's input contract (battery_input/6) against its source.

Usage:
    python3 scripts/check_inputs.py            # report, exit 1 on a problem
    python3 scripts/check_inputs.py --json ID  # print one battery's inputs as JSON

A contract is optional; a battery without one is skipped. When a battery has
one, it must:
  * parse, with a known type and presence on every entry;
  * give every entity role at least one `key` fact (a fixed(Name) role is one
    named subject, so it needs none, but a `key` there means "one of these must
    be present");
  * declare every attribute, relation and metric name the rules read, and read
    every name it declares.

`inputs_for(path)` is what build_registry.py uses to put the contract into
registry.json, so DataGrout can validate facts and build a JSON Schema
without parsing Prolog.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).parent.parent
MODULES = ROOT / "modules"

KINDS = {"attribute", "relation", "metric"}
SIMPLE_TYPES = {"number", "integer", "days", "date", "bool", "atom", "list"}
SIMPLE_PRESENCE = {"key", "required", "optional"}


# ── A small reader for the terms a contract uses ─────────────────────────────

TOKEN = re.compile(
    r"\s*(?:(?P<num>-?\d+(?:\.\d+)?)|(?P<qatom>'(?:[^'\\]|''|\\.)*')|"
    r"(?P<atom>[a-z][A-Za-z0-9_]*)|(?P<var>[A-Z_][A-Za-z0-9_]*)|(?P<punct>[()\[\],]))"
)


def tokens(text):
    pos = 0
    out = []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m or m.end() == pos:
            if text[pos:].strip() == "":
                break
            raise ValueError(f"cannot read {text[pos:pos + 20]!r}")
        pos = m.end()
        kind = m.lastgroup
        value = m.group(kind)
        if kind == "qatom":
            value = value[1:-1].replace("''", "'").replace("\\'", "'")
            kind = "atom"
        elif kind == "num":
            value = float(value) if "." in value else int(value)
        out.append((kind, value))
    return out


def parse_term(toks, i=0):
    kind, value = toks[i]
    if kind == "num":
        return value, i + 1
    if kind == "var":
        return {"var": value}, i + 1
    if kind == "punct" and value == "[":
        items = []
        i += 1
        if toks[i] == ("punct", "]"):
            return items, i + 1
        while True:
            item, i = parse_term(toks, i)
            items.append(item)
            if toks[i] == ("punct", ","):
                i += 1
                continue
            if toks[i] == ("punct", "]"):
                return items, i + 1
            raise ValueError("expected , or ] in a list")
    if kind == "atom":
        if i + 1 < len(toks) and toks[i + 1] == ("punct", "("):
            args = []
            i += 2
            while True:
                arg, i = parse_term(toks, i)
                args.append(arg)
                if toks[i] == ("punct", ","):
                    i += 1
                    continue
                if toks[i] == ("punct", ")"):
                    return {"f": value, "args": args}, i + 1
                raise ValueError("expected , or ) in arguments")
        return value, i + 1
    raise ValueError(f"unexpected {value!r}")


def clauses(source, functor):
    """Each `functor(...)` clause at the start of a line, as its argument text."""
    out = []
    for m in re.finditer(rf"^{functor}\(", source, re.M):
        depth, j, quoted = 0, m.end() - 1, False
        while j < len(source):
            c = source[j]
            if quoted:
                if c == "'" and source[j + 1:j + 2] == "'":
                    j += 1
                elif c == "\\":
                    j += 1
                elif c == "'":
                    quoted = False
            elif c == "'":
                quoted = True
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    out.append(source[m.start():j + 1])
                    break
            j += 1
    return out


# ── The contract ─────────────────────────────────────────────────────────────

def type_json(t):
    if isinstance(t, str) and t in SIMPLE_TYPES:
        return t
    if isinstance(t, dict) and t["f"] == "enum" and len(t["args"]) == 1 and isinstance(t["args"][0], list):
        return {"enum": t["args"][0]}
    if isinstance(t, dict) and t["f"] == "ref" and len(t["args"]) == 1 and isinstance(t["args"][0], str):
        return {"ref": t["args"][0]}
    raise ValueError(f"unknown type {t!r}")


def presence_json(p):
    if isinstance(p, str) and p in SIMPLE_PRESENCE:
        return p
    if isinstance(p, dict) and p["f"] == "default" and len(p["args"]) == 1:
        return {"default": p["args"][0]}
    raise ValueError(f"unknown presence {p!r}")


def inputs_for(path):
    """The battery's contract as a list of dicts, or [] when it has none."""
    source = pathlib.Path(path).read_text()
    out = []
    for text in clauses(source, "battery_input"):
        term, _ = parse_term(tokens(text))
        args = term["args"]
        if len(args) != 6:
            raise ValueError(f"battery_input needs 6 arguments: {text[:60]}")
        _battery, role, fact, typ, presence, note = args
        if isinstance(role, dict) and role["f"] == "fixed":
            role_json = {"fixed": role["args"][0]}
        elif isinstance(role, str):
            role_json = role
        else:
            raise ValueError(f"role must be a name or fixed(Name): {role!r}")
        if not (isinstance(fact, dict) and fact["f"] in KINDS and len(fact["args"]) == 1):
            raise ValueError(f"fact must be attribute(N), relation(N) or metric(N): {fact!r}")
        out.append({
            "role": role_json,
            "kind": fact["f"],
            "name": fact["args"][0],
            "type": type_json(typ),
            "presence": presence_json(presence),
            "note": note if isinstance(note, str) else "",
        })
    return out


READ = {
    "attribute": re.compile(r"\battribute\(\s*[^,()]+,\s*'?([a-z][a-z0-9_]*)'?\s*,"),
    "relation": re.compile(r"\brelation\(\s*[^,()]+,\s*'?([a-z][a-z0-9_]*)'?\s*,"),
    "metric": re.compile(r"\bmetric\(\s*[^,()]+,\s*'?([a-z][a-z0-9_]*)'?\s*,"),
}


def code_only(source):
    """The rules without comments or manifest clauses (a contract's own entries
    would otherwise count as reads)."""
    kept, skipping = [], False
    for line in source.splitlines():
        stripped = line.lstrip()
        if stripped.startswith(("battery_input(", "battery_fact_shape(", "battery_export(", "battery_module(")):
            skipping = True
        if not skipping:
            kept.append(line.split("%", 1)[0])
        if skipping and line.rstrip().endswith(")."):
            skipping = False
    return "\n".join(kept)


def names_read(source):
    """(kind, name) pairs the rules look up, from clause bodies, not comments."""
    code = code_only(source)
    # A term built for output (rostering's `Fact = attribute(Slot, domain, Cs)`)
    # is not a lookup, so a match right after `=` does not count as a read.
    return {
        (kind, m.group(1))
        for kind, rx in READ.items()
        for m in rx.finditer(code)
        if not code[:m.start()].rstrip().endswith("=")
    }


def problems_for(path):
    source = pathlib.Path(path).read_text()
    try:
        inputs = inputs_for(path)
    except (ValueError, IndexError, KeyError) as e:
        return [f"contract does not parse: {e}"]
    if not inputs:
        return None
    problems = []
    roles = {}
    for i in inputs:
        roles.setdefault(json.dumps(i["role"]), []).append(i)
    for role, entries in roles.items():
        if not isinstance(json.loads(role), dict) and not any(e["presence"] == "key" for e in entries):
            problems.append(f"role {json.loads(role)} has no key fact, so its subjects cannot be found")
    declared = {(i["kind"], i["name"]) for i in inputs}
    read = names_read(source)
    for kind, name in sorted(read - declared):
        problems.append(f"reads {kind}({name}) but the contract does not declare it")
    # A name passed in as a parameter (hier_own/2 asks for metric `amount`
    # through hier_own/3) is read without appearing in a lookup, so a declared
    # name only has to occur somewhere in the code.
    code = code_only(source)
    for kind, name in sorted(declared - read):
        if not re.search(rf"\b{re.escape(name)}\b", code):
            problems.append(f"declares {kind}({name}) but no clause mentions it")
    return problems


def battery_files():
    for pl in sorted(MODULES.glob("*/*/*.pl")):
        yield pl


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--json":
        target = sys.argv[2].replace("-", "_")
        for pl in battery_files():
            if pl.stem == target or pl.parent.name.replace("-", "_") == target:
                print(json.dumps(inputs_for(pl), indent=2))
                return 0
        print(f"no battery {sys.argv[2]}", file=sys.stderr)
        return 1

    failed = False
    with_contract = 0
    for pl in battery_files():
        problems = problems_for(pl)
        if problems is None:
            continue
        with_contract += 1
        rel = pl.relative_to(ROOT)
        if problems:
            failed = True
            print(f"FAIL  {rel}")
            for p in problems:
                print(f"      {p}")
        else:
            print(f"ok    {rel}")
    print(f"{with_contract} batteries with an input contract", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
