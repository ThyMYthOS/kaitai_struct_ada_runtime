#!/bin/sh
# Run the compiler backend over all formats of the Kaitai Struct test suite
# and tell for each what comes of it.
#
#   scripts/survey.sh [--prove] [--read-write] [--jobs N] [--out DIR]
#
# Every formats/*.ksy of the test suite is given to the compiler.  A format
# is "generated", "rejected" (the Ada backend names a construct it does not
# support) or "invalid" (the compiler does not accept the description at
# all).  The generated parsers are compiled, and with --prove GNATprove runs
# over all of them, with the switches the examples are proven with.  With
# --read-write the compiler is asked to generate Write as well.  The
# result is DIR/survey.tsv, one line per format, and totals on the output.
#
# KSC names the compiler launcher (default: the one scripts/build-compiler.sh
# builds in $KSC_DIR).  KST_DIR names a checkout of kaitai_struct_tests.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KSC=${KSC:-$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler}
KST_DIR=${KST_DIR:-$HOME/.cache/kaitai_struct_tests}
out=$here/obj/survey
prove=no
rw=
jobs=0
while [ $# -gt 0 ]; do
   case $1 in
      --prove) prove=yes ;;
      --read-write) rw=--read-write ;;
      --jobs) jobs=$2; shift ;;
      --out) out=$2; shift ;;
      *) echo "unknown argument $1" >&2; exit 2 ;;
   esac
   shift
done

[ -x "$KSC" ] || { echo "no compiler at $KSC; run scripts/build-compiler.sh" >&2; exit 1; }
[ -d "$KST_DIR/formats" ] || { echo "no formats in $KST_DIR" >&2; exit 1; }

rm -rf "$out"
mkdir -p "$out/src" "$out/log"

# Generate.  A format whose top-level id is that of another format (there
# are none in the suite today) would overwrite its files.
for ksy in "$KST_DIR"/formats/*.ksy; do
   name=$(basename "$ksy" .ksy)
   mkdir -p "$out/one"
   rm -f "$out"/one/*
   (cd "$KST_DIR/formats" && "$KSC" -t ada $rw -I . --outdir "$out/one" "$name.ksy") >"$out/log/$name.txt" 2>&1 || true
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
   for Source_Dirs use ("src");
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
