#!/usr/bin/env bash
# Run the official Kaitai Struct test suite against the Ada backend.
#
#   scripts/run-kaitai-suite.sh [--out DIR] [--no-fail] [--jobs N] [NAME ...]
#
# For every test of kaitai_struct_tests (spec/ks/<name>.kst, or only the
# NAMEs given) the script
#   1. generates the parser of formats/<name>.ksy with the Ada backend,
#   2. generates the test program test_<name>.adb with the Ada test
#      translator (AdaSG, compiler/tests-overlay),
#   3. builds all programs against the library with gprbuild,
#   4. runs each program on its data file.
# It writes DIR/results.md (a table of all tests) and DIR/junit.xml, and
# prints how many tests ended in which class:
#
#   passed         all asserts hold
#   failed         the program ran and an assert did not hold
#   error          the program raised an exception or crashed
#   build failed   the parser or the program does not compile
#   not generated  the backend rejects the format
#   not translated AdaSG cannot express the asserts of the test
#
# The exit status is 0 only if no test failed, errored or failed to build;
# --no-fail makes it 0 in any case.
#
# Environment:
#   KSC_DIR   the compiler, built by scripts/build-compiler.sh
#             (default: $HOME/.cache/kaitai_struct_compiler)
#   KST_DIR   a checkout of kaitai-io/kaitai_struct_tests at the pinned
#             commit; cloned there if missing
#             (default: $HOME/.cache/kaitai_struct_tests)
#   DIR       --out (default: build/kaitai-suite below the repository)
#
# Needs: Java, sbt (or the one build-compiler.sh downloaded), git, patch,
# python3 and Alire with a native GNAT toolchain.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KST_DIR=${KST_DIR:-$HOME/.cache/kaitai_struct_tests}
kst_commit=4108136c807f8df88df843de6571f1a7bf29c74e
out=$here/build/kaitai-suite
no_fail=0
jobs=$(nproc 2>/dev/null || echo 2)
names=()

while [ $# -gt 0 ]; do
   case $1 in
      --out) out=$2; shift 2 ;;
      --no-fail) no_fail=1; shift ;;
      --jobs) jobs=$2; shift 2 ;;
      -h | --help) sed -n '2,/^set -euo/p' "$0" | sed '$d;s/^# \{0,1\}//'; exit 0 ;;
      -*) echo "unknown option $1" >&2; exit 2 ;;
      *) names+=("${1%.kst}"); shift ;;
   esac
done

mkdir -p "$out"
out=$(cd "$out" && pwd)
ksc=$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler
if [ ! -x "$ksc" ]; then
   echo "no compiler at $ksc: run scripts/build-compiler.sh (with KSC_DIR=$KSC_DIR) first" >&2
   exit 2
fi

# sbt: the one on the PATH, or the one that build-compiler.sh downloaded
sbt=sbt
if ! command -v sbt >/dev/null 2>&1; then
   if [ -x "$KSC_DIR/.sbt-dist/sbt/bin/sbt" ]; then
      sbt=$KSC_DIR/.sbt-dist/sbt/bin/sbt
   else
      echo "sbt not found" >&2
      exit 2
   fi
fi
sbt_opts=()
if [ -f "$HOME/.sbt/repositories" ]; then
   sbt_opts+=("-Dsbt.override.build.repos=true")
fi

# Maven Central sometimes answers 429; try again a few times
run_sbt() {
   local n=0
   until "$sbt" "${sbt_opts[@]}" --batch "$@"; do
      n=$((n + 1))
      [ "$n" -lt 5 ] || { echo "sbt failed" >&2; return 1; }
      sleep 30
   done
}

step() { echo "== $*"; }

# ---------------------------------------------------------------- the tests

if [ ! -d "$KST_DIR/.git" ]; then
   step "cloning kaitai_struct_tests into $KST_DIR"
   mkdir -p "$(dirname "$KST_DIR")"
   git clone --quiet --filter=blob:none --no-checkout https://github.com/kaitai-io/kaitai_struct_tests.git "$KST_DIR"
