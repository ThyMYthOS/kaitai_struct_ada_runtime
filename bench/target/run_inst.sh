#!/bin/sh
# Run the measurements of instances (instance_bench) on a simulated STM32F4 (Cortex-M4) in Renode and report
# instructions per record, and the size of the value of each variant.
#
#   ./run_inst.sh [rts]        default: light-stm32f4
#
# A program is built for every variant, because the program has neither arguments nor a console to read them from:
# the variant is a package of constants (cfg/instance_config.ads), which this script writes and restores.  The
# program that only generates the input of the layout is subtracted.
# Needs Alire and Renode; see ../../scripts/renode-run.sh.
set -eu

rts=${1:-light-stm32f4}
RECORDS=100   # Instance_Config.Records
cd "$(dirname "$0")"
cp cfg/instance_config.ads cfg/instance_config.ads.orig
trap 'mv cfg/instance_config.ads.orig cfg/instance_config.ads' EXIT

# write_config <variant> <run>
write_config() {
   cat >cfg/instance_config.ads <<CFG
with Inst_Runs;

package Instance_Config is
   Variant : constant Inst_Runs.Variant := Inst_Runs.$1;
   Records : constant := $RECORDS;
   Run     : constant Boolean := $2;
end Instance_Config;
CFG
}

# build <main>
build() {
   alr -n exec -- gprbuild -q -p -P kaitai_bench_target.gpr -XRTS="$rts" -XMODE=proven -XKAITAI_STRUCT_CHECKS=proven \
      -XKAITAI_STRUCT_SUBDIR="$rts" "$1" >/dev/null
}

# build_and_run <variant> <run>: print "<instructions> <checksum>"
build_and_run() {
   write_config "$1" "$2"
   build target_instance.adb
   ../../scripts/renode-run.sh "bin/$rts/proven/target_instance" 1 |
      awk '/^SUM/ { sum = $2 } /^INSTRUCTIONS/ { count = $2 } END { print count, sum }'
}

echo "== instances on $rts: instructions per record, checksum"
for v in Int_D1_Parse Int_D1_Access Int_D2_Parse Int_D2_Access User_D1_Parse User_D1_Access User_D2_Parse \
   User_D2_Access Until_D1_Parse Until_D1_Access Until_D2_Parse Until_D2_Access; do
   set -- "$v" $(build_and_run "$v" False)
   base=$2
   set -- "$v" $(build_and_run "$v" True)
   awk -v name="$1" -v total="$2" -v base="$base" -v n=$RECORDS -v sum="$3" \
      'BEGIN { printf "%-18s%12.1f   %s\n", name, (total - base) / n, sum }'
done

echo "== size of the value in bits"
build target_instance_sizes.adb
../../scripts/renode-run.sh "bin/$rts/proven/target_instance_sizes" | grep '^SIZE'
