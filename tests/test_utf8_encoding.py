"""#926 - file readers must decode as UTF-8 regardless of system locale."""

from pathlib import Path

from tests._project import python_source


class TestUtf8Encoding:
    def _check_encoding(self, filepath):
        source = Path(filepath).read_text(encoding="utf-8")
        return source

    def test_review_reads_utf8(self):
        import inspect

        import code_review_graph.tools.review

        source = python_source(code_review_graph.tools.review)
        assert 'read_text(encoding="utf-8"' in source

    def test_flows_tools_reads_utf8(self):
        import inspect

        import code_review_graph.tools.flows_tools

        source = python_source(code_review_graph.tools.flows_tools)
        assert 'read_text(encoding="utf-8"' in source

    def test_eval_runner_opens_utf8(self):
        import inspect

        import code_review_graph.eval.runner

        source = python_source(code_review_graph.eval.runner)
        assert 'encoding="utf-8"' in source

    def test_eval_reporter_opens_utf8(self):
        import inspect

        import code_review_graph.eval.reporter

        source = python_source(code_review_graph.eval.reporter)
        assert 'encoding="utf-8"' in source
