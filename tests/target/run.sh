#!/bin/sh
# Build the tests for an STM32F4 and run them in Renode.
#
#   ./run.sh [rts ...]        default: light-stm32f4
set -eu

cd "$(dirname "$0")"
status=0
for rts in "${@:-light-stm32f4}"; do
   echo "== tests on STM32F4, run-time $rts"
   alr -n build -- -XRTS="$rts" -XKAITAI_STRUCT_SUBDIR="$rts" >/dev/null
   output=$(../../scripts/renode-run.sh "bin/$rts/target_tests_main")
   echo "$output"
   echo "$output" | grep -q '^PASSED' || status=1
done
exit $status
