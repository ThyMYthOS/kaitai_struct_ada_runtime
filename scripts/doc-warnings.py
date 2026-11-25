#!/usr/bin/env python3
"""Sort the warnings of "gnatdoc --warnings" by the part of a package they are in.

   doc-warnings.py [--all] LOG FILE...

LOG is the output of gnatdoc.  FILE... are the specifications that count;
warnings for other files are dropped.  gnatdoc also reports the completions
in the private part of a package, which are not what a user reads, so a
warning counts only if its line is in a visible part.

The classes "entity", "component" and "enumeration literal" are errors: the
exit status is 1 if there is one.  The classes "parameter" and "return value"
are counted only (--all makes them errors as well; --procedures makes
the parameters of procedures errors).
"""
import os
import re
import sys

WARNING = re.compile(r"^(?P<file>[^:]+):(?P<line>\d+):\d+: warning: (?P<text>.*)$")
PRIVATE = re.compile(r"^( *)private\s*$")


def private_lines(path):
    """The numbers of the lines of PATH that are in a private part."""
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    result = set()
    for start, line in enumerate(lines):
        m = PRIVATE.match(line)
        if not m:
            continue
        closing = re.compile("^" + m.group(1) + r"end [A-Za-z0-9_.]+;")
        for number in range(start, len(lines)):
            result.add(number + 1)
            if closing.match(lines[number]):
                break
    return result


def kind(text):
    for name in ("entity", "component", "enumeration literal", "parameter", "return value"):
        if text.startswith(name):
            return name
    return "other"


def main():
    args = sys.argv[1:]
    strict = "--all" in args
    procedures = "--procedures" in args
    args = [a for a in args if a not in ("--all", "--procedures")]
    log, files = args[0], args[1:]
    by_name = {os.path.basename(f): f for f in files}
    hidden = {name: private_lines(path) for name, path in by_name.items()}
    source = {}
    for name, path in by_name.items():
        with open(path, encoding="utf-8", errors="replace") as f:
            source[name] = f.read().split(chr(10))
    counts = {}
    errors = []
    seen = set()
    with open(log, encoding="utf-8", errors="replace") as f:
        for raw in f:
            m = WARNING.match(raw.rstrip("\n"))
            if not m or m.group("file") not in by_name or raw in seen:
                continue
            seen.add(raw)
            if int(m.group("line")) in hidden[m.group("file")]:
                continue
            k = kind(m.group("text"))
            counts[k] = counts.get(k, 0) + 1
            of_procedure = source[m.group("file")][int(m.group("line")) - 1].lstrip().startswith("procedure")
            if k == "parameter" and of_procedure:
                counts["parameter of a procedure"] = counts.get("parameter of a procedure", 0) + 1
            if (strict or k in ("entity", "component", "enumeration literal", "other")
                    or (procedures and k == "parameter" and of_procedure)):
                errors.append(raw.rstrip("\n"))
    for line in errors:
        print(line)
    summary = ", ".join("%s: %d" % (k, counts.get(k, 0)) for k in
                        ("entity", "component", "enumeration literal", "parameter", "parameter of a procedure",
                         "return value", "other"))
    print("%d specifications; not documented in visible parts: %s" % (len(files), summary))
    return 1 if errors else 0


sys.exit(main())
