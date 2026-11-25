# Performance of the Jac rewrite

How fast the neojac build of code-review-graph runs next to the Python it replaced, what made it
slower, what was changed on this branch (`neojac-perf`) to close the gap, and what neojac 0.5.1
does not allow yet.

## Setup

- **Original**: the Python package at commit `bbdda4b9e`, run from its checkout
  (`PYTHONPATH=<checkout>`).
- **Jac before**: the build of `neojac-deslop`'s head (`896fb71`), copied aside.
- **Jac after**: the build of this branch (`neojac build pyproject.toml`).
- All three run on the same interpreter, neojac's CPython 3.15.2, with the same dependencies
  (the project's `.jac/venv`: fastmcp 4.1.6, mcp 2.3.0, tree-sitter 0.26.0,
  tree-sitter-language-pack 0.13.0, networkx 3.7), and `PYTHONHASHSEED=0`.
- Input: a Git repository holding a copy of the original's `code_review_graph/` (renamed `crg/`,
  so `python -m code_review_graph` cannot import it from the working directory) and `tests/`
  without fixtures: 404 tracked files, 235,033 lines of Python. A second commit changes two
  functions, for `detect-changes --base HEAD~1`. Read-only commands run all three variants on
  the same graph directory, so absolute paths, and with them set iteration order, are equal.
- Each workload alternates original, Jac before and Jac after, repeated 5 times (3 for `update`,
  7 for the analysis MCP session); the table gives medians. CPU is user+sys of the child processes.
- Outputs are compared after removing timestamps, durations and the input's directory name: every
  workload below gave byte-identical normalised output in all three variants
  (`same_output: true` in every run).
- The machine is shared: an Intel i9-10850K, 20 hardware threads, 62 GB, with other users' jobs
  running throughout. The 1-minute load average during the runs is given with each table; it
  ranged from 8 to 70. Wall times of short commands moved by up to 2x between rounds; the
  ratios between variants within one round, which alternate, are the reliable figures.

The scripts were run from `/home/jayanaka/neojac-deslop/perf/code-review-graph/`, outside the
repository (a `.py` file under the archwire would have to join a space): `bench2.py` (the
workloads), `mcp_client.py` (an MCP stdio client that times each phase and digests each response),
`parse_all.py` (the parser alone), `suite.sh` and `cmpjunit.py` (the test suite in shards, and a
per-test comparison of two runs).

## Results

| Workload | Original | Jac before | Jac after | after / original | after / before | load |
|---|---:|---:|---:|---:|---:|---:|
| `--version` | 0.075 s | 1.151 s | 0.086 s | 1.15x | 0.07x | 11.6 |
| `--help` | 0.085 s | 1.158 s | 0.084 s | 0.99x | 0.07x | 11.1 |
| `status` | 0.142 s | 1.282 s | 0.151 s | 1.06x | 0.12x | 10.9 |
| `search GraphStore` | 0.138 s | 1.233 s | 0.148 s | 1.07x | 0.12x | 11.0 |
| `query importers_of crg/graph.py` | 0.146 s | 1.266 s | 0.148 s | 1.01x | 0.12x | 11.2 |
| `impact --files crg/flows.py` | 0.268 s | 1.498 s | 0.271 s | 1.01x | 0.18x | 11.5 |
| `detect-changes --base HEAD~1` | 0.339 s | 1.635 s | 0.397 s | 1.17x | 0.24x | 11.6 |
| `architecture` | 1.074 s | 2.616 s | 0.337 s | 0.31x | 0.13x | 11.3 |
| `flows --limit 20` | 0.155 s | 1.481 s | 0.167 s | 1.08x | 0.11x | 11.1 |
| `dead-code --limit 50` | 1.013 s | 2.753 s | 1.179 s | 1.16x | 0.43x | 11.7 |
| `large-functions --limit 20` | 0.127 s | 1.110 s | 0.131 s | 1.03x | 0.12x | 10.8 |
| MCP: start, `tools/list`, 6 tool calls | 2.643 s | 3.061 s | 2.036 s | 0.77x | 0.67x | 8.7 |
| MCP: start, hub nodes, surprising connections, knowledge gaps | 5.246 s | 7.128 s | 4.478 s | 0.85x | 0.63x | 13.4 |
| `update` after editing one file | 11.794 s | 20.176 s | 16.496 s | 1.40x | 0.82x | 33.1 |
| `build` (full, 404 files) | 21.883 s | 31.110 s | 29.165 s | 1.33x | 0.94x | 17.1 |
| Parser alone (`CodeParser.parse_bytes` on each file), one process, 404 files, 3 runs | 30.8 s | 57.7 s | 44.4 s | 1.44x | 0.77x | 12-34 |

