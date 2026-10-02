"""agent-check: your own checks on any project, for the agent-grid manager.

Reads .agent-grid/checks.toml in the current folder (the folder root):

  protect = ["tests/", "SPEC.md"]       files analysts can read but never change
  [[check]]  name, run, timeout         commands that must pass (exit 0)
  [[golden]] name, workflow, inputs,    known inputs with known-good outputs: the
             expect, compare            workflow runs on the inputs, and each output
                                        must match its expected file
Levy folders also use [roll], [rules], [backtest] and the rest: see levy-check.

Commands:
  agent-check init                    write a starter checks.toml to fill in
  agent-check run                     run every [[check]] here (and levy-check's rules, in a
                                      levy folder); the manager uses it after changing inputs
  agent-check compare EXPECTED ACTUAL compare two files; exit 0 if they match
  agent-check plan                    (used by agent-hook) the checks and golden tests, as JSON
  agent-check protect                 (used by agent-hook) the protected paths, one per line

Exit codes: 0 all passed, 1 a check failed, 2 checks.toml or a file it names can't be used.
"""
import difflib
import json
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ImportError:  # Python < 3.11
    tomllib = None

CONFIG = Path(".agent-grid/checks.toml")
ALWAYS = [".agent-grid/checks.toml", ".agent-grid/review.md", ".agent-grid/backtest/", ".agent-grid/golden/"]
SHOW = 40

TEMPLATE = """# Your answer key for this folder: what "correct" means, from sources other than the
# analyst's code (a spec, tests you wrote, known-good outputs). Analysts can read this file
# but never change it: agent-grid blocks their edits. Paths are relative to the folder root.

# Files and folders analysts can read but never change: your own tests, fixtures, specs.
# (This file, .agent-grid/golden/, .agent-grid/backtest/, and review.md always are.)
protect = []                    # e.g. ["tests/", "fixtures/", "SPEC.md"]

# Commands that must pass, run from the folder root in the test copy, after the workflows.
# Exit 0 means pass. Use tests you wrote or trust, not ones the analyst wrote.
# [[check]]
# name = "unit tests"
# run = "python3 -m pytest -q tests/"
# timeout = 600                 # seconds (default 600)

# Known inputs with known-good outputs. The workflow runs in its own copy with these
# inputs swapped in, and each output must match its expected file exactly (text files
# ignore Windows line endings; .xlsx files compare cell values).
# [[golden]]
# name = "March sample"
# workflow = ""                 # blank = the folder's only workflow
# inputs = { "data/input.csv" = ".agent-grid/golden/march/input.csv" }
# expect = { "out/report.csv" = ".agent-grid/golden/march/report.csv" }
# compare = ""                  # instead of an exact match: a command, run in that copy,
#                               # that exits 0 when the outputs are right
"""


class Unusable(Exception):
    """checks.toml or a file it names can't be used: the user's problem, not the analyst's."""


def load_config():
    if tomllib is None:
        raise Unusable("agent-check needs Python 3.11 or newer (for tomllib).")
    if not CONFIG.is_file():
        raise Unusable(f"No {CONFIG} here. Run: agent-check init")
    try:
        return tomllib.loads(CONFIG.read_text(encoding="utf-8"))
    except tomllib.TOMLDecodeError as e:
        raise Unusable(f"{CONFIG} isn't valid TOML: {e}")


def inside(p, what):
    """A path relative to the folder root, without '..'."""
    s = str(p).strip().replace("\\", "/")
    while s.startswith("./"):
        s = s[2:]
    if not s or s.startswith("/") or (len(s) > 1 and s[1] == ":") or ".." in Path(s).parts:
        raise Unusable(f"{what} {p!r} must be a path inside this folder, relative to its root.")
    return s


def protected(cfg):
    out = list(ALWAYS)
    for p in cfg.get("protect") or []:
        s = inside(p, "protect entry")
        if Path(s).is_dir() and not s.endswith("/"):
            s += "/"
        if s not in out:
            out.append(s)
    return out


