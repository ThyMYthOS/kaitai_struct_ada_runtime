#!/bin/sh
# Run the measurements of repetitions (repeat_bench) on a simulated STM32F4 (Cortex-M4) in Renode and report
# instructions per run of a variant.
#
#   ./run_rep.sh [rts]        default: light-stm32f4
#   ONLY=worst ./run_rep.sh   only the last group
#
# A program is built for every combination of variant and number of elements, because the program has neither
# arguments nor a console to read them from: the combination is a package of constants (cfg/repeat_config.ads),
# which this script writes and restores.  The program that only generates the input of the layout is subtracted.
# Needs Alire and Renode; see ../../scripts/renode-run.sh.
set -eu

rts=${1:-light-stm32f4}
cd "$(dirname "$0")"
cp cfg/repeat_config.ads cfg/repeat_config.ads.orig
trap 'mv cfg/repeat_config.ads.orig cfg/repeat_config.ads' EXIT

# write_config <variant> <elements> <run>
write_config() {
   cat >cfg/repeat_config.ads <<CFG
with Rep_Runs;

package Repeat_Config is
   Variant  : constant Rep_Runs.Variant := Rep_Runs.$1;
   Elements : constant := $2;
   Reps     : constant := 1;
   Run      : constant Boolean := $3;
end Repeat_Config;
CFG
}

# simulate <seconds>: print "<instructions> <checksum>" of the program just built
simulate() {
   ../../scripts/renode-run.sh "bin/$rts/proven/target_repeat" "$1" |
      awk '/^SUM/ { sum = $2 } /^INSTRUCTIONS/ { count = $2 } END { print count, sum }'
}

# build_and_run <variant> <elements> <run> <seconds>
build_and_run() {
   write_config "$1" "$2" "$3"
   alr -n exec -- gprbuild -q -p -P kaitai_bench_target.gpr -XRTS="$rts" -XMODE=proven -XKAITAI_STRUCT_CHECKS=proven \
      -XKAITAI_STRUCT_SUBDIR="$rts" target_repeat.adb >/dev/null
   simulate "$4"
}

# measure <variant> <elements> <seconds>
measure() {
   set -- "$1" "$2" "$3" $(build_and_run "$1" "$2" False "$3")
   base=$4
   set -- "$1" "$2" "$3" $(build_and_run "$1" "$2" True "$3")
   awk -v name="$1" -v n="$2" -v total="$4" -v base="$base" -v sum="$5" \
      'BEGIN { printf "%-18s%8d%12d   %s\n", name, n, total - base, sum }'
}

echo "== repetitions on $rts: instructions per run, checksum"
if [ -z "${ONLY:-}" ]; then
for n in 10 100 1000; do
   seconds=0.5
   [ "$n" -lt 1000 ] || seconds=4
   for v in A_Parse A_Get_First A_Get_Mid A_Get_Last A_Next_All A_Get_All Index_Mod Index_Get Index_Fixed_Mod \
      Index_Fixed Last_Eos Last_Get Last_Kept Prev_Carried Other_Get Other_Lockstep; do
      measure "$v" "$n" "$seconds"
   done
done
for n in 8 10 12 14 16; do
   measure Prev_Naive "$n" 0.5
done
for n in 1000 100000; do
   for v in Empty_Parse Empty_Get Empty_Get_Stop; do
      measure "$v" "$n" 1
   done
done
fi
# The input that costs most for its size: a quarter of N references, each to the last element
for n in 500 1000; do
   measure Index_Worst "$n" 4
done