Wall time, median; "after / before" below 1 is the speed-up this branch made. CPU time (user+sys)
tracks wall time within a few percent for every single-process workload; `update` and `build`
parse in worker processes, and their wall time includes waiting for SQLite's writes, which moved
with the load. The load column is the median 1-minute load average while that row ran.

**A later round on a quiet machine** (load 6-9), with commit 7 (`b3d3b89`) in the after build:

| Workload | Original | Jac before | Jac after | after / original | after / before |
|---|---:|---:|---:|---:|---:|
| `build` (full, 404 files), 5 runs | 20.6 s | 35.3 s | 27.1 s | 1.32x | 0.77x |
| `update` after editing one file, 5 runs | 9.2 s | 14.6 s | 11.8 s | 1.27x | 0.80x |
| Parser alone, 404 files, 3 runs | 24.3 s | | 33.2 s | 1.37x | |

Run of the parser with `held` replaced by an identity function in the process (an experiment to
size blocker 1, not shipped): 30.2 s, the original's time.

**Test suite.** `pytest` over the 297 test modules in 10 parallel shards (pytest-xdist crashes on
neojac's CPython 3.15, so the shards are separate processes), on neojac's test tree (the repository
without `code_review_graph/`, as `neojac test` runs it), one run per build:

| Run | Load | Sum of shard times | Longest shard (wall) | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|---:|---:|
| Original, round 1 | 20-70 | 4722 s | 1135 s | 8243 | 3 | 1003 |
| Original, round 2 | 11-16 | 4530 s | 967 s | 8242 | 4 | 1003 |
| Jac before | 9-18 | 4558 s | 994 s | 8206 | 31 | 930 |
| Jac after commit 1 only | 20-38 | 4452 s | 923 s | 8202 | 35 | 930 |
| Jac after commit 2 (`0e99681`) | 17-30 | 4537 s | 1048 s | 8208 | 29 | 930 |
| Jac after (final) | 15-28 | 5242 s | 1074 s | 8207 | 30 | 930 |
| Jac after commit 7 (`b3d3b89`) | 9-24 | 4731 s | 1035 s | 8209 | 29 | 930 |

The suite takes the same time within the machine's noise: it is bound by its slowest tests (real
Git repositories, subprocesses, watchers), not by the package's code. The Jac runs collect 82 fewer
tests and fail 26 more, the same ones before and after this branch: tests that read the package's
own `.py` sources or need the neojac project (`test_e2e_real_repo`, `test_import_target_integrity`,
`test_utf8_encoding`, source checks in `test_main`, `test_main_lazy_tool_imports`,
`test_tool_suggestion_names`), which neojac's test tree leaves out by construction; the two
`test_doctor` checks that run Python with `-I` (which drops `PYTHONPATH`); and timing-dependent
watcher tests in `test_watch_robustness::TestRealObserver`, which fail in a different 1-4 of 7 on
every run of every build under this load. Comparing the final before and after runs test by test,
the only difference is one of those watcher tests. The first version of commit 1 broke six tests
that patch `code_review_graph.graph.GraphStore` (blocker 2); the committed version passes them.

## What made the difference

Where each part runs: the archwire declares two `cpython` spaces (`code_review_graph`, the
shipped package, and `code_review_graph_dev`, its tests and scripts) and one `node` space (the
VS Code extension, still TypeScript and not benchmarked here). There is no `native` space, so none
of the package is machine code; it is Jac lowered to Python and run on CPython. The dev space
imports the package in its own process, so there are no crossings between spaces at run time:
every cost below is in the Python the cpython space emits.

Seven commits, in order of effect:

