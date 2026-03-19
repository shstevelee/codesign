#!/usr/bin/env bash

AUTOTEST_REGRESSION_PATH="auto_tests/auto-test.list.yaml"

PREINSTALLED_OPENROAD_PATH="$(pwd)/openroad_interface/OpenROAD/build/src/openroad"

set -eo pipefail

shopt -s expand_aliases

OPENROAD_PRE_INSTALLED=1 SCALEHLS_PRE_INSTALLED=1 STREAMHLS_PRE_INSTALLED=1 source full_env_start.sh

# Run regression and propagate its exit code directly.
# Use 'set +e' so the script can capture the exit code instead of exiting immediately.
set +e
run_regression -l "$AUTOTEST_REGRESSION_PATH" -g -m 10 --preinstalled_openroad_path "$PREINSTALLED_OPENROAD_PATH"
status=$?
set -e
exit $status