def workflows():
    return sorted(p.parent.name for p in Path(".agent-grid/workflows").glob("*/run.sh"))


def plan(cfg):
    checks = []
    for i, c in enumerate(cfg.get("check") or [], start=1):
        if not isinstance(c, dict) or not str(c.get("run") or "").strip():
            raise Unusable(f"[[check]] number {i} has no run command.")
        checks.append({"name": str(c.get("name") or f"check {i}"), "run": str(c["run"]),
                       "timeout": int(c.get("timeout", 600))})
    goldens, wfs = [], workflows()
    for i, g in enumerate(cfg.get("golden") or [], start=1):
        name = str(g.get("name") or f"golden {i}")
        expect = [[inside(o, f"golden {name!r} expect output"), inside(e, f"golden {name!r} expected file")]
                  for o, e in (g.get("expect") or {}).items()]
        inputs = [[inside(d, f"golden {name!r} input"), inside(s, f"golden {name!r} input file")]
                  for d, s in (g.get("inputs") or {}).items()]
        compare = str(g.get("compare") or "").strip()
        if not expect and not compare:
            raise Unusable(f"golden {name!r} has neither expect nor compare, so nothing would be checked.")
        for _, e in expect:
            if not Path(e).is_file():
                raise Unusable(f"golden {name!r}: the expected file {e} doesn't exist.")
        for _, s in inputs:
            if not Path(s).is_file():
                raise Unusable(f"golden {name!r}: the input file {s} doesn't exist.")
        wf = str(g.get("workflow") or "").strip()
        if wf and wf not in wfs:
            raise Unusable(f"golden {name!r}: {wf!r} isn't a workflow in .agent-grid/workflows/.")
        if not wf and len(wfs) > 1:
            raise Unusable(f"golden {name!r} names no workflow, but there are {len(wfs)} ({', '.join(wfs)}). Name one.")
        goldens.append({"name": name, "workflow": wf or (wfs[0] if wfs else ""), "inputs": inputs,
                        "expect": expect, "compare": compare})
    return {"protect": protected(cfg), "levy": isinstance(cfg.get("roll"), dict),
            "checks": checks, "golden": goldens}


# ---- Comparing an output with its known-good version ---------------
def xlsx_cells(path):
    import openpyxl
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    out = {}
    for ws in wb.worksheets:
        out[ws.title] = {}
        for r, row in enumerate(ws.iter_rows(values_only=True), start=1):
            for c, v in enumerate(row, start=1):
                if v is not None and v != "":
                    out[ws.title][(r, c)] = v
    wb.close()
    return out


def cell_name(r, c):
    s = ""
    while c:
        c, m = divmod(c - 1, 26)
        s = chr(65 + m) + s
    return f"{s}{r}"


def compare(expected, actual):
    """(matched, lines describing the difference)"""
    e, a = Path(expected), Path(actual)
    if not e.is_file():
        raise Unusable(f"The expected file {expected} doesn't exist.")
    if not a.is_file():
        return False, [f"the workflow didn't write {actual}"]
    if e.suffix.lower() in (".xlsx", ".xlsm") and a.suffix.lower() in (".xlsx", ".xlsm"):
        try:
            ec, ac = xlsx_cells(e), xlsx_cells(a)
        except ImportError:
            raise Unusable("Comparing .xlsx files needs openpyxl (pip install openpyxl).")
        diffs = []
        for sheet in sorted(set(ec) | set(ac)):
            if sheet not in ac:
                diffs.append(f"sheet {sheet!r} is missing")
                continue
            if sheet not in ec:
                diffs.append(f"extra sheet {sheet!r}")
                continue
            for k in sorted(set(ec[sheet]) | set(ac[sheet])):
                if ec[sheet].get(k) != ac[sheet].get(k):
                    diffs.append(f"{sheet}!{cell_name(*k)}: expected {ec[sheet].get(k)!r}, got {ac[sheet].get(k)!r}")
        return not diffs, diffs[:SHOW] + ([f"... and {len(diffs) - SHOW} more"] if len(diffs) > SHOW else [])
    eb, ab = e.read_bytes(), a.read_bytes()
    if eb == ab:
        return True, []
    try:
        et = eb.decode("utf-8-sig").replace("\r\n", "\n")
        at = ab.decode("utf-8-sig").replace("\r\n", "\n")
    except UnicodeDecodeError:
        return False, [f"the files differ (binary: {len(eb)} bytes expected, {len(ab)} bytes written)"]
    if et == at:
        return True, []
    diff = list(difflib.unified_diff(et.splitlines(), at.splitlines(), "expected", "written", lineterm="", n=1))
    return False, diff[:SHOW] + ([f"... and {len(diff) - SHOW} more diff lines"] if len(diff) > SHOW else [])


