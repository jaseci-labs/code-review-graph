"""_extract_value_references returns early unless a node's type is in _VALUE_REFERENCE_TYPES,
which must list exactly the types its branches handle (neojac-perf)."""

from code_review_graph.parser import _VALUE_REFERENCE_TYPES, CodeParser


def test_gate_lists_exactly_the_handled_types():
    assert _VALUE_REFERENCE_TYPES == (
        CodeParser._PAIR_TYPES
        | CodeParser._ARRAY_TYPES
        | CodeParser._ARGUMENTS_TYPES
        | {"assignment_expression", "augmented_assignment", "assignment"}
    )