1. **Start-up: import modules where they are used** (`266388e`). The rewrite fetched other
   modules through a helper, `lazy("skills", "PLATFORMS")`, but every name it fetched also had a
   wire in `archwire.jac`, and the emitter imports a wire's provider at the top of the consumer.
   So `cli` imported every module of the package, `main` and with it fastmcp and the MCP SDK
   among them, before it read its arguments: `code-review-graph --version` took 1.3-1.4 s against
   the original's 0.08 s, and every command paid it. The 301 `lazy()` calls became imports in the
   function bodies (`import from code_review_graph.skills { PLATFORMS }`), which the wires admit
   and which run where the function runs, as the original's did. Where a module already binds the
   same name at its top, such a body import reuses that binding instead of reading the provider
   again (blocker 2), which would miss a test's `patch("code_review_graph.graph.GraphStore")`;
   those 11 sites import the module and read the attribute (`_graph.GraphStore(...)`) instead.
   `globals()` in a module with body imports is refused (blocker 5), so five lazy-attribute caches
   use `vars(sys.modules[__name__])`, the same dict. `_lazy.jac` is gone.
2. **Edges read by three columns** (`0e99681`). `get_architecture_overview`, `find_hub_nodes`,
   `find_surprising_connections` and the suggested-questions test check built a `GraphEdge` for
   each of the 124,000 rows of the edge table, decoding each row's JSON `extra`, and then read
   `kind`, `source_qualified` and `target_qualified`. In the cpython space each field read off a
   Python object costs a runtime call (blocker 1), so this was 1.5 million calls. A new
   `GraphStore.iter_edge_kinds_and_ends()` selects the three columns `ORDER BY rowid`, the order
   `SELECT *` returns, so the results are identical. `architecture` and the MCP session that ends
   with `get_architecture_overview_tool` became faster than the original.
3. **`find_dead_code`'s member-call scan** (`98185ef`). The port declares a function's loop
   variables `any` at its top; one of them, `end`, was then a slice bound inside a generator, and
   each slice converted it to `int` through the runtime: 0.97 million conversions per run. A loop
   variable of its own and a plain loop leave one conversion per `.`.
4. **Parser: type sets made once** (`763a7c9`). `_extract_from_tree`, run for every syntax node,
   rebuilt four sets from the parser's type tables each call (eight runtime-wrapped reads and four
   set constructions). The tables are fixed when the parser is made; the sets are now made once per
   language.
5. **Parser: one read of `node.type`** (`720b843`, `e685fa1`). The five hottest tree walks read
   `node.type` up to seven times per node, each through the runtime; they read it once.
   `_extract_value_references`, also run for every node, qualified the caller's name before
   learning that no branch would use it; it now returns first when none applies.
6. **Parser: the depth limit and the value-reference gate** (`b3d3b89`). Thirteen nested tree
   walks read `self._MAX_AST_DEPTH` for every node; the enclosing method reads it once and the
   walk uses the local. The early return of `_extract_value_references` read three class
   attributes per node; it checks a module-level set of the same types, which a new test
   (`tests/test_value_reference_gate.py`) keeps equal to them. 120-file parse: 15.5 s to 14.7 s.

Every commit kept the full test suite at the original's results, apart from tests that cannot run
in neojac's test tree (above), and every workload's output identical.

## Where the Jac is still slower, and why

The parser is the one workload still well behind the original: parsing the 404 files in one
process takes 1.37-1.44x the original's time (it was 1.87x), and `build` and `update`, which parse in
worker processes, move with it. The profile names the cause: on 60 files the parser makes 16
million calls to the runtime's `held()` (counted after commit 4), one for every attribute read,
subscript and call result of a Python object (here a tree-sitter `Node`), and `held()` costs about
3x a plain Python call because it checks `isinstance(v, (Struct, Array))` and `Struct`'s metaclass
sends that down CPython's slow path. Replacing `held` with an identity function in the process (an
experiment, not shipped) brings the 404-file parse from 44.4 s to 30.2 s, the original's 30.8 s:
the remaining gap is that one runtime function. The rest is the `bool()` and `convert()` the emitter
adds because every annotation in a module with `from __future__ import annotations` is `any`
(blocker 3).

