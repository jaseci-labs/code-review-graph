"""Post-build Spring AOP advice-to-target call resolver.

Tree-sitter parsing sees a ``@Before``/``@Around``/... advice method inside an
``@Aspect`` class and the business methods it intercepts as two unrelated
methods — there is no ``CALLS`` edge between them, because the interception
happens through a Spring AOP proxy at runtime, not through a static method
call in the advice's source text.  This module approximates that missing
edge by reading the pointcut expression each advice annotation carries
(already captured verbatim in ``extra["decorators"]`` by the parser) and
matching it against candidate target methods already in the graph.

Resolution chain:
    ``@Aspect`` class
        → ``@Pointcut``/``@Before``/``@After``/``@Around``/``@AfterReturning``/
          ``@AfterThrowing`` methods inside it
        → pointcut expression (inline, or via a same-class named
          ``@Pointcut`` reference)
        → candidate target methods matched against that expression
        → ``CALLS`` edge, advice → target, tagged ``extra.aop_resolved``

Scope (see issue #592 — Option 1, regex-based approximation):

* ``@annotation(some.pkg.Foo)`` pointcuts are matched by simple annotation
  name (``Foo``) against ``extra["decorators"]`` on the candidate method
  itself. This is exact enough for the common case, but two same-named
  annotations in different packages are indistinguishable — a known
  approximation, consistent with the rest of Option 1. A *class-level*
  ``extra["spring_annotations"]`` match (e.g. a class-level
  ``@Transactional``) is intentionally **not** expanded to every method in
  that class — that is ``@within()`` semantics, a different pointcut
  designator, and conflating the two produced widespread false positives
  on common class-level stereotype annotations (see PR #916 review).
* ``execution(...)`` pointcuts are matched segment by segment against the
  full ``package.ClassName.methodName`` portion of a candidate — the
  return-type pattern and parameter pattern (``(..)``) are discarded, but
  the declaring-type pattern (package included) is matched in full against
  each candidate's resolved Java package (``extra["java_package"]``, set at
  parse time from the file's ``package`` declaration — see
  ``_extract_classes`` in ``parser.py``) joined with its class and method
  name.  A candidate in Java's default (unnamed) package has no
  ``java_package`` and is matched using the bare ``ClassName.methodName``,
  so a pointcut that names a package never matches a default-package class.
  A declaring type of exactly ``*`` (``execution(* *.*(..))``) means any
  type in any package, as in AspectJ.
  This is still an approximation of full AspectJ semantics (no
  supertype/interface expansion, no ``+`` subtype matching) and can produce
  false positives/negatives on those axes — see issue #592 — but no longer
  discards package selectivity: two same-named classes in different
  packages are no longer conflated (see PR #916 review).
* Pointcut expressions combining multiple sub-expressions with ``&&`` or
  ``||`` are compound boolean pointcuts and are skipped entirely rather
  than partially parsed, to avoid emitting a wrong edge. This check also
  applies to the expression a same-class named ``@Pointcut`` reference
  resolves to, not just the reference text itself. A bare ``!`` negation
  is not recognized by either pointcut-kind matcher below, so it is
  skipped too — just by falling through unparsed rather than via an
  explicit compound-operator check.
* Constructors (``extra["java_constructor"]``), test methods and methods of
  ``@Aspect`` classes are never targets: Spring AOP proxies method calls on
  beans, does not auto-proxy aspects, and tests run outside the proxy.
* Advice whose pointcut is not one complete string literal (a constant, or
  literals joined with ``+``) is skipped rather than partially resolved.
* Annotations are compared by simple name, so a fully qualified method or
  advice annotation (``@com.acme.Audited``, ``@org.aspectj.lang.annotation.Before``)
  matches. A fully qualified *class-level* ``@org.aspectj.lang.annotation.Aspect``
  is still not recognized: aspects are found through
  ``extra["spring_annotations"]``, which ``_get_java_annotations`` in
  ``parser.py`` fills with simple-name annotations only. Changing that would
  alter Spring stereotype detection as a whole, so it is left for a separate
  change.
* ``within(Type+)``, ``args()``/``target()``/``this()``, and named pointcut
  references that cross an ``@Aspect`` class boundary are out of scope for
  this pass (see the narrower AOP ``LanguageGap`` note in
  ``uncertainty.py``) and are left for a future PR.

Reuses the existing ``CALLS`` edge kind rather than introducing a new one,
so advice→target edges are automatically picked up by ``callers_of``,
``callees_of``, and ``get_impact_radius`` without touching their edge-kind
allowlists. Two dedicated query patterns, ``advises`` and ``advised_by``,
filter this same data down to only the ``extra.aop_resolved`` edges — use
those when the goal is specifically "what AOP relationships exist here"
rather than every caller/callee regardless of provenance.

Edge *direction* for impact analysis is the one place these edges do not
follow the plain ``CALLS`` policy. ``CALLS`` propagates target→source
(changing a callee impacts its callers), but an advice does not get called
by the method it wraps — plain propagation would report "change the
target, the aspect is impacted" and miss the relationship that actually
matters: "change the advice (its logic runs around every target), what
does that impact". ``graph.py``'s impact-radius traversal (both the SQL and
NetworkX engines) special-cases any edge carrying ``extra.aop_resolved`` to
always propagate source→target (advice → its targets), overriding
``IMPACT_EDGE_DIRECTIONS["CALLS"]`` for just these edges — see PR #916
review. ``callers_of``/``callees_of``/``advises``/``advised_by`` are plain
graph traversal, not impact analysis, and are unaffected by this override.
"""

