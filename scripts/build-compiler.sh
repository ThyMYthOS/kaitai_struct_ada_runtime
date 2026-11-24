#!/bin/sh
# Build the Kaitai Struct compiler with the Ada backend.
#
#   scripts/build-compiler.sh
#
# The upstream compiler is cloned at the commit that compiler/ was written
# for into $KSC_DIR (default: $HOME/.cache/kaitai_struct_compiler), or taken
# from there if it exists.  The Ada backend (compiler/, an overlay with the
# paths of the upstream tree) is copied into it, compiler/upstream.patch is
# applied, and sbt builds the launcher, whose path is printed at the end.
#
# When no sbt is on the PATH, sbt 1.12.9 is downloaded into $KSC_DIR.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
commit=963fd6b3c633e87ed197c5a065f5c8a7d31c1328
sbt_version=1.12.9

if [ ! -d "$KSC_DIR/.git" ]; then
   mkdir -p "$(dirname "$KSC_DIR")"
   git clone https://github.com/kaitai-io/kaitai_struct_compiler.git "$KSC_DIR"
   git -C "$KSC_DIR" checkout --quiet "$commit"
fi

# The overlay: new files with the paths of the upstream tree
(cd "$here/compiler" && find . -name '*.scala' -type f) | while read -r f; do
   mkdir -p "$KSC_DIR/$(dirname "$f")"
   cp "$here/compiler/$f" "$KSC_DIR/$f"
done

# The edits of existing files.  The files of the checkout are put back as
# they are upstream first, so that the patch applies whatever an earlier
# run, with an earlier patch, has left there.
git -C "$KSC_DIR" checkout --quiet "$commit" -- .
git -C "$KSC_DIR" apply "$here/compiler/upstream.patch"

sbt=sbt
if ! command -v sbt >/dev/null 2>&1; then
   if [ ! -x "$KSC_DIR/.sbt-dist/sbt/bin/sbt" ]; then
      mkdir -p "$KSC_DIR/.sbt-dist"
      curl -fsSL -o "$KSC_DIR/.sbt-dist/sbt.tgz" \
         "https://github.com/sbt/sbt/releases/download/v$sbt_version/sbt-$sbt_version.tgz"
      tar -xzf "$KSC_DIR/.sbt-dist/sbt.tgz" -C "$KSC_DIR/.sbt-dist"
   fi
   sbt="$KSC_DIR/.sbt-dist/sbt/bin/sbt"
fi

opts=""
if [ -f "$HOME/.sbt/repositories" ]; then
   opts="-Dsbt.override.build.repos=true"
fi

cd "$KSC_DIR"
# Maven Central sometimes answers 429; try again a few times
n=0
until "$sbt" $opts --batch compilerJVM/stage; do
   n=$((n + 1))
   [ "$n" -lt 5 ] || { echo "sbt failed" >&2; exit 1; }
   sleep 30
done

echo "$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler"
