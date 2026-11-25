import from __future__ { annotations }

import importlib, operator, json, sqlite3, subprocess, sys;

import from pathlib { Path }

import from typing { Any }

glob _FILE_PATH_KEYS: any = ("file_path", "notebook_path");

def _payload_cwd(payload: Any) -> Path | None;
def _payload_file(payload: Any, cwd: Path | None) -> Path | None;

def _git(directory: Path, *args_: str) -> str | None;
def _toplevel(directory: Path) -> Path | None;
def _superproject(repo_root: Path) -> Path | None;
def _recorded_root(db_path: Path) -> Path | None;
def _has_graph(repo_root: Path) -> bool;
def _existing_dir(path: Path) -> Path | None;
def _repo_for_file(path: Path, session_repo: Path | None, existing_only: bool = False) -> Path
    | None;
def _read_payload -> Any;

def _session_repo(payload: Any) -> Path | None;
def _hook_repo -> Path | None;
def _update_target(payload: Any, existing_only: bool = False) -> Path | None;
def run_update_hook(existing_only: bool = False);

def _update_repo(repo_root: Path);
def run_status_hook;
