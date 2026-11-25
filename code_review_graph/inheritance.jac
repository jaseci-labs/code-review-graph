"""Which class a name means, and which ancestor declares an inherited method.

``this.handle()`` in ``Leaf`` runs ``Alpha.handle`` when ``Leaf extends Alpha``
and only ``Alpha`` declares ``handle``. The parser reads one file, so it writes
``<leaf file>::Leaf.handle``, which names no node, and ``callers_of`` on
``Alpha.handle`` finds nothing. The same goes for ``pet.getName()`` when
``getName`` is declared on ``Pet``'s base class. See: #984

This index answers both questions from the stored graph:

* A class is known by its qualified name, never by its short name alone. Two
  files may each declare a ``Widget``.
* A name in an ``extends`` clause, or a declared receiver type, means a class
  only when the file says which one: the same file, a file it imports, a Java
  ``java_type`` or same-package class, or a PHP class in the same namespace.
* An inherited method is the nearest one up the superclass chain. Where a class
  has more than one parent that could hold code (Python), it must be the only
  declaration among all ancestors, so no lookup order can pick another. A
  parent the graph cannot name stops the walk, because it may declare the
  method itself.

Contributed in idea by #1036 (Anthony Ala).
"""

import builtins;

import operator;

import from __future__ { annotations }

import json;

import sqlite3;

import from typing { Optional }

glob _SINGLE_SUPERCLASS: any;

glob _MAX_DEPTH: any;

with entry {
    _SINGLE_SUPERCLASS = frozenset({"java", "csharp", "typescript", "tsx", "javascript", "php"});
    _MAX_DEPTH = 32;
}

def _load_extra(raw: Optional[str]) -> dict;

"""Does this Class node hold no code a subclass inherits through extends?"""
def _is_interface(language: str, extra: dict) -> bool;

"""``Base<T>`` -> ``Base``; ``Foo[]`` -> ``Foo``; whitespace trimmed."""
def _strip_type(raw: str) -> str;

"""Class identities, their parents and their methods, read once from a graph.

    ``import_targets`` maps each file to the files it imports, as
    ``GraphStore._import_evidence`` builds it. ``raw_imports`` maps a file to
    the imports that name no file, short name to full name: a Java test under
    ``src/test`` imports ``org.acme.owner.Owner`` that way. The full name finds
    the class, or shows it comes from outside the graph, so a same-package class
    with that short name is not mistaken for it.
    """
obj InheritanceIndex {
    has _imports: any,
        _raw_imports: any,
        _classes: any,
        _by_name: any,
        _java_fqcn: any,
        _java_package: any,
        _php_namespaces: any,
        _php_fqn: any,
        _methods: any,
        _raw_parents: any,
        _parents: any,
        _inherited: any;

    def init(
        conn: sqlite3.Connection,
        import_targets: dict[str, set[str]],
        raw_imports: dict[str, dict[str, str]],
    );

    def is_class(qualified_name: str) -> bool;

    def has_parents(qualified_name: str) -> bool;

    """The package a Java file declares, as the parser recorded it."""
    def java_package(file_path: str) -> Optional[str];

    """The method *class_name* declares itself, if any."""
    def method_of(class_name: str, method: str) -> Optional[str];

    """The one class *raw* can mean when written in *context_file*.

        None when the file gives no evidence, when two classes fit, or when the
        name comes from outside the graph.
        """
    def resolve_type(raw: str, context_file: str, language: str) -> Optional[str];

    """The ancestor method a call to *method* on *class_name* runs, if sure.

        The class itself is not consulted: callers check ``method_of`` first.
        """
    def inherited_method(class_name: str, method: str) -> Optional[str];

    static def _only(candidates: list[str]) -> Optional[str];

    def _resolve_parent(child: str, raw: str, extra: dict) -> Optional[str];

    """(parents that can hold inherited code, whether any parent is unknown)."""
    def _parents_of(class_name: str) -> tuple[list[str], bool];

    def _walk(class_name: str, method: str) -> Optional[str];

    """The one ancestor declaring *method*, when every ancestor is known."""
    def _only_declaration(class_name: str, method: str) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
