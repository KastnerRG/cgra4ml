#!/usr/bin/env bash
##############################################################################
# Script    : xrun_auto.sh
# Purpose   : Run DeepSoCFlow simulation via xrun
##############################################################################
#
# First-time setup (run once from the repo root):
#   pip install .
#   mkdir -p run/work
#   cd run/work
#   python ../example.py
#
# Subsequent runs (from the repo root):
#   pip install .
#   cd run/work
#   python ../example.py
#
# This script automates the above — invoke it from the scripts folder:
#   bash xrun_auto.sh
# It navigates to the repo root, runs the simulation, then returns here
# so you can invoke xrun_auto.sh again without changing directory.
#
##############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR/../../../../"
pip install .
mkdir -p run/work
cd run/work
python ../example.py

cd "$SCRIPT_DIR"