# ---- Commands ------------------------------------------------------
def cmd_run():
    cfg = load_config()
    p = plan(cfg)
    failed = False
    if not p["checks"] and not p["levy"]:
        print("agent-check: checks.toml has no [[check]] commands to run")
    for c in p["checks"]:
        try:
            r = subprocess.run(c["run"], shell=True, capture_output=True, text=True, timeout=c["timeout"],
                               executable="/bin/bash")
            rc, out = r.returncode, (r.stdout + r.stderr).strip().splitlines()
        except subprocess.TimeoutExpired:
            rc, out = 124, [f"(stopped: ran longer than {c['timeout']} seconds)"]
        if rc == 0:
            print(f"pass {c['name']}")
        else:
            failed = True
            print(f"FAIL {c['name']} (exit {rc}): {c['run']}")
            for ln in out[-25:]:
                print(f"  {ln}")
    if p["levy"]:
        lc = Path(__file__).with_name("levy_check.py")
        r = subprocess.run([sys.executable, str(lc), "rules"], capture_output=True, text=True)
        print(r.stdout.rstrip())
        if r.returncode == 2:
            raise Unusable(r.stdout.strip().splitlines()[-1] if r.stdout.strip() else "levy-check failed")
        failed = failed or r.returncode != 0
    return 1 if failed else 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "run"
    if any(a in ("-h", "--help", "help") for a in argv[1:]):
        print(__doc__.strip())
        return 0
    try:
        if cmd == "init":
            if CONFIG.exists():
                print(f"{CONFIG} already exists; not overwriting it.")
                return 2
            CONFIG.parent.mkdir(parents=True, exist_ok=True)
            CONFIG.write_text(TEMPLATE, encoding="utf-8")
            print(f"Wrote {CONFIG}. List your own tests under protect, add [[check]] commands,")
            print("and put known-good examples in .agent-grid/golden/ for [[golden]] tests.")
            return 0
        if cmd == "run":
            return cmd_run()
        if cmd == "plan":
            print(json.dumps(plan(load_config())))
            return 0
        if cmd == "protect":
            print("\n".join(protected(load_config()) if CONFIG.is_file() else ALWAYS))
            return 0
        if cmd == "compare":
            if len(argv) != 4:
                print("Usage: agent-check compare EXPECTED ACTUAL")
                return 2
            ok, lines = compare(argv[2], argv[3])
            print(f"{'match' if ok else 'DIFFERENT'}: {argv[3]} vs {argv[2]}")
            for ln in lines:
                print(f"  {ln}")
            return 0 if ok else 1
        print(__doc__.strip())
        return 2
    except Unusable as e:
        print(f"checks.toml problem: {e}")
        return 2
    except (ValueError, TypeError) as e:
        print(f"checks.toml problem: a setting has the wrong kind of value ({e}).")
        return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except BrokenPipeError:
        sys.exit(0)
