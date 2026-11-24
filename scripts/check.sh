#!/bin/sh
# Run the checks of the repository; the CI runs the same script.
#
#   scripts/check.sh [step ...]      default: all steps
#
#   format   all sources are formatted with gnatformat
#   build    the library builds without warnings, with checks enabled and
#            without, and under the restrictions of a light run-time library
#   test     the tests pass on the development machine
#   prove    GNATprove proves all checks of the library and of the parsers
#            that use it: the sample parser and those under examples/
#   target   the tests pass on a simulated STM32F4, with a light and an
#            embedded run-time library
#   bench    the benchmarks build and their checksums agree
set -eu

cd "$(dirname "$0")/.."
root=$PWD

step_format() {
   for project in kaitai_struct.gpr tests/kaitai_struct_tests.gpr tests/target/kaitai_struct_tests_target.gpr \
      bench/kaitai_bench.gpr bench/target/kaitai_bench_target.gpr; do
      (cd "$(dirname "$project")" && alr exec -- gnatformat -P "$(basename "$project")" -U --no-subprojects --check)
   done
}

step_build() {
   # -gnatwe turns warnings and style violations into errors
   alr -n build -- -XKAITAI_STRUCT_CHECKS=enabled -cargs -gnatwe
   alr -n build -- -XKAITAI_STRUCT_CHECKS=proven -cargs -gnatwe
   alr -n build -- -XKAITAI_STRUCT_CONTRACTS=on -cargs -gnatwe
   alr -n build -- -XKAITAI_STRUCT_RESTRICTIONS=on -cargs -gnatwe
}

step_test() {
   (cd tests && alr -n build -- -cargs -gnatwe && ./bin/tests_main)
}

step_prove() {
   # GNATprove keeps the answers of the provers in the directory that
   # GNATPROVE_CACHE names, and takes them from there when it meets the same
   # question again.  The CI sets it and carries the directory from run to
   # run.  It has to be an absolute path.
   cache=""
   if [ -n "${GNATPROVE_CACHE:-}" ]; then
      mkdir -p "$GNATPROVE_CACHE"
      cache="--memcached-server=file:$GNATPROVE_CACHE"
   fi
   alr exec -- gnatprove -P kaitai_struct.gpr $cache
   # Of the tests project this covers the units in SPARK: the sample parser
   # and the parsers under examples/
   (cd tests && alr exec -- gnatprove -P kaitai_struct_tests.gpr $cache)
}

step_target() {
   tests/target/run.sh light-stm32f4 embedded-stm32f4
}

step_bench() {
   (
      cd bench
      alr -n build -- -XMODE=proven -XKAITAI_STRUCT_CHECKS=proven
      # Designs that parse the same fields must agree: the byte-aligned ones,
      # the bit fields in big endian order, and those in little endian order
      output=$(./bin/proven/stream_bench 10000 1)
      for group in -v 'bits_be' 'bits_le'; do
         case $group in
            -v) sums=$(echo "$output" | grep -v 'bits' | awk '{ print $NF }' | sort -u | wc -l) ;;
            *) sums=$(echo "$output" | grep "$group" | awk '{ print $NF }' | sort -u | wc -l) ;;
         esac
         [ "$sums" = 1 ] || { echo "stream designs disagree" >&2; exit 1; }
      done
      sums=$(for strategy in lazy index_arena index_owned vector_values vector_reserved ada_vector \
         ptr_malloc ptr_pool ptr_pool_kept ptr_subpool owned_malloc owned_pool owned_pool_kept owned_subpool; do
         ./bin/proven/memory_bench $strategy 10000 32 1 | awk '{ print $(NF - 1), $NF }'
      done | sort -u | wc -l)
      [ "$sums" = 1 ] || { echo "memory strategies disagree" >&2; exit 1; }
   )
}

[ $# -gt 0 ] || set -- format build test prove target bench
for step in "$@"; do
   echo "== $step"
   cd "$root"
   "step_$step"
done
echo "== all checks passed"
