#!/bin/sh
# Run the compiler backend over all formats of the Kaitai Struct test suite
# and tell for each what comes of it.
#
#   scripts/survey.sh [--prove] [--no-cache] [--read-write] [--jobs N] [--formats DIR] [--out DIR]
#
# Every formats/*.ksy of the test suite (or, with --formats, every *.ksy of
# DIR) is given to the compiler.  A format is "generated", "rejected" (the Ada
# backend names a construct it does not support) or "invalid" (the compiler
# does not accept the description at all).  The generated parsers are
# compiled, and with --prove GNATprove runs over all of them, with the
# switches the examples are proven with.  With --read-write the compiler is
# asked to generate Write as well.  The result is DIR/survey.tsv, one line per
# format, and totals on the output.
#
# With --formats DIR the descriptions are those of DIR instead of
# $KST_DIR/formats, and DIR is where the compiler looks for imports.
# scripts/survey.sh --prove --formats compiler/diff-formats --out DIR checks
# the descriptions of this repository that are compared with the Python target.
#
# The proof cache: when GNATPROVE_CACHE names a directory, GNATprove keeps
# its results there and a check that it finds there is not proved again.  A
# result "proved" then says that the check was proved at some time, by anybody
# who shares the directory, with equal switches; it does not say that it is
# proved now within the time limit.  A check at the edge of the time limit
# passes with a full cache and can fail without it.  --no-cache (or an empty
# GNATPROVE_CACHE) proves everything again.
#
# The import path of the compiler holds the directory of the formats and its
# subdirectory ks_path, which is what the tests mean by $KS_PATH.  KSF_DIR
# optionally names a checkout of kaitai-io/kaitai_struct_formats, which is
# added to it; imports_abs imports common/vlq_base128_le.ksy from there, and
# is "invalid" (the file is not found) without it.
#
# The formats that use an opaque type or a custom process call packages that
# are written by hand: the opaque types of the tests are formats of the suite,
# which are generated too, and the packages of the custom processes are in
# compiler/foreign/, a source directory of the project that compiles and proves
# the parsers.
#
# KSC names the compiler launcher (default: the one scripts/build-compiler.sh
# builds in $KSC_DIR).  KST_DIR names a checkout of kaitai_struct_tests.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KSC=${KSC:-$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler}
KST_DIR=${KST_DIR:-$HOME/.cache/kaitai_struct_tests}
KSF_DIR=${KSF_DIR:-}
[ -z "$KSF_DIR" ] || KSF_DIR=$(cd "$KSF_DIR" && pwd)
out=$here/obj/survey
formats=
prove=no
rw=
jobs=0
while [ $# -gt 0 ]; do
   case $1 in
      --prove) prove=yes ;;
      --no-cache) GNATPROVE_CACHE= ;;
      --read-write) rw=--read-write ;;
      --jobs) jobs=$2; shift ;;
      --formats) formats=$2; shift ;;
      --out) out=$2; shift ;;
      *) echo "unknown argument $1" >&2; exit 2 ;;
   esac
   shift
done

[ -x "$KSC" ] || { echo "no compiler at $KSC; run scripts/build-compiler.sh" >&2; exit 1; }
[ -n "$formats" ] || formats=$KST_DIR/formats
[ -d "$formats" ] || { echo "no formats in $formats" >&2; exit 1; }
formats=$(cd "$formats" && pwd)

imports="-I . -I ks_path"
[ -n "$KSF_DIR" ] && imports="$imports -I $KSF_DIR"

rm -rf "$out"
mkdir -p "$out/src" "$out/log"

# Generate.  A format whose top-level id is that of another format (there
# are none in the suite today) would overwrite its files.
for ksy in "$formats"/*.ksy; do
   name=$(basename "$ksy" .ksy)
   mkdir -p "$out/one"
   rm -f "$out"/one/*
   (cd "$formats" && "$KSC" -t ada $rw $imports --outdir "$out/one" "$name.ksy") >"$out/log/$name.txt" 2>&1 || true
   if grep -q 'not supported by the Ada backend' "$out/log/$name.txt"; then
      reason=$(grep -m1 'not supported by the Ada backend' "$out/log/$name.txt" | sed 's/.*not supported by the Ada backend: //')
      printf '%s\trejected\t%s\n' "$name" "$reason"
   elif grep -q 'error:' "$out/log/$name.txt"; then
      reason=$(grep -m1 'error:' "$out/log/$name.txt" | sed 's/.*error: //' | cut -c1-80)
      printf '%s\tinvalid\t%s\n' "$name" "$reason"
   elif ls "$out"/one/*.ads >/dev/null 2>&1; then
      mv "$out"/one/* "$out/src/"
      printf '%s\tgenerated\t\n' "$name"
   else
      printf '%s\tcrashed\t%s\n' "$name" "$(tail -1 "$out/log/$name.txt" | cut -c1-80)"
   fi
done >"$out/generate.tsv"

cat >"$out/survey.gpr" <<GPR
with "$here/kaitai_struct.gpr";
project Survey is
   for Source_Dirs use ("src", "$here/compiler/foreign");
   for Object_Dir use "obj";
   for Create_Missing_Dirs use "True";
   package Compiler is
      for Default_Switches ("Ada") use ("-gnat2012", "-gnata", "-gnatwa");
   end Compiler;
   package Prove is
      for Proof_Switches ("Ada") use ("--level=1", "--checks-as-errors=off", "--output=oneline");
   end Prove;
end Survey;
GPR

cd "$here"
alr exec -- gprbuild -q -c -k -j0 -P "$out/survey.gpr" >"$out/compile.txt" 2>&1 || true

if [ "$prove" = yes ]; then
   cache=""
   if [ -n "${GNATPROVE_CACHE:-}" ]; then
      mkdir -p "$GNATPROVE_CACHE"
      cache="--memcached-server=file:$GNATPROVE_CACHE"
   fi
   alr exec -- gnatprove -P "$out/survey.gpr" -j"$jobs" -k $cache >"$out/prove.txt" 2>&1 || true
fi

# One line per format: name, class, reason, compiled, proved
while IFS="$(printf '\t')" read -r name class reason; do
   compiled=-
   proved=-
   if [ "$class" = generated ]; then
      # Messages name the files of the parser, which are called after it
      if grep -q "^$name\.ad[sb]:.*\(error\|warning\)" "$out/compile.txt"; then compiled=no; else compiled=yes; fi
      if [ "$prove" = yes ]; then
         if grep -q "^$name\.ad[sb]:" "$out/prove.txt"; then proved=no; else proved=yes; fi
      fi
   fi
   printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$class" "$reason" "$compiled" "$proved"
done <"$out/generate.tsv" >"$out/survey.tsv"

awk -F'\t' '
   { class[$2]++ }
   $2 == "generated" && $4 == "yes" { compiled++ }
   $2 == "generated" && $5 == "yes" { proved++ }
   $2 == "generated" && $5 == "no" { unproved = unproved " " $1 }
   $2 == "generated" && $4 == "no" { broken = broken " " $1 }
   END {
      printf "formats: %d, generated: %d, rejected: %d, invalid: %d, crashed: %d\n", NR, class["generated"], class["rejected"], class["invalid"], class["crashed"]
      printf "compiled without messages: %d of %d\n", compiled, class["generated"]
      if (broken != "") print "with messages:" broken
      if (proved + 0 > 0 || unproved != "") printf "proved without messages: %d of %d\n", proved, class["generated"]
      if (unproved != "") print "not proved:" unproved
   }' "$out/survey.tsv"
