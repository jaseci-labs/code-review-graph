"""CLI entry point for the crg-daemon multi-repo watcher.

Usage:
    crg-daemon start [--foreground]
    crg-daemon stop
    crg-daemon restart [--foreground]
    crg-daemon status
    crg-daemon logs [--repo ALIAS] [--follow] [--lines N]
    crg-daemon add <path> [--alias ALIAS]
    crg-daemon remove <path_or_alias>
"""

import operator;

import from __future__ { annotations }

import argparse;

import logging;

import os;

import signal;

import subprocess;

import sys;

import time;

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Windows reports a vanished PID as ERROR_INVALID_PARAMETER (87)."""
def _process_already_gone(error: OSError) -> bool;

"""Start the daemon process."""
def _handle_start(args: argparse.Namespace) -> None;

"""Stop the running daemon process, and anything it left behind."""
def _handle_stop(_args: argparse.Namespace) -> None;

"""Finish what a daemon that was killed could not.

    The daemon terminates its own children on SIGTERM, but one that had to be
    SIGKILLed did not get the chance, and on Windows ``os.kill`` is always
    ``TerminateProcess``, so its shutdown code never runs at all.
    """
def _reap_watchers_left_behind -> None;

"""Restart the daemon (stop + start)."""
def _handle_restart(args: argparse.Namespace) -> None;

"""Render an age in seconds compactly: ``12s``, ``4m``, ``3h``, ``2d``."""
def _format_age(seconds: float | None) -> str;

"""Show daemon status and configuration."""
def _handle_status(_args: argparse.Namespace) -> None;

"""Show daemon or per-repo log files."""
def _handle_logs(args: argparse.Namespace) -> None;

"""Add a repository to the daemon config."""
def _handle_add(args: argparse.Namespace) -> None;

"""Remove a repository from the daemon config."""
def _handle_remove(args: argparse.Namespace) -> None;

"""Entry point for the crg-daemon CLI."""
def main -> None;

with entry:__main__ {
    main();
}
