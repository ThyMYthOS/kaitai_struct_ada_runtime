#!/bin/sh
# Build and run all benchmarks.
#
#   ./run.sh [records] [max_payload]
#
# Every memory strategy runs in its own process so that the resident set
# size is not influenced by the previous strategy.
set -eu

RECORDS=${1:-1000000}
MAX_PAYLOAD=${2:-32}
cd "$(dirname "$0")"

checks_for() {
   if [ "$1" = proven ]; then echo proven; else echo enabled; fi
}

for mode in checked inlined proven; do
   alr -n build -- -XMODE=$mode -XKAITAI_STRUCT_CHECKS="$(checks_for $mode)" >/dev/null
done

echo "== stream designs: ns per 15-byte record (median, minimum), checksum"
for mode in checked inlined proven; do
   echo "-- mode $mode"
   ./bin/$mode/stream_bench "$RECORDS" 15
done

echo
echo "== parsing designs: ns per record (median, minimum), checksum"
for mode in checked inlined proven; do
   echo "-- mode $mode"
   ./bin/$mode/parse_bench "$RECORDS" 15
done

echo
echo "== memory strategies, $RECORDS records, payload 0..$MAX_PAYLOAD bytes"
echo "   ns per record: build, traverse; ns per access: pick; ns per record: teardown;"
echo "   resident bytes per record; checksums"
for mode in inlined proven; do
   echo "-- mode $mode"
   for strategy in lazy index_arena index_owned vector_values vector_reserved ada_vector \
                   ptr_malloc ptr_pool ptr_pool_kept ptr_subpool \
                   owned_malloc owned_pool owned_pool_kept owned_subpool; do
      ./bin/$mode/memory_bench $strategy "$RECORDS" "$MAX_PAYLOAD" 9
   done
done
