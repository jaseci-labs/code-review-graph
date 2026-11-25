import from __future__ { annotations }

import csv;

import from pathlib { Path }

import from typing { Any }
def generate_markdown_report(results: list[dict[str, Any]]) -> str;
def _newest_runs(results_dir: Path, prefix: str) -> list[Path];
def _read_csvs(results_dir: Path, prefix: str) -> list[dict[str, str]];
def _md_table(headers: list[str], rows: list[list[str]]) -> str;
def generate_full_report(results_dir: str | Path) -> str;
def generate_readme_tables(results_dir: str | Path) -> str;
