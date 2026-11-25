#!/bin/sh
# Regenerate the parsers of the generated_* variants of parse_bench from the
# descriptions in formats/ and format them.
#
#   ./generate.sh
#
# KSC names the compiler launcher; by default it is the one that
# ../scripts/build-compiler.sh builds in $KSC_DIR.
set -eu

KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KSC=${KSC:-$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler}

[ -x "$KSC" ] || { echo "no compiler at $KSC; run scripts/build-compiler.sh" >&2; exit 1; }

cd "$(dirname "$0")"

files=""
for ksy in formats/*.ksy; do
   name=$(basename "$ksy" .ksy)
   "$KSC" -t ada --outdir generated "$ksy" 2>&1 | grep -v '^Picked up' || true
   files="$files generated/$name.ads generated/$name.adb"
done

# The formatting settings come from the project, which lists generated/
alr exec -- gnatformat -P kaitai_bench.gpr --no-subprojects $files
