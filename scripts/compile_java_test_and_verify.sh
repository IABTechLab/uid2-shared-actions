#!/usr/bin/env bash

mvn -B $EXTRA_FLAGS clean compile test | tee build.log

tests_run=$(cat build.log  | grep "Tests run:" | tail -n 1 | sed 's/.*Tests run: \([0-9]*\).*/\1/')

echo "DEBUG: tests_run = $tests_run"

if [ -z "$tests_run" ]; then
    echo "WARNING: Could not determine the number of tests run."
    exit 1
fi

if [ "$tests_run" -eq 0 ]; then
    echo "ERROR: No tests were run!"
    exit 1
fi

echo "INFO: $tests_run tests were run!"