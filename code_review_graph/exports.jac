import from __future__ { annotations }

import builtins;

import html;

import json;

import logging;

import os;

import re;

import tempfile;

import from pathlib { Path }

glob logger: any;

glob GRAPHML_NS: any;

glob GRAPHML_SCHEMA: any;

glob _XML_ILLEGAL: any;

with entry {
    logger = logging.getLogger(__name__);
}

obj MissingOptionalDependencyError(ImportError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def export_json(store: GraphStore, output_path: Path) -> Path;

with entry {
    GRAPHML_NS = "http://graphml.graphdrawing.org/xmlns";
    GRAPHML_SCHEMA = "http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd";
    _XML_ILLEGAL = re.compile("[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]");
}

def _xml_text(value: object) -> str;
def export_graphml(store: GraphStore, output_path: Path) -> Path;
def export_neo4j_cypher(store: GraphStore, output_path: Path) -> Path;
def _cypher_escape(s: str) -> str;
def _cypher_props(d: dict) -> str;
def export_obsidian_vault(store: GraphStore, output_dir: Path) -> Path;
def _yaml_scalar(value: object) -> str;
def _obsidian_slug(name: str) -> str;
def _obsidian_slugs(nodes: list[dict]) -> dict[str, str];
def export_svg(store: GraphStore, output_path: Path) -> Path;
