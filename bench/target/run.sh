#!/bin/sh
# Run the stream benchmark on a simulated STM32F4 (Cortex-M4) in Renode and
# report instructions per 15-byte record.
#
#   ./run.sh [rts ...]        default: light-stm32f4
#
# Each design is linked into a program of its own.  The instruction count of
# the program that parses nothing is subtracted, which leaves the cost of
# parsing.  The counts are exact and repeatable.
#
# Needs Alire and Renode; see ../../scripts/renode-run.sh.
set -eu

RECORDS=1000   # Target_Data.Records
cd "$(dirname "$0")"

# Print "<instructions> <checksum>" for one program
simulate() {
   ../../scripts/renode-run.sh "$1" |
      awk '/^SUM/ { sum = $2 } /^INSTRUCTIONS/ { count = $2 } END { print count, sum }'
}

echo "== stream designs on STM32F4: instructions per 15-byte record, checksum"
for rts in "${@:-light-stm32f4}"; do
   for mode in checked inlined proven; do
      if [ $mode = proven ]; then checks=proven; else checks=enabled; fi
      alr -n build -- -XRTS="$rts" -XMODE=$mode \
         -XKAITAI_STRUCT_CHECKS=$checks -XKAITAI_STRUCT_SUBDIR="$rts" >/dev/null
      echo "-- run-time $rts, mode $mode"
      set -- $(simulate "bin/$rts/$mode/target_none")
      base=$1
      for variant in cursor_sticky pointer_sticky cursor_status block_check kaitai kaitai_block kaitai_local \
         bits_classic_be kaitai_bits_be bits_classic_le kaitai_bits_le; do
         set -- $(simulate "bin/$rts/$mode/target_$variant")
         awk -v name=$variant -v total="$1" -v base="$base" -v n=$RECORDS -v sum="$2" \
            'BEGIN { printf "%-16s%10.1f   %s\n", name, (total - base) / n, sum }'
      done
      # The programs of parse_bench: each group has a base of its own, which
      # fills the buffer for the group and parses nothing
      echo "-- parsing designs, instructions per record"
      for group in "term kaitai_term term_classic" "contents kaitai_contents contents_classic" \
         "substream kaitai_substream substream_classic" \
         "nested nested_local nested_outer_only nested_direct"; do
         set -- $(simulate "bin/$rts/$mode/target_none_${group%% *}")
         base=$1
         for variant in ${group#* }; do
            set -- $(simulate "bin/$rts/$mode/target_$variant")
            awk -v name=$variant -v total="$1" -v base="$base" -v n=$RECORDS -v sum="$2" \
               'BEGIN { printf "%-18s%10.1f   %s\n", name, (total - base) / n, sum }'
         done
      done
      echo "-- overflow protection, instructions per 15-byte record with two expressions"
      set -- $(simulate "bin/$rts/$mode/target_arith_none")
      base=$1
      for variant in plain guarded guarded_where_needed checked flagged; do
         set -- $(simulate "bin/$rts/$mode/target_arith_$variant")
         awk -v name=$variant -v total="$1" -v base="$base" -v n=$RECORDS -v sum="$2" \
            'BEGIN { printf "%-22s%10.1f   %s\n", name, (total - base) / n, sum }'
      done
   done
done
