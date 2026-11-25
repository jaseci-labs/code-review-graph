import from __future__ { annotations }

import importlib, operator, argparse, logging, os, signal, subprocess, sys, time;

glob logger: any = logging.getLogger(__name__);

def _process_already_gone(error: OSError) -> bool;
def _handle_start(args: argparse.Namespace);
def _handle_stop(_args: argparse.Namespace);
def _reap_watchers_left_behind;
def _handle_restart(args: argparse.Namespace);
def _format_age(seconds: float | None) -> str;
def _handle_status(_args: argparse.Namespace);
def _handle_logs(args: argparse.Namespace);
def _handle_add(args: argparse.Namespace);
def _handle_remove(args: argparse.Namespace);
def main;

with entry:__main__ {
    main();
}
