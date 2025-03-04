#!/usr/bin/env bash

# Function to display usage instructions
usage() {
  echo "Usage: $0 [-s SETTINGS_FILE] [-D NAME=VALUE]"
  echo "  -s SETTINGS_FILE    Specify Maven settings file"
  echo "  -D NAME=VALUE       Set a system property (can be used multiple times)"
  echo "Any remaining arguments will be passed directly to Maven."
  exit 1
}

# Initialize variables
settings_file=""
system_properties=()  # Use an array for multiple -D options

# Parse command-line options
while getopts "s:D:" opt; do
  case $opt in
    s)
      settings_file="-s $OPTARG"
      ;;
    D)
      system_properties+=("-D$OPTARG")
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

# Shift off the processed options, leaving only the remaining arguments
shift "$((OPTIND-1))"

# Construct Maven command
mvn_command="mvn -B ${settings_file}"

# Add system properties to the command
for prop in "${system_properties[@]}"; do
  mvn_command+=" ${prop}"
done

# Append any remaining arguments to the Maven command
mvn_command+=" $@"

# Add the fixed part of the Maven command
mvn_command+=" clean compile test"

echo "DEBUG: Executing Maven command: ${mvn_command}"
${mvn_command} | tee build.log

TEST_RESULTS=$(cat build.log  | grep "Tests run:" | tail -n 1)
tests_run=$(echo $TEST_RESULTS | sed 's/.*Tests run: \([0-9]*\).*/\1/')
tests_failed=$(echo $TEST_RESULTS | sed 's/.*Failures: \([0-9]*\).*/\1/')
tests_errors=$(echo $TEST_RESULTS | sed 's/.*Errors: \([0-9]*\).*/\1/')

echo "DEBUG: tests_run = $tests_run tests_failed = $tests_failed tests_errors = $tests_errors"

if [ -z "$tests_run" ]; then
    echo "WARNING: Could not determine the number of tests run."
    exit 1
fi

if [ "$tests_run" -eq 0 ]; then
    echo "ERROR: No tests were run!"
    exit 1
fi

echo "INFO: $tests_run tests were run!"

if [ "$tests_failed" -ne 0 ]; then
    echo "ERROR: $tests_failed Tests Failed!"
    exit 1
fi

if [ "$tests_errors" -ne 0 ]; then
    echo "ERROR: $tests_errors Tests had errors!"
    exit 1
fi
