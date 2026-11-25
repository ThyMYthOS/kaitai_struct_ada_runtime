#!/bin/sh
# Count executed instructions instead of measuring time.
#
#   ./icount.sh [records] [max_payload]
#
# Runs the benchmarks under Valgrind (cachegrind) and reports user-space
# instructions per record.  The counts are repeatable, so small differences
# are meaningful, and no hardware performance counters are needed.  They do
# not show cache misses, page faults or time spent in the kernel; use run.sh
# for those effects.
#
# The cost of one phase is the difference between two runs that stop at
# successive phases.
set -eu

RECORDS=${1:-100000}
MAX_PAYLOAD=${2:-32}
PICKS=1000
cd "$(dirname "$0")"

count() {
   valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/dev/null "$@" 2>&1 >/dev/null |
      awk '/I +refs:/ { gsub(",", "", $NF); print $NF }'
}

per() {
   awk -v a="$1" -v b="$2" -v n="$3" 'BEGIN { printf "%12.1f", (a - b) / n }'
}

checks_for() {
   if [ "$1" = proven ]; then echo proven; else echo enabled; fi
}

for mode in checked inlined proven; do
   alr -n build -- -XMODE=$mode -XKAITAI_STRUCT_CHECKS="$(checks_for $mode)" >/dev/null
done

echo "== stream designs: instructions per 15-byte record"
for mode in checked inlined proven; do
   echo "-- mode $mode"
   base=$(count ./bin/$mode/stream_bench "$RECORDS" 1 none)
   for variant in cursor_sticky pointer_sticky cursor_status cursor_raise block_check kaitai kaitai_block kaitai_local \
         bits_classic_be kaitai_bits_be bits_classic_le kaitai_bits_le; do
      total=$(count ./bin/$mode/stream_bench "$RECORDS" 1 $variant)
      printf "%-16s%s\n" $variant "$(per "$total" "$base" "$RECORDS")"
   done
done

echo
echo "== parsing designs: instructions per record (the formats are described in bench/README.md)"
for mode in checked inlined proven; do
   echo "-- mode $mode"
   base=$(count ./bin/$mode/parse_bench "$RECORDS" 1 none)
   for variant in kaitai_term kaitai_term_local term_classic kaitai_contents kaitai_contents_local contents_classic \
         kaitai_substream kaitai_substream_local substream_classic \
         nested_local nested_outer_only nested_direct \
         fields1_local fields1_direct fields2_local fields2_direct \
         fields3_local fields3_direct fields4_local fields4_direct \
         fields8_local fields8_direct calls_both_local calls_inner_local \
         calls_direct kaitai_xor_one xor_one_classic kaitai_xor_many \
         xor_many_classic_mod xor_many_classic_counter kaitai_rotate rotate_classic \
         status1_sticky status1_returned status4_sticky status4_returned status8_sticky status8_returned \
         generated_fields4 generated_term generated_nested \
         bits_flat_v1 bits_flat_v2 bits_flat_v3 bits_flat_v3a bits_flat_v4 \
         bits_le_v1 bits_le_v2 bits_le_v3 bits_le_v3a bits_le_v4 \
         bits_mixed_v1 bits_mixed_v2 bits_mixed_v3 bits_mixed_v3a bits_mixed_v4 \
         bits_nested_v1 bits_nested_v2 bits_nested_v3 bits_nested_v3a bits_nested_v4; do
      total=$(count ./bin/$mode/parse_bench "$RECORDS" 1 $variant)
      printf "%-26s%s\n" $variant "$(per "$total" "$base" "$RECORDS")"
   done
done

echo
echo "== overflow protection: instructions per 15-byte record with two expressions"
for mode in checked inlined proven; do
   echo "-- mode $mode"
   base=$(count ./bin/$mode/arith_bench "$RECORDS" none)
   for variant in plain guarded guarded_where_needed checked flagged; do
      total=$(count ./bin/$mode/arith_bench "$RECORDS" $variant)
      printf "%-22s%s\n" $variant "$(per "$total" "$base" "$RECORDS")"
   done
done

echo
echo "== memory strategies, $RECORDS records, payload 0..$MAX_PAYLOAD bytes"
echo "   instructions per record: build, traverse; per access: pick; per record: teardown"
for mode in inlined proven; do
   echo "-- mode $mode"
   for strategy in lazy index_arena index_owned vector_values vector_reserved ada_vector \
                   ptr_malloc ptr_pool ptr_pool_kept ptr_subpool \
                   owned_malloc owned_pool owned_pool_kept owned_subpool; do
      c0=$(count ./bin/$mode/memory_bench $strategy "$RECORDS" "$MAX_PAYLOAD" 1 0)
      c1=$(count ./bin/$mode/memory_bench $strategy "$RECORDS" "$MAX_PAYLOAD" 1 1)
      c2=$(count ./bin/$mode/memory_bench $strategy "$RECORDS" "$MAX_PAYLOAD" 1 2)
      c3=$(count ./bin/$mode/memory_bench $strategy "$RECORDS" "$MAX_PAYLOAD" 1 3)
      c4=$(count ./bin/$mode/memory_bench $strategy "$RECORDS" "$MAX_PAYLOAD" 1 4)
      printf "%-16s%s%s%s%s\n" $strategy \
         "$(per "$c1" "$c0" "$RECORDS")" "$(per "$c2" "$c1" "$RECORDS")" \
         "$(per "$c3" "$c2" "$PICKS")" "$(per "$c4" "$c3" "$RECORDS")"
   done
done