`dead-code` is the other command still measurably slower (1.16x in the final round, 1.5x in
noisier earlier ones): `find_dead_code` makes 0.88 million `held()` calls, about eight per edge row
of its scan, from `index.setdefault(key, set()).add(value)` chains on dictionaries the checker
reads as `any`; `_row_to_node` adds 0.24 million (15 per SQLite row). `detect-changes` (1.17x)
has the same cause: of its 0.25 million `held()` calls, 0.12 million are in `_row_to_node`. Only a
cheaper `held` (blocker 1) or annotations the checker can use (blocker 3) would remove them. The short commands are within 0-17% of the original:
the package's start-up, now importing what the original imports, plus the emitted modules' own
set-up (the runtime module `_jac_code_review_graph` and each module's `__jac_init__`): about
10 ms, the difference in `--version`.

What was tried and dropped:

- **Typed annotations** (removing `from __future__ import annotations` from `refactor.jac`): the
  emitted code lost most of its `held()` and `bool()` calls, but builtin methods then check their
  arguments at run time with Jac's signatures, and `names.update(re.findall(...))` raised
  `TypeError: expected set, found list` where Python accepts any iterable. The checker cannot see
  this because the argument is `any`. 39 tests failed; the change was reverted (blocker 3).
- **`NodeInfo`/`EdgeInfo` as Jac `obj`s** instead of `@dataclass` classes: their field reads
  would lose `held()`, but constructing a Jac `obj` in a cpython space takes 10.6 us against the
  dataclass's 1.3 us, and the parser makes one per node and edge (blocker 7).
- **A native extension** for counts like the community cohesion and degree loops, tried in a
  scratch project: neojac builds one from a Jac module (`[extensions."pkg/_fast"] jac = "..."`),
  imported by the cpython package, and it computes 19x faster than Python,
  but every argument crosses element by element (blocker 6): counting internal edges over 50,000
  string pairs took 114 ms against Python's 2.9 ms. Every hot path in this package moves strings
  and graph rows, not numbers, so nothing was moved to native code.

## Blockers in neojac 0.5.1

Each has a minimal reproduction: a project made of `jac.toml`, an `archwire.jac` with one
`cpython` space `pkg`, and the files shown, built with `neojac build pyproject.toml`
(neojac 0.5.1, linux-x86_64).

**1. `_jac.held()` on every read of a Python value is slow.** Every attribute read, subscript and
call result whose type is a Python class or `any` is wrapped in `held(v)`, which is
`box(v) if isinstance(v, (Struct, Array)) else v`. `Struct` has the metaclass `JacType`, so the
`isinstance` takes CPython's slow path even for a `str` (the runtime module is named after the
project; here this repository's):

```sh
PY=.jac/venv/bin/python; export PYTHONPATH=.jac/build/pypi/top/site
$PY -m timeit -s "import _jac_code_review_graph as j; S=j.Struct; A=j.Array; x='a'" "isinstance(x, A)"       # 36 ns
$PY -m timeit -s "import _jac_code_review_graph as j; S=j.Struct; A=j.Array; x='a'" "isinstance(x, S)"       # 73 ns
$PY -m timeit -s "import _jac_code_review_graph as j; S=j.Struct; A=j.Array; x='a'" "isinstance(x, (S, A))"  # 123 ns
```

```jac
def a(x: any) -> int {
    n = 0;
    for c in x.children { n += c.size(); }
    return n;
}
```

emits `for c in _jac.held(x.children): n += _jac.held(c.size())`. It is the largest cost left in
the parser (above). The project cannot avoid it: a Python class as the declared type (`p: Path`)
is wrapped too, and there is no option for a space that declares no structs. A cheaper `held`
(a per-type cache, or a check that skips the metaclass) would recover the parser's gap: with an
identity `held` the parser runs in the original's time (above).

**2. A body import of a name the module also binds at its top does not read it again.**
`pkg/a.jac`: `def make -> str { return "real"; }`. Wire `pkg.a ++> pkg.b { make }`. `pkg/b.jac`:

```jac
glob DEFAULT: any = make;

def fresh -> str {
    import from pkg.a { make }
    return make();
}
```

```sh
$PY -c "import pkg.a, pkg.b; pkg.a.make = lambda: 'patched'; print(pkg.b.fresh())"   # real
```

Python's `from pkg.a import make` in the function prints `patched`. The emitted body is
`_jac.start('pkg.a'); return make()`, the module-level binding. Tests that patch a provider
(`patch("code_review_graph.graph.GraphStore")`) depend on the fresh read; the workaround is
`import pkg.a as a_mod;` and `a_mod.make()`.

**3. `from __future__ import annotations` makes every annotation `any`; removing it makes builtin
methods strict at run time.** `neojac port` keeps the future import, so 89 of the 94 modules
have it and the emitter adds `held()`, `bool()` and `convert()` throughout:

```jac
import from __future__ { annotations }
def lowered(text: str) -> str { return text.lower(); }      # return _jac.held(text.lower())
```

Without it the same function emits `return text.lower()`. But then:

```jac
import re;
def words(text: any) -> set[str] {
    names: set[str] = set();
    names.update(re.findall("[A-Z]\\w*", text));
    return names;
}
```

builds without a diagnostic and raises `TypeError: expected set, found list` at run time
(`names.update(_jac.convert(re.findall(...), (set, str)))`), where Python's `set.update` takes any
iterable. A port cannot drop the future import without auditing every call of a builtin method
whose argument is `any`.

**4. A loop variable captured by a generator is used as an unwrapped `Cell` in a slice.**

```jac
def g(w: str, cn: set[str]) -> set[str] {
    out: set[str] = set();
    for (end, ch) in enumerate(w) {
        if ch == "." {
            out.update(set(w[s:end] for s in range(max(0, end - 3), end) if w[s:end] in cn));
        }
    }
    return out;
}
```

emits `w[s:end]` where `end` is a `_jac.Cell`, while the `range` beside it reads `end.v`:
`g("ab.cd", {"ab"})` raises `TypeError: slice indices must be integers or have an __index__
method`. The port's form (`end: any` declared at the top) avoids the cell but converts `end` on
every slice.

**5. `globals()` in a module with a body import is E2240.**

```jac
def cached -> any {
    import from pkg.a { make }
    return make;
}

def names -> list[str] {
    return sorted(globals());
}
```

`error[E2240]: 'make' is brought into 'pkg.b' by an import in a code body, which starts its module
where it runs: use it after that import, in its body`, pointing at `globals()`.
`vars(sys.modules[__name__])` is accepted and is the same dict. Related: a body import whose alias
differs from the module's existing wire (`import code_review_graph.parser as _parser;` where the
wire says `as parser_mod`) is reported as `W2001 unknown name '_parser'` at its uses, not as E2094
with the wire to add; and E2094's message for a method names the whole chain of the class's methods
(several kilobytes) as the function.

