#!/bin/sh
# Check that the compiler rejects each description in compiler/rejected/ with the error that its first line names.
#
#   scripts/check-rejected.sh
#
# The first line of a description is `# error: <text>`; the compiler must report
# a construct that the Ada backend does not support, and its message must contain
# the text.  KSC names the compiler launcher (default: the one that
# scripts/build-compiler.sh builds in $KSC_DIR).
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KSC=${KSC:-$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler}
[ -x "$KSC" ] || { echo "no compiler at $KSC; run scripts/build-compiler.sh" >&2; exit 1; }

status=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for ksy in "$here"/compiler/rejected/*.ksy; do
   name=$(basename "$ksy")
   want=$(head -n 1 "$ksy" | sed 's/^# error: //')
   "$KSC" -t ada --outdir "$tmp" "$ksy" >"$tmp/log" 2>&1 || true
   if grep -q "not supported by the Ada backend" "$tmp/log" && grep -qF -- "$want" "$tmp/log"; then
      echo "ok   $name"
   else
      echo "FAIL $name: expected an error with: $want" >&2
      sed 's/^/     /' "$tmp/log" >&2
      status=1
   fi
done
exit $status