fi
if [ ! -f "$KST_DIR/translator/build.sbt" ] || [ ! -d "$KST_DIR/formats" ] || [ ! -d "$KST_DIR/spec/ks" ] || [ ! -d "$KST_DIR/src" ]; then
   step "checking out formats, spec/ks, src and translator at $kst_commit"
   git -C "$KST_DIR" checkout --quiet "$kst_commit" -- formats spec/ks src translator
fi

# The overlay: new files with the paths of the tests repository; the patch:
# edits of existing files (registration of the target "ada")
(cd "$here/compiler/tests-overlay" && find . -type f) | while read -r f; do
   mkdir -p "$KST_DIR/$(dirname "$f")"
   cp "$here/compiler/tests-overlay/$f" "$KST_DIR/$f"
done
if patch -p1 -R --dry-run -s -d "$KST_DIR" < "$here/compiler/tests.patch" >/dev/null 2>&1; then
   echo "tests.patch is applied already"
else
   patch -p1 -s -d "$KST_DIR" < "$here/compiler/tests.patch"
fi

if [ ${#names[@]} -eq 0 ]; then
   while IFS= read -r f; do names+=("$(basename "$f" .kst)"); done < <(ls "$KST_DIR"/spec/ks/*.kst | sort)
fi
echo "${#names[@]} tests"

# ------------------------------------------------- compiler and translator

stamp=$KSC_DIR/.kst-published
if [ ! -f "$stamp" ] || [ "$ksc" -nt "$stamp" ]; then
   step "publishing the compiler locally"
   (cd "$KSC_DIR" && run_sbt compilerJVM/publishLocal) > "$out/publish.log" 2>&1 || { tail -20 "$out/publish.log"; exit 1; }
   touch "$stamp"
fi

step "building the test translator"
(cd "$KST_DIR/translator" && run_sbt compile "export Runtime/fullClasspath") > "$out/translator-build.log" 2>&1 \
   || { grep -v '^\[info\]' "$out/translator-build.log" | tail -30; exit 1; }
classpath=$(grep '^/' "$out/translator-build.log" | tail -1)
[ -n "$classpath" ] || { echo "no classpath from sbt" >&2; exit 1; }

rm -rf "$out/gen" "$out/tests" "$out/log" "$out/status" "$out/bin" "$out/obj"
mkdir -p "$out/gen" "$out/tests" "$out/log" "$out/status"

# ---------------------------------------------------- 1. the parsers

step "generating the parsers"
gen_one() {
   local n=$1
   if "$ksc" -t ada --outdir "$out/gen/$n" -I "$KST_DIR/formats" -I "$KST_DIR/formats/ks_path" \
      "$KST_DIR/formats/$n.ksy" > "$out/log/$n.ksc.log" 2>&1; then
      echo ok > "$out/log/$n.ksc.rc"
   else
      echo failed > "$out/log/$n.ksc.rc"
      rm -rf "$out/gen/$n"   # what the compiler wrote before it gave up
   fi
}
export -f gen_one
export ksc out KST_DIR
printf '%s\n' "${names[@]}" | xargs -P "$jobs" -I{} bash -c 'gen_one {}'

generated=()
for n in "${names[@]}"; do
   [ "$(cat "$out/log/$n.ksc.rc")" = ok ] && generated+=("$n")
done
echo "${#generated[@]} parsers generated"

# ---------------------------------------------------- 2. the test programs

step "generating the test programs"
translated=()
if [ ${#generated[@]} -gt 0 ]; then
   rm -rf "$KST_DIR/spec/ks/out/ada"
   # one JVM for all tests; a test that makes the translator throw is
   # retried alone below, so that it does not hide the others
   (cd "$KST_DIR/translator" && java -cp "$classpath" io.kaitai.struct.testtranslator.Main -t ada "${generated[@]}") \
      > "$out/log/translator.log" 2>&1 || true
   for n in "${generated[@]}"; do
      if [ ! -f "$KST_DIR/spec/ks/out/ada/test_$n.adb" ]; then
         (cd "$KST_DIR/translator" && java -cp "$classpath" io.kaitai.struct.testtranslator.Main -t ada "$n") \
            > "$out/log/$n.translator.log" 2>&1 || true
      fi
   done
   for n in "${generated[@]}"; do
      f=$KST_DIR/spec/ks/out/ada/test_$n.adb
      if [ ! -f "$f" ]; then
         reason=$(grep -v '^Picked up\|^Translating\|^\.\.\. generating' "$out/log/$n.translator.log" | grep -m1 '[A-Za-z]' || true)
         printf 'not translated\ttranslator failed: %s\n' "${reason:-no output}" > "$out/status/$n"
      elif head -1 "$f" | grep -q '^--  NOT TRANSLATED:'; then
         printf 'not translated\t%s\n' "$(head -1 "$f" | sed 's/^--  NOT TRANSLATED: //')" > "$out/status/$n"
      else
         cp "$f" "$out/tests/test_$n.adb"
         translated+=("$n")
      fi
   done
fi
echo "${#translated[@]} test programs generated"

# ---------------------------------------------------------- 3. the build

built=()
if [ ${#translated[@]} -gt 0 ]; then
   step "building the test programs"
   mains=$(printf '"test_%s.adb", ' "${translated[@]}")
   dirs=$(printf '"gen/%s", ' "${translated[@]}")
   cat > "$out/suite.gpr" <<EOF
with "$here/kaitai_struct.gpr";
with "$here/kaitai_struct_files.gpr";

--  Generated by scripts/run-kaitai-suite.sh: one main per test
project Suite is
   for Source_Dirs use (${dirs}"tests");
   for Object_Dir use "obj";
   for Exec_Dir use "bin";
   for Create_Missing_Dirs use "True";
   for Main use (${mains%, });

   package Compiler is
      for Default_Switches ("Ada") use ("-O1", "-g", "-gnat2012", "-gnata", "-gnatwa");
   end Compiler;
end Suite;
EOF
   # -k: keep going after errors; contracts of the library are checked, as in its own tests
   (cd "$out" && alr -C "$here" -n exec -- gprbuild -P "$out/suite.gpr" -p -k -j"$jobs" -XKAITAI_STRUCT_CONTRACTS=on) \
      > "$out/build.log" 2>&1 || true
   for n in "${translated[@]}"; do
      if [ -x "$out/bin/test_$n" ]; then built+=("$n"); fi
   done
fi
echo "${#built[@]} test programs built"

# ----------------------------------------------------------- 4. the runs

step "running the tests"
for n in "${built[@]}"; do
   data=$(grep -m1 '^data:' "$KST_DIR/spec/ks/$n.kst" | sed 's/^data: *//' || true)
   rc=0
   (cd "$KST_DIR" && timeout 60 "$out/bin/test_$n" "$KST_DIR/src") > "$out/log/$n.run" 2>&1 || rc=$?
   echo "$rc" > "$out/log/$n.run.rc"
done

# ------------------------------------------------------------ the report

step "report"
export out KST_DIR
printf '%s\n' "${names[@]}" > "$out/names.txt"
python3 -I - "$out" <<'PY'
import os, re, sys
from xml.sax.saxutils import escape, quoteattr

out = sys.argv[1]
names = [l.strip() for l in open(os.path.join(out, "names.txt")) if l.strip()]
classes = ["passed", "failed", "error", "build failed", "not generated", "not translated"]

def read(path):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except OSError:
        return None

# build errors by test: a file test_<n>.adb or <n>.ads/.adb
nameset = set(names)
build_errors = {}
log = read(os.path.join(out, "build.log")) or ""
pat = re.compile(r"^([A-Za-z0-9_\-]+)\.(?:ads|adb):(\d+):(\d+): (.*)$")
for line in log.splitlines():
    m = pat.match(line)
    if not m:
        continue
    base = m.group(1)
    n = base if base in nameset else (base[5:] if base.startswith("test_") and base[5:] in nameset else None)
    if n is None:
        continue
    text = m.group(4)
    if not text.startswith("error"):
        continue
    build_errors.setdefault(n, []).append(f"{base}.ad?:{m.group(2)}: {text}")

results = {}
for n in names:
    status = read(os.path.join(out, "status", n))
    if status is not None:
        cls, detail = status.rstrip("\n").split("\t", 1)
        results[n] = (cls, detail)
        continue
    if read(os.path.join(out, "log", n + ".ksc.rc")) is None or read(os.path.join(out, "log", n + ".ksc.rc")).strip() != "ok":
        msg = [l for l in (read(os.path.join(out, "log", n + ".ksc.log")) or "").splitlines() if l.strip() and not l.startswith("Picked up")]
        detail = " ".join(msg[:2]).replace(n + ".ksy", "").strip() or "no message"
        detail = re.sub(r"^\S*/formats/", "", detail)
        results[n] = ("not generated", detail)
        continue
    if not os.path.exists(os.path.join(out, "bin", "test_" + n)):
        errs = build_errors.get(n, [])
        results[n] = ("build failed", " / ".join(errs[:3]) if errs else "see build.log")
        continue
    run = read(os.path.join(out, "log", n + ".run")) or ""
    rc = int((read(os.path.join(out, "log", n + ".run.rc")) or "1").strip())
    lines = run.splitlines()
    fails = [l for l in lines if l.startswith("FAIL")]
    if rc == 0 and "PASSED" in lines and not fails:
        results[n] = ("passed", "")
    elif "FAILED" in lines and fails:
        results[n] = ("failed", "; ".join(fails[:6]) + (f"; ... ({len(fails)} in all)" if len(fails) > 6 else ""))
    else:
        tail = [l for l in lines if l.strip()][-3:]
        results[n] = ("error", f"exit status {rc}: " + " / ".join(tail))

counts = {c: sum(1 for r in results.values() if r[0] == c) for c in classes}

with open(os.path.join(out, "results.md"), "w") as f:
    f.write("# Kaitai Struct test suite against the Ada backend\n\n")
    f.write("| Result | Tests |\n|---|---|\n")
    for c in classes:
        f.write(f"| {c} | {counts[c]} |\n")
    f.write(f"| total | {len(results)} |\n\n")
    f.write("| Test | Result | Detail |\n|---|---|---|\n")
    for n in names:
        cls, detail = results[n]
        d = detail.replace("|", "\\|").replace("\n", " ")
        f.write(f"| {n} | {cls} | {d} |\n")

with open(os.path.join(out, "junit.xml"), "w") as f:
    bad = counts["failed"]
    err = counts["error"] + counts["build failed"]
    skip = counts["not generated"] + counts["not translated"]
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write(f'<testsuite name="kaitai-struct-ada" tests="{len(results)}" failures="{bad}" errors="{err}" skipped="{skip}">\n')
    for n in names:
        cls, detail = results[n]
        f.write(f'  <testcase classname="kaitai_struct_tests" name={quoteattr(n)}>')
        if cls == "failed":
            f.write(f'<failure message={quoteattr(detail[:200])}>{escape(detail)}</failure>')
        elif cls in ("error", "build failed"):
            f.write(f'<error message={quoteattr(cls + ": " + detail[:200])}>{escape(detail)}</error>')
        elif cls in ("not generated", "not translated"):
            f.write(f'<skipped message={quoteattr(cls + ": " + detail[:200])}/>')
        f.write('</testcase>\n')
    f.write('</testsuite>\n')

print()
for c in classes:
    print(f"{c:15} {counts[c]:4}")
print(f"{'total':15} {len(results):4}")
for c in ("error", "build failed", "failed"):
    for n in names:
        if results[n][0] == c:
            print(f"  {c}: {n}: {results[n][1][:150]}")
open(os.path.join(out, "bad.count"), "w").write(str(counts["failed"] + counts["error"] + counts["build failed"]))
PY
echo "results: $out/results.md, $out/junit.xml"

bad=$(cat "$out/bad.count")
if [ "$bad" -gt 0 ] && [ "$no_fail" -eq 0 ]; then
   exit 1
fi
exit 0
