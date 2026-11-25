#!/bin/sh
# Regenerate the parsers under examples/ from their descriptions.
#
#   scripts/generate-examples.sh [--check]
#
# For every examples/<name>/<name>.ksy the compiler written for this
# repository (see scripts/build-compiler.sh) writes <name>.ads and
# <name>.adb next to it, and gnatformat formats them with the settings of
# kaitai_style.gpr.  With --check the committed files are restored afterwards
# and the script fails if they differ from freshly generated ones.
#
# KSC names the compiler launcher; by default it is the one that
# scripts/build-compiler.sh builds in $KSC_DIR.
set -eu

# Examples that are written by hand, as the model for constructs the
# compiler does not generate yet.  They are left alone.
HANDWRITTEN="write_model"

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KSC=${KSC:-$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler}
check=no
[ "${1:-}" = "--check" ] && check=yes

[ -x "$KSC" ] || { echo "no compiler at $KSC; run scripts/build-compiler.sh" >&2; exit 1; }

cd "$here"

backup=
if [ "$check" = yes ]; then
   backup=$(mktemp -d)
   trap 'rm -rf "$backup"' EXIT
   for ksy in examples/*/*.ksy; do
      name=$(basename "$ksy" .ksy)
      dir=$(dirname "$ksy")
      case " $HANDWRITTEN " in *" $name "*) continue ;; esac
      mkdir -p "$backup/$name"
      for ext in ads adb; do
         [ -f "$dir/$name.$ext" ] && cp "$dir/$name.$ext" "$backup/$name/$name.$ext"
      done
   done
fi

files=""
for ksy in examples/*/*.ksy; do
   name=$(basename "$ksy" .ksy)
   dir=$(dirname "$ksy")
   case " $HANDWRITTEN " in *" $name "*) continue ;; esac
   "$KSC" -t ada --outdir "$dir" "$ksy" 2>&1 | grep -v '^Picked up' || true
   files="$files $dir/$name.ads $dir/$name.adb"
done

# The formatting settings come from the project, which lists the examples
alr exec -- gnatformat -P tests/kaitai_struct_tests.gpr --no-subprojects $files

status=0
if [ "$check" = yes ]; then
   for ksy in examples/*/*.ksy; do
      name=$(basename "$ksy" .ksy)
      dir=$(dirname "$ksy")
      case " $HANDWRITTEN " in *" $name "*) continue ;; esac
      for ext in ads adb; do
         if ! cmp -s "$dir/$name.$ext" "$backup/$name/$name.$ext"; then
            echo "$dir/$name.$ext is not what the compiler generates" >&2
            status=1
         fi
         # restore what was committed
         if [ -f "$backup/$name/$name.$ext" ]; then
            cp "$backup/$name/$name.$ext" "$dir/$name.$ext"
         fi
      done
   done
   [ "$status" = 0 ] && echo "examples are up to date"
fi
exit $status
