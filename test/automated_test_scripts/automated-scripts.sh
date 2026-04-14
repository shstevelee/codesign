#!/usr/bin/env bash

AUTOTEST_REGRESSION_PATH="auto_tests/auto-test.list.yaml"

set -eo pipefail

shopt -s expand_aliases

source full_env_start.sh --skip-openroad

# Run regression and propagate its exit code directly.
# Use 'set +e' so the script can capture the exit code instead of exiting immediately.
set +e
run_regression -l "$AUTOTEST_REGRESSION_PATH" -g -m 10 --preinstalled_openroad_path "$PREINSTALLED_OPENROAD_PATH" --preinstalled_scalehls_path "$PREINSTALLED_SCALEHLS_PATH" --preinstalled_streamhls_path "$PREINSTALLED_STREAMHLS_PATH"
status=$?
set -e
exit $status