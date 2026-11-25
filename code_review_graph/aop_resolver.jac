import from __future__ { annotations }

import builtins;

import operator;

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

def _extract_annotation_string_arg(deco_text: str) -> Optional[str];
def _annotation_head(deco_text: str) -> str;
def _glob_matches(pattern: str, text: str) -> bool;

obj _DottedPattern {
    has _parts: any;

    def init(pattern: str, any_package_prefix: bool = False);

    def `match(subject: str) -> bool;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _parse_execution_expression(expr: str) -> Optional[tuple[_DottedPattern, bool]];
def _resolve_pointcut_expr(expr: str, pointcuts: dict[str, str]) -> Optional[str];

def _load_extra(raw: Optional[str]) -> dict;
def resolve_aop_advice(store: "GraphStore") -> dict;