import builtins;

import operator;

import from __future__ { annotations }

import json;

import logging;

import re;

import from typing { TYPE_CHECKING, Optional }

glob logger: any;

glob _ADVICE_ANNOTATIONS: any;

glob _COMPOUND_OPERATORS: any;

glob _NAMED_POINTCUT_REF: any;

glob _ANNOTATION_POINTCUT: any;

glob _EXECUTION_POINTCUT: any;

glob _DESIGNATOR_PREFIX: any;

glob _DERIVED_FLAG: any;

with entry {
    logger = logging.getLogger(__name__);

    _ADVICE_ANNOTATIONS = frozenset({
        "Before",
        "After",
        "Around",
        "AfterReturning",
        "AfterThrowing",
    });
    _COMPOUND_OPERATORS = ("&&", "||");
    _NAMED_POINTCUT_REF = re.compile("^\\s*([A-Za-z_][A-Za-z0-9_]*)\\(\\s*\\)\\s*$");
    _ANNOTATION_POINTCUT = re.compile("^\\s*@annotation\\s*\\((.+)\\)\\s*$", re.DOTALL);
    _EXECUTION_POINTCUT = re.compile("^\\s*execution\\s*\\((.*)\\)\\s*$", re.DOTALL);
    _DESIGNATOR_PREFIX = re.compile(
        "^\\s*(?:execution|@annotation|within|args|target|this)\\s*\\("
    );

    _DERIVED_FLAG = "aop_resolved";
}

"""Return the pointcut expression embedded in an advice annotation's raw text.

    Handles the common positional form (``@Before("expr")``) as well as
    named-argument forms (``@AfterThrowing(pointcut = "expr", throwing =
    "ex")`` / ``value = "expr"``). Returns ``None`` when no string literal
    argument can be found, or when literals are joined with ``+``: reading only
    the first would drop whatever the rest adds, such as a ``&&``.
    """
def _extract_annotation_string_arg(deco_text: str) -> Optional[str];

"""Return the simple annotation name from a raw decorator string.

    Arguments and any package qualifier are dropped, so ``com.acme.Audited``
    and ``Audited`` compare equal.
    """
def _annotation_head(deco_text: str) -> str;

"""Match one segment where ``*`` means any characters, without backtracking."""
def _glob_matches(pattern: str, text: str) -> bool;

"""An AspectJ-style dotted wildcard pattern, matched one segment at a time.

    Rules (approximate — see module docstring for the scope this is applied
    within):

    * ``..`` means "any number of intervening whole segments", zero included
    * a lone ``.`` separates two segments
    * ``*`` within a segment means "any characters but a dot"
    * every other character is matched literally

    The pattern text comes from the repository being indexed, and a regex over
    repeated ``..*`` or ``*a*a`` backtracks catastrophically, so no regex is
    built, not even for one segment. Tracking the reachable positions keeps
    this polynomial on any input.
    """
obj _DottedPattern {
    has _parts: any;

    def init(pattern: str, any_package_prefix: bool = False);

    def `match(subject: str) -> bool;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Reduce an ``execution(...)`` pointcut expression to a (pattern, needs_class) pair.

    ``needs_class`` is True when the expression's method-pattern token
    included a declaring-type segment (e.g. ``com.foo.*.*``), so the pattern
    must be matched against the candidate's full ``package.ClassName.methodName``
    (see ``resolve_aop_advice``); it is False for a method-name-only pattern
    (e.g. ``*get*Index``), matched against the bare method name.  The full
    declaring-type+method pattern is kept, package included — no segments are
    dropped, so an explicit package qualifier in the pointcut stays selective
    (see module docstring).  Returns ``None`` when the expression cannot be
    safely reduced (e.g. no parameter-pattern parens found).
    """
def _parse_execution_expression(expr: str) -> Optional[tuple[_DottedPattern, bool]];

"""Follow a same-class named ``@Pointcut`` reference to its expression.

    Returns the expression to actually parse (``expr`` itself when it is
    already an inline expression), or ``None`` when ``expr`` is a
    cross-aspect reference, an unresolvable reference, or a compound boolean
    expression — all out of scope for this pass. The compound check is
    applied both to ``expr`` and, when ``expr`` is a named reference, to the
    ``@Pointcut`` body it resolves to — a bare reference like
    ``"myPointcut()"`` carries no ``&&``/``||`` itself even when the
    pointcut it names does.
    """
def _resolve_pointcut_expr(expr: str, pointcuts: dict[str, str]) -> Optional[str];

def _load_extra(raw: Optional[str]) -> dict;

"""Resolve Spring AOP advice methods to the target methods their pointcut matches.

    Safe to call multiple times: previously derived edges (tagged
    ``extra.aop_resolved``) are cleared and rebuilt on every call, so a
    changed or removed pointcut cannot leave a stale edge behind.

    Returns a dict with resolution counts for telemetry.
    """
def resolve_aop_advice(store: "GraphStore") -> dict;