**6. A native extension module pays per element at the crossing.** With
`[extensions."pkg/_fast"] jac = "native/fast.jac"`:

```jac
def count_internal(members: list[str], edges: list[tuple[str, str]]) -> int { ... }
def spin(n: int) -> int { ... }
def take_list(xs: list[str]) -> int { return len(xs); }
```

`spin(1_000_000)`: 8 ms native, 155 ms Python. `take_list` of 40,000 strings: 24 ms (600 ns per
element), and an empty call 14.5 us. `count_internal` over 50,000 pairs: 114 ms native, 2.9 ms
Python. There is no way to hand a native module a Python list or dict without converting it, so
code that works on strings and rows gets slower when moved.

**7. Constructing a Jac `obj` in a cpython space is 8x a dataclass.** An `obj` with six fields and
a `postinit`: 10.6 us per construction, against 1.3 us for the equivalent `@dataclass` with
`__post_init__`, because `JacObj`'s `init` is generic Python over `__jac_fields__`.

**8. Smaller limits met on the way.** `neojac build pyproject.toml --release` is refused
(`--release is an option of a program's build, and this is a Python project's wheel`), so there is
no build of a cpython space that could leave out the run-time checks;
`yield from` is not Jac syntax; a docstring as a method body's first statement is E0002
"missing ';'".
