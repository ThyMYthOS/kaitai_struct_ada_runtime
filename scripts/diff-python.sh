#!/usr/bin/env bash
# Differential test: the Ada parsers against the Python parsers of the same compiler.
#
#   scripts/diff-python.sh [--out DIR] [--inputs N] [--jobs N] [--no-fail] [--reuse] [--formats DIR] [NAME ...]
#
# For every format of kaitai_struct_tests that the Ada backend generates
# (formats/<name>.ksy, or only the NAMEs given), and for the formats of our own in
# compiler/diff-formats (<name>.ksy with its data file <name>.bin; --formats names
# another directory), the script
#   1. generates the Ada parser and the Python parser with the same compiler,
#   2. generates a dump program in Ada and one in Python from the same
#      description (AdaDiff, compiler/tests-overlay); both print one line
#      `path = value` for every field, instance, element and nested value,
#      or the single line FAILED if anything fails while the whole value is
#      walked,
#   3. makes the inputs: the data file of the test of the format plus N
#      mutations of it (fixed seed), the same files for both sides,
#   4. builds the Ada dump programs against the library with run-time checks
#      on and contracts executed,
#   5. runs both programs on every input and compares the dumps.
# It writes DIR/results.md (a table per format and every difference), keeps
# the inputs in DIR/inputs and the dumps of the differences in DIR/diffs, and
# prints a summary.
#
# Classes of an input:
#   same             both dumps are equal (both parsed, or both failed)
#   known            a difference in KNOWN_DIFFERENCES below (documented, intended)
#   different        a difference that nothing explains: a finding
#   Ada exception    the Ada program raised an exception or a contract failed
#                    (also a finding)
#   no result        a program crashed or timed out
# A format is `skipped` with a reason if the backend rejects it, it has no test
# data or the dump cannot be generated, and `build failed` if its Ada program
# does not compile.
#
# The exit status is 0 only if there is no input of the classes different,
# Ada exception and no result, and no format failed to build; --no-fail makes
# it 0 in any case.
#
# --reuse keeps what is in DIR from an earlier run (parsers, dumps, inputs)
# instead of generating it again, so that a generated parser can be changed by
# hand to see whether the comparison finds the change; the programs are built
# again.
#
# Environment:
#   KSC_DIR   the compiler, built by scripts/build-compiler.sh
#             (default: $HOME/.cache/kaitai_struct_compiler)
#   KST_DIR   a checkout of kaitai-io/kaitai_struct_tests at the pinned
#             commit (default: $HOME/.cache/kaitai_struct_tests)
#   PYTHON    the Python 3 to use (default: python3)
#   KAITAI_PYTHON_RUNTIME  a checkout of kaitai_struct_python_runtime (default:
#             $HOME/.cache/kaitai_struct_python_runtime, cloned at the commit
#             that the script names if it is missing)
#   DIR       --out (default: build/diff-python below the repository)
#
# Needs: Java, sbt, git, patch, Python 3 (3.8 or later) and Alire with a native GNAT toolchain.
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
KSC_DIR=${KSC_DIR:-$HOME/.cache/kaitai_struct_compiler}
KST_DIR=${KST_DIR:-$HOME/.cache/kaitai_struct_tests}
kst_commit=4108136c807f8df88df843de6571f1a7bf29c74e
out=$here/build/diff-python
no_fail=0
jobs=2
inputs=200
reuse=0
extra=$here/compiler/diff-formats
names=()

while [ $# -gt 0 ]; do
   case $1 in
      --out) out=$2; shift 2 ;;
      --inputs) inputs=$2; shift 2 ;;
      --jobs) jobs=$2; shift 2 ;;
      --no-fail) no_fail=1; shift ;;
      --reuse) reuse=1; shift ;;
      --formats) extra=$2; shift 2 ;;
      -h | --help) sed -n '2,/^set -euo/p' "$0" | sed '$d;s/^# \{0,1\}//'; exit 0 ;;
      -*) echo "unknown option $1" >&2; exit 2 ;;
      *) names+=("${1%.ksy}"); shift ;;
   esac
done

mkdir -p "$out"
out=$(cd "$out" && pwd)
ksc=$KSC_DIR/jvm/target/universal/stage/bin/kaitai-struct-compiler
if [ ! -x "$ksc" ]; then
   echo "no compiler at $ksc: run scripts/build-compiler.sh (with KSC_DIR=$KSC_DIR) first" >&2
   exit 2
fi

# Differences between the Ada and the Python parsers that are intended or documented, and
# that therefore do not make the script fail: "id@@class@@format regexp@@Ada reason regexp@@Python
# reason regexp@@reason@@check", the check being empty or `outside-s64` (the Ada reason is
# `undefined <path>` and the Python dump has an integer outside S64 at that path).  An input is a known difference if its class (`ada-fails`: Ada
# FAILED and Python parsed; `py-fails`: the other way round) is the one of the entry, the
# format matches, and what the programs say about the failure (the `#why` lines; empty for
# the side that parsed) matches the regexps.  Keep the list short and specific.
KNOWN_DIFFERENCES=(
   "encoding-not-checked@@py-fails@@.*@@.*@@^UnicodeDecodeError: '(?!ascii|utf-8|utf-16)@@Ada checks strings only in ASCII, UTF-8 and UTF-16; in any other encoding every byte is accepted (docs/codegen.md, Rules of the compiler)@@"
   "depth-or-repetition-limit@@ada-fails@@.*@@^parse LIMIT_EXCEEDED$@@.*@@a type that contains itself is parsed to a depth of 8, and a repetition without progress ends with Limit_Exceeded (docs/codegen.md, Types that contain themselves)@@"
   "overflow-64@@ada-fails@@.*@@^undefined @@.*@@an expression that does not fit into 64 bits is not defined in Ada, Python has integers of any size (docs/codegen.md, What differs); only if the Python value of the instance is outside S64@@outside-s64"
)

# ---------------------------------------------------------------- tools

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

py=${PYTHON:-python3}
# The Python runtime: the generated code of this compiler build needs `substream`, which
# the release 0.11 of kaitaistruct on PyPI does not have, so the runtime comes from its
# repository, at the commit that was current when this script was written
py_runtime=${KAITAI_PYTHON_RUNTIME:-$HOME/.cache/kaitai_struct_python_runtime}
py_runtime_commit=54076c90b5c81348c0d4d005d769247d0497a007
if [ ! -f "$py_runtime/kaitaistruct.py" ]; then
   step "cloning kaitai_struct_python_runtime into $py_runtime"
   mkdir -p "$(dirname "$py_runtime")"
   git clone --quiet https://github.com/kaitai-io/kaitai_struct_python_runtime.git "$py_runtime"
   git -C "$py_runtime" checkout --quiet "$py_runtime_commit"
fi
export PYTHONPATH=$py_runtime

# ---------------------------------------------------------- the tests

if [ ! -d "$KST_DIR/.git" ]; then
   step "cloning kaitai_struct_tests into $KST_DIR"
   mkdir -p "$(dirname "$KST_DIR")"
   git clone --quiet --filter=blob:none --no-checkout https://github.com/kaitai-io/kaitai_struct_tests.git "$KST_DIR"
fi
if [ ! -f "$KST_DIR/translator/build.sbt" ] || [ ! -d "$KST_DIR/formats" ] || [ ! -d "$KST_DIR/spec/ks" ] || [ ! -d "$KST_DIR/src" ]; then
   step "checking out formats, spec/ks, src and translator at $kst_commit"
   git -C "$KST_DIR" checkout --quiet "$kst_commit" -- formats spec/ks src translator
fi

# The overlay (new files of the tests repository) and the patch (edits of existing ones)
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
   while IFS= read -r f; do names+=("$(basename "$f" .ksy)"); done < <(ls "$KST_DIR"/formats/*.ksy | sort)
   if [ -d "$extra" ]; then
      while IFS= read -r f; do names+=("$(basename "$f" .ksy)"); done < <(ls "$extra"/*.ksy 2>/dev/null | sort)
   fi
fi
echo "${#names[@]} formats"

# ------------------------------------------------- compiler and translator

stamp=$KSC_DIR/.kst-published
if [ ! -f "$stamp" ] || [ -n "$(find "$KSC_DIR/jvm/target/universal/stage/lib" -name 'io.kaitai*.jar' -newer "$stamp" 2>/dev/null)" ]; then
   step "publishing the compiler locally"
   (cd "$KSC_DIR" && run_sbt compilerJVM/publishLocal) > "$out/publish.log" 2>&1 || { tail -20 "$out/publish.log"; exit 1; }
   touch "$stamp"
fi

step "building the test translator"
(cd "$KST_DIR/translator" && run_sbt compile "export Runtime/fullClasspath") > "$out/translator-build.log" 2>&1 \
   || { grep -v '^\[info\]' "$out/translator-build.log" | tail -30; exit 1; }
classpath=$(grep '^/' "$out/translator-build.log" | tail -1)
[ -n "$classpath" ] || { echo "no classpath from sbt" >&2; exit 1; }
# The dumps must come from the compiler build that wrote the parsers, which the
# staged launcher holds, not from whatever was published locally last
stage_jar=$(ls "$KSC_DIR"/jvm/target/universal/stage/lib/io.kaitai*compiler*.jar | head -1)
classpath=$(echo "$classpath" | sed "s#[^:]*kaitai-struct-compiler_2.13.jar#$stage_jar#")

if [ "$reuse" -eq 0 ]; then
   rm -rf "$out/gen" "$out/py" "$out/dump" "$out/inputs" "$out/status"
fi
rm -rf "$out/log" "$out/run" "$out/bin" "$out/obj"
mkdir -p "$out/gen" "$out/py" "$out/dump" "$out/inputs" "$out/status" "$out/log" "$out/run"

# ---------------------------------------------------- 1. the parsers

step "generating the Ada and Python parsers"
gen_one() {
   local n=$1 data msg
   if [ "$reuse" -eq 1 ] && [ -d "$out/gen/$n" ] && [ -d "$out/py/$n" ]; then
      return
   fi
   # the description and the data file of the test, or of our own format
   if [ -f "$extra/$n.ksy" ]; then
      ksy=$extra/$n.ksy
      data=$extra/$n.bin
   else
      ksy=$KST_DIR/formats/$n.ksy
      data=$(grep -m1 '^data:' "$KST_DIR/spec/ks/$n.kst" 2>/dev/null | sed 's/^data: *//' || true)
      [ -z "$data" ] || data=$KST_DIR/src/$data
   fi
   if [ -z "$data" ] || [ ! -f "$data" ] || [ ! -f "$ksy" ]; then
      printf 'skipped\tno test with a data file\n' > "$out/status/$n"
      return
   fi
   if ! "$ksc" -t ada --outdir "$out/gen/$n" -I "$KST_DIR/formats" -I "$KST_DIR/formats/ks_path" -I "$extra" \
      "$ksy" > "$out/log/$n.ksc.log" 2>&1; then
      msg=$(grep -v '^Picked up' "$out/log/$n.ksc.log" | grep -m1 '[A-Za-z]' | sed "s#^[^ ]*/formats/##" || true)
      printf 'skipped\tthe backend rejects it: %s\n' "${msg:-no message}" > "$out/status/$n"
      rm -rf "$out/gen/$n"
      return
   fi
   if ! "$ksc" -t python --outdir "$out/py/$n" -I "$KST_DIR/formats" -I "$KST_DIR/formats/ks_path" -I "$extra" \
      "$ksy" > "$out/log/$n.ksc-python.log" 2>&1; then
      msg=$(grep -v '^Picked up' "$out/log/$n.ksc-python.log" | grep -m1 '[A-Za-z]' || true)
      printf 'skipped\tthe Python target rejects it: %s\n' "${msg:-no message}" > "$out/status/$n"
      rm -rf "$out/gen/$n" "$out/py/$n"
      return
   fi
   printf '%s\n%s\n' "$data" "$ksy" > "$out/gen/$n/.source"
}
export -f gen_one
export ksc out KST_DIR reuse extra
printf '%s\n' "${names[@]}" | xargs -P "$jobs" -I{} bash -c 'gen_one {}'

generated=()
for n in "${names[@]}"; do
   [ -d "$out/gen/$n" ] && generated+=("$n")
done
echo "${#generated[@]} formats with both parsers"

# ------------------------------------------------------- 2. the dumps

step "generating the dump programs"
dumped=()
if [ ${#generated[@]} -gt 0 ]; then
   if [ "$reuse" -eq 0 ] || [ ! -d "$out/dump/${generated[0]}" ]; then
      java -cp "$classpath" io.kaitai.struct.testtranslator.specgenerators.AdaDiff \
         "$KST_DIR/formats:$extra" "$KST_DIR/formats/ks_path" "$out/dump" "${generated[@]}" > "$out/log/adadiff.log" 2>&1 \
         || { tail -20 "$out/log/adadiff.log"; exit 1; }
   fi
   for n in "${generated[@]}"; do
      if [ -f "$out/dump/$n/skipped" ]; then
         printf 'skipped\tno dump: %s\n' "$(cat "$out/dump/$n/skipped")" > "$out/status/$n"
      elif [ -f "$out/dump/$n/dump_$n.adb" ]; then
         dumped+=("$n")
      else
         printf 'skipped\tno dump program was generated\n' > "$out/status/$n"
      fi
   done
fi
echo "${#dumped[@]} dump programs generated"

# ---------------------------------------------------------- 3. the inputs

step "making the inputs ($inputs mutations of each data file)"
export out KST_DIR inputs
export DIFF_JOBS=$jobs
printf '%s\n' "${dumped[@]}" > "$out/dumped.txt"
"$py" -I - "$out" "$KST_DIR" "$inputs" "$reuse" "$py" <<'PY'
import concurrent.futures, os, random, re, subprocess, sys

out, kst, count, reuse, py = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4] == "1", sys.argv[5]
names = [l.strip() for l in open(os.path.join(out, "dumped.txt")) if l.strip()]

SPECIAL = [0x00, 0x01, 0x02, 0x03, 0x7F, 0x80, 0xFE, 0xFF]


def dictionary(path):
    """Numbers and strings of the description (magic numbers, `valid`, `contents`, case labels, enumeration values)
    as bytes: without them a mutation hardly ever finds the values that make a parser take another path"""
    text = open(path, errors="replace").read()
    toks = set()
    for m in re.finditer(r"\b0x[0-9a-fA-F_]+\b|\b\d+\b", text):
        try:
            v = int(m.group(0).replace("_", ""), 0)
        except ValueError:
            continue
        if v < 256:
            toks.add(bytes([v]))
        for w in (2, 4, 8):
            if v < 1 << (8 * w):
                toks.add(v.to_bytes(w, "little"))
                toks.add(v.to_bytes(w, "big"))
    for m in re.finditer(r"\"([^\"\n]{1,32})\"|'([^'\n]{1,32})'", text):
        toks.add((m.group(1) or m.group(2)).encode("utf-8", "replace"))
    return sorted(toks)[:400]


def mutate1(seed, rng, k, words, sweep):
    n = len(seed)
    b = bytearray(seed)
    # the first ones are fixed: they are the same for every format
    fixed = [
        lambda: b"",
        lambda: bytes(n),
        lambda: b"\xff" * n,
        lambda: seed[:-1],
        lambda: seed[: n // 2],
        lambda: seed + b"\x00",
        lambda: seed + seed,
        lambda: seed[1:],
    ]
    if k < len(fixed):
        return bytes(fixed[k]())
    kind = rng.choice(["flip", "byte", "byte", "byte", "trunc", "extend", "dup", "del", "ins", "zero", "ones", "bytes"] + ["word"] * 4 * bool(words) + ["sweep"] * 4)

    def pos():
        # many fields that matter (lengths, counts, selectors) are at the start
        if n == 0:
            return 0
        return rng.randrange(min(n, 16)) if rng.random() < 0.5 else rng.randrange(n)

    if n == 0:
        return bytes(rng.randrange(256) for _ in range(rng.randrange(1, 17)))
    if kind == "word":
        w = rng.choice(words)
        r = rng.random()
        i = 0 if r < 0.25 else rng.randrange(n + 1) if r < 0.4 else pos()
        if rng.random() < 0.7:
            b[i : i + len(w)] = w
        else:
            b[i:i] = w
        return bytes(b)
    if kind == "sweep":
        # every position of the data file gets its turn, so that no field is left out by chance
        b[sweep() % n] = rng.choice(SPECIAL) if rng.random() < 0.5 else rng.randrange(256)
        return bytes(b)
    if kind == "flip":
        for _ in range(rng.randrange(1, 4)):
            i = pos()
            b[i] ^= 1 << rng.randrange(8)
        return bytes(b)
    if kind == "byte":
        for _ in range(rng.randrange(1, 3)):
            b[pos()] = rng.choice(SPECIAL) if rng.random() < 0.7 else rng.randrange(256)
        return bytes(b)
    if kind == "bytes":
        i = pos()
        for j in range(i, min(n, i + rng.randrange(2, 9))):
            b[j] = rng.randrange(256)
        return bytes(b)
    if kind == "trunc":
        return seed[: rng.randrange(n)]
    if kind == "extend":
        m = rng.randrange(1, 33)
        return seed + (bytes(m) if rng.random() < 0.3 else bytes(rng.randrange(256) for _ in range(m)))
    if kind == "dup":
        i = rng.randrange(n)
        j = min(n, i + rng.randrange(1, 17))
        return seed[:j] + seed[i:j] + seed[j:]
    if kind == "del":
        i = rng.randrange(n)
        j = min(n, i + rng.randrange(1, 17))
        return seed[:i] + seed[j:]
    if kind == "ins":
        i = pos()
        return seed[:i] + bytes(rng.randrange(256) for _ in range(rng.randrange(1, 5))) + seed[i:]
    if kind == "zero":
        i = pos()
        j = min(n, i + rng.randrange(1, 9))
        b[i:j] = bytes(j - i)
        return bytes(b)
    i = pos()
    j = min(n, i + rng.randrange(1, 9))
    b[i:j] = b"\xff" * (j - i)
    return bytes(b)


def mutate(seed, rng, k, words, sweep):
    m = mutate1(seed, rng, k, words, sweep)
    if k >= 8:
        # several changes together: one of them often has to repair what another breaks
        for _ in range(rng.choice([0, 0, 1, 2])):
            m = mutate1(m, rng, k, words, sweep)
    return m


def limit():
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (3 << 30, 3 << 30))


def signature(text):
    """What a dump shows of the shape of the value: the paths without element numbers, the chosen cases, the
    absent members; for a failure the kind of the exception"""
    lines = [l for l in text.split("\n")[1:] if l and not l.startswith("#")]
    if lines[:1] == ["FAILED"]:
        why = [l for l in text.split("\n") if l.startswith("#why ")]
        return ("FAILED", re.sub(r"[^A-Za-z_].*", "", why[0][5:]) if why else "")
    shape = set()
    for l in lines:
        path, _, value = l.partition(" = ")
        shape.add(re.sub(r"\[\d+\]", "[]", path) + (" " + value if path.endswith(".case") or value == "absent" else ""))
    return frozenset(shape)


def shapes(n, d, files):
    """The signature of the Python dump of each file, run in one process"""
    cmd = [py, os.path.join(out, "dump", n, "dump_" + n + ".py"), os.path.join(out, "py", n)] + files
    try:
        text = subprocess.run(cmd, cwd=d, capture_output=True, timeout=60, preexec_fn=limit).stdout.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        return {}
    res = {}
    for sect in text.split("@@ ")[1:]:
        name, _, rest = sect.partition("\n")
        res[name] = signature(sect)
    return res


def make(n):
    d = os.path.join(out, "inputs", n)
    if reuse and os.path.isdir(d) and os.listdir(d):
        return len(os.listdir(d))
    os.makedirs(d, exist_ok=True)
    data, ksy = open(os.path.join(out, "gen", n, ".source")).read().split("\n")[:2]
    seed = open(data, "rb").read()
    rng = random.Random("diff-python:" + n)
    words = dictionary(ksy)
    order = list(range(max(len(seed), 1)))
    rng.shuffle(order)
    turn = [0]

    def sweep():
        turn[0] += 1
        return order[turn[0] % len(order)]

    seen = {seed}
    with open(os.path.join(d, "seed.bin"), "wb") as f:
        f.write(seed)
    # The inputs come in batches of 25. A mutant whose Python dump has a shape that no earlier input had (another
    # chosen case, a member that is there or not, another kind of failure) becomes a seed of the later mutants,
    # which makes them go deeper into the structure than mutations of the data file alone
    corpus = [seed]
    shape_seen = set(shapes(n, d, ["seed.bin"]).values())
    k = made = tries = 0
    while made < count and tries < count * 20:
        batch = []
        while len(batch) < 25 and made + len(batch) < count and tries < count * 20:
            tries += 1
            if 8 <= k < 8 + min(len(seed), count * 2 // 3):
                # first every position of the data file (as far as two thirds of the inputs reach) is changed
                # on its own, in a random order, so that no field is missed
                i = order[k - 8]
                b = bytearray(seed)
                b[i] ^= rng.randrange(1, 256)
                m = bytes(b)
            else:
                base = seed if k < 8 or rng.random() < 0.4 else rng.choice(corpus)
                m = mutate(base, rng, k, words, sweep)
            k += 1
            if m in seen:
                continue
            seen.add(m)
            batch.append(m)
        files = []
        for m in batch:
            made += 1
            files.append("m%04d.bin" % made)
            with open(os.path.join(d, files[-1]), "wb") as f:
                f.write(m)
        for f, sig in shapes(n, d, files).items():
            if sig not in shape_seen:
                shape_seen.add(sig)
                corpus.append(open(os.path.join(d, f), "rb").read())
        if not batch:
            break
    return made + 1


with concurrent.futures.ThreadPoolExecutor(max_workers=int(os.environ.get("DIFF_JOBS", "2"))) as ex:
    total = sum(ex.map(make, names))
print(f"{total} inputs")
PY

# ------------------------------------------------------------ 4. the build

built=()
if [ ${#dumped[@]} -gt 0 ]; then
   step "building the Ada dump programs"
   : > "$out/build.log"
   remaining=("${dumped[@]}")
   # One project with a main for every format. A format whose program does not compile stops the
   # linking of the others, so those are left out and the build is repeated for the rest.
   for attempt in 1 2 3 4; do
      mains=$(printf '"dump_%s.adb", ' "${remaining[@]}")
      dirs=$(printf '"gen/%s", "dump/%s", ' $(for n in "${remaining[@]}"; do echo "$n" "$n"; done))
      cat > "$out/diff.gpr" <<EOF
with "$here/kaitai_struct.gpr";
with "$here/kaitai_struct_files.gpr";

--  Generated by scripts/diff-python.sh: one main per format
project Diff is
   for Source_Dirs use (${dirs%, });
   for Object_Dir use "obj";
   for Exec_Dir use "bin";
   for Create_Missing_Dirs use "True";
   for Main use (${mains%, });

   package Compiler is
      for Default_Switches ("Ada") use ("-O1", "-g", "-gnat2012", "-gnata");
   end Compiler;
end Diff;
EOF
      # -k: keep going after errors; contracts of the library are checked, as in its own tests
      (cd "$out" && alr -C "$here" -n exec -- gprbuild -P "$out/diff.gpr" -p -k -j"$jobs" -XKAITAI_STRUCT_CONTRACTS=on) \
         > "$out/build.$attempt.log" 2>&1 || true
      cat "$out/build.$attempt.log" >> "$out/build.log"
      failing=$(grep -E '^[A-Za-z0-9_-]+\.ad[sb]:[0-9]+:[0-9]+: error' "$out/build.$attempt.log" | sed 's/\.ad[sb]:.*//' | sort -u || true)
      [ -n "$failing" ] || break
      next=()
      for n in "${remaining[@]}"; do
         bad=0
         for u in $failing; do
            if [ "$u" = "dump_$n" ] || [ -f "$out/gen/$n/$u.ads" ] || [ -f "$out/gen/$n/$u.adb" ]; then bad=1; fi
         done
         [ "$bad" -eq 1 ] || next+=("$n")
      done
      remaining=("${next[@]}")
      [ ${#remaining[@]} -gt 0 ] || break
   done
   for n in "${dumped[@]}"; do
      [ -x "$out/bin/dump_$n" ] && built+=("$n")
   done
fi
echo "${#built[@]} dump programs built"

# --------------------------------------- 5. the runs, comparison and report

step "running both programs on all inputs"
printf '%s\n' "${names[@]}" > "$out/names.txt"
printf '%s\n' "${dumped[@]}" > "$out/dumped.txt"
printf '%s\n' "${built[@]}" > "$out/built.txt"
printf '%s\n' "${KNOWN_DIFFERENCES[@]}" > "$out/known.txt"
"$py" -I - "$out" "$jobs" "$py" <<'PY'
import collections, concurrent.futures, os, re, shutil, subprocess, sys

out, jobs, py = sys.argv[1], int(sys.argv[2]), sys.argv[3]


def lines(name):
    p = os.path.join(out, name)
    return [l.rstrip("\n") for l in open(p) if l.strip()] if os.path.exists(p) else []


names = lines("names.txt")
dumped = set(lines("dumped.txt"))
built = set(lines("built.txt"))
known = [l.split("@@", 6) for l in lines("known.txt") if l.count("@@") >= 6]

status = {}
for n in names:
    p = os.path.join(out, "status", n)
    if os.path.exists(p):
        cls, detail = open(p).read().rstrip("\n").split("\t", 1)
        status[n] = (cls, detail)

# errors of the build, by format
build_log = open(os.path.join(out, "build.log"), errors="replace").read() if os.path.exists(os.path.join(out, "build.log")) else ""
errs = collections.defaultdict(list)
for line in build_log.splitlines():
    m = re.match(r"^([A-Za-z0-9_\-]+)\.(?:ads|adb):(\d+):(\d+): (error.*)$", line)
    if m:
        errs[m.group(1)].append(f"{m.group(1)}.ad?:{m.group(2)}: {m.group(4)}")
for n in names:
    if n in dumped and n not in built:
        units = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(out, "gen", n)) if f.endswith((".ads", ".adb"))} | {"dump_" + n}
        es = [e for u in sorted(units) for e in errs.get(u, [])]
        status[n] = ("build failed", " / ".join(es[:3]) or "see build.log")


def limit():
    # a repetition of billions of elements must not take the machine down: 3 GiB for each program
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (3 << 30, 3 << 30))


def run(cmd, cwd, timeout):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, timeout=timeout, preexec_fn=limit)
        return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or b"").decode("utf-8", "replace"), "timeout"


def parse(text):
    """sections of a program: file -> (kind, lines, why)"""
    res = {}
    cur = None
    for l in text.split("\n"):
        if l.startswith("@@ "):
            cur = l[3:]
            res[cur] = ["OK", [], ""]
        elif cur is None or l == "":
            continue
        elif l == "FAILED":
            res[cur][0] = "FAILED"
        elif l.startswith("EXCEPTION"):
            res[cur][0] = "EXCEPTION"
            res[cur][2] = l
        elif l.startswith("#why "):
            res[cur][2] = (res[cur][2] + " " + l[5:]).strip()
        else:
            res[cur][1].append(l)
    return {k: tuple(v) for k, v in res.items()}


def run_side(cmd_for, files, cwd):
    """Runs one program on all files; those it did not get to are run one at a time"""
    rc, so, se = run(cmd_for(files), cwd, 120)
    res = parse(so)
    # the last section of a program that died is incomplete
    if rc != 0 and files:
        done = [f for f in files if f in res]
        if done and rc != 0:
            res.pop(done[-1], None)
    for f in files:
        if f not in res:
            rc1, so1, se1 = run(cmd_for([f]), cwd, 20)
            r1 = parse(so1)
            if f in r1 and rc1 == 0:
                res[f] = r1[f]
            else:
                res[f] = ("NORESULT", [], f"rc={rc1} " + ("timeout" if rc1 == 124 else (se1.strip().splitlines() or [""])[-1][:100]))
    return res


def process(n):
    d = os.path.join(out, "inputs", n)
    files = sorted(os.listdir(d))
    ada = run_side(lambda fs: [os.path.join(out, "bin", "dump_" + n)] + fs, files, d)
    pyr = run_side(lambda fs: [py, os.path.join(out, "dump", n, "dump_" + n + ".py"), os.path.join(out, "py", n)] + fs, files, d)
    return n, files, ada, pyr


def norm(line):
    """path of a line without the numbers of elements"""
    return re.sub(r"\[\d+\]", "[]", line.split(" = ", 1)[0])


def classify(n, f, a, p):
    """-> (class, detail, first differing line)"""
    ak, al, aw = a
    pk, pl, pw = p
    if ak == "EXCEPTION":
        return "ada-exception", aw, ""
    if ak == "NORESULT":
        return "no-result", f"Ada: {aw}; Python: {pw}".strip(), ""
    if (pk == "NORESULT" and "timeout" in pw) or (pk == "FAILED" and pw.startswith("MemoryError")):
        # Python is slow or runs out of memory where Ada gives up early (a repetition of billions of empty elements)
        return "py-timeout", f"Ada: {ak}; Python: {pw}", ""
    if pk == "NORESULT":
        return "no-result", f"Ada: {aw}; Python: {pw}".strip(), ""
    if ak == "FAILED" and pk == "FAILED":
        if "dump too large" in aw and "dump too large" in pw:
            return "capped", "", ""
        return "same-failed", "", ""
    if ak == "FAILED":
        return "ada-fails", aw, ""
    if pk == "FAILED":
        return "py-fails", pw, ""
    if al == pl:
        return "same-ok", "", ""
    for i in range(max(len(al), len(pl))):
        x = al[i] if i < len(al) else "(end of the dump)"
        y = pl[i] if i < len(pl) else "(end of the dump)"
        if x != y:
            return "value", f"Ada: {x}  /  Python: {y}", f"line {i + 1}: Ada `{x}`, Python `{y}`"
    return "value", "", ""


def outside_s64(aw, plines):
    m = re.match(r"undefined (\S+)$", aw)
    if not m:
        return False
    for l in plines:
        path, _, value = l.partition(" = ")
        if path == m.group(1):
            try:
                return not -(1 << 63) <= int(value) < (1 << 63)
            except ValueError:
                return False
    return False


def known_id(n, cls, aw, pw, plines=()):
    for kid, kcls, kfmt, kada, kpy, why, check in known:
        if kcls == cls and re.fullmatch(kfmt, n) and re.search(kada, aw) and re.search(kpy, pw):
            if check == "outside-s64" and not outside_s64(aw, plines):
                continue
            return kid
    return None


work = sorted(built)
results = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as ex:
    for n, files, ada, pyr in ex.map(process, work):
        results[n] = (files, ada, pyr)

per = {}
groups = collections.OrderedDict()
known_counts = collections.Counter()
known_detail = collections.Counter()
known_why = {}
for n in work:
    files, ada, pyr = results[n]
    c = collections.Counter()
    leaves_seed = leaves = 0
    ok_ada = ok_py = 0
    for f in files:
        a, p = ada[f], pyr[f]
        cls, detail, first = classify(n, f, a, p)
        if a[0] == "OK":
            ok_ada += 1
        if p[0] == "OK":
            ok_py += 1
        if cls == "same-ok":
            leaves += len(a[1])
            if f == "seed.bin":
                leaves_seed = len(a[1])
        if cls in ("ada-fails", "py-fails", "value"):
            kid = known_id(n, cls, a[2], p[2], p[1]) if cls != "value" else None
            if kid is not None:
                c["known"] += 1
                known_counts[kid] += 1
                known_detail[(kid, n, re.sub(r"\d+", "N", (a[2] if cls == "ada-fails" else p[2]))[:90])] += 1
                continue
        c[cls] += 1
        if cls not in ("same-ok", "same-failed", "capped"):
            # inputs with the same cause are one group: the class, the path of the first difference and the reason
            if cls == "value":
                key = (n, cls, norm(first.split("Ada `")[1].split("`, Python")[0]) if "Ada `" in first else first)
            elif cls == "ada-fails":
                key = (n, cls, re.sub(r"\d+", "N", a[2]))
            elif cls == "py-fails":
                key = (n, cls, re.sub(r"\d+", "N", p[2])[:80])
            else:
                key = (n, cls, re.sub(r"\d+", "N", a[2] if cls == "ada-exception" else detail)[:80])
            g = groups.setdefault(key, {"files": [], "detail": detail, "first": first, "cls": cls})
            g["files"].append(f)
    per[n] = dict(c=c, files=len(files), leaves_seed=leaves_seed, leaves=leaves, ok_ada=ok_ada, ok_py=ok_py)

# the dumps of the differences
shutil.rmtree(os.path.join(out, "diffs"), ignore_errors=True)
for key, g in groups.items():
    n = key[0]
    files, ada, pyr = results[n]
    d = os.path.join(out, "diffs", n)
    os.makedirs(d, exist_ok=True)
    for f in g["files"]:
        base = f[:-4]
        a, p = ada[f], pyr[f]
        with open(os.path.join(d, base + ".ada"), "w") as fh:
            fh.write(a[0] + "\n" + a[2] + "\n" + "\n".join(a[1]) + "\n")
        with open(os.path.join(d, base + ".py"), "w") as fh:
            fh.write(p[0] + "\n" + p[2] + "\n" + "\n".join(p[1]) + "\n")
        shutil.copy(os.path.join(out, "inputs", n, f), os.path.join(d, f))

ncls = ["same-ok", "same-failed", "capped", "py-timeout", "known", "value", "ada-fails", "py-fails", "ada-exception", "no-result"]
label = {
    "same-ok": "same dump", "same-failed": "both fail", "capped": "dump over the limit", "py-timeout": "Python timeout or memory", "known": "known", "value": "values differ",
    "ada-fails": "only Ada fails", "py-fails": "only Python fails", "ada-exception": "Ada exception", "no-result": "no result",
}
tot = collections.Counter()
for n in work:
    tot.update(per[n]["c"])
bad_inputs = sum(tot[c] for c in ("value", "ada-fails", "py-fails", "ada-exception", "no-result"))
build_failed = [n for n in names if status.get(n, ("",))[0] == "build failed"]
skipped = [n for n in names if status.get(n, ("",))[0] == "skipped"]
allinputs = sum(per[n]["files"] for n in work)

with open(os.path.join(out, "results.md"), "w") as f:
    f.write("# Ada parsers against Python parsers of the same compiler\n\n")
    f.write(f"{len(names)} formats: {len(work)} compared, {len(skipped)} skipped, {len(build_failed)} failed to build.\n")
    f.write(f"{allinputs} inputs in all, {sum(per[n]['ok_ada'] for n in work)} parsed by Ada, {sum(per[n]['ok_py'] for n in work)} parsed by Python, ")
    f.write(f"{sum(per[n]['leaves'] for n in work)} leaves compared in inputs with the same dump.\n\n")
    f.write("| Class | Inputs |\n|---|---|\n")
    for c in ncls:
        f.write(f"| {label[c]} | {tot[c]} |\n")
    f.write(f"| total | {allinputs} |\n\n")
    if known_counts:
        f.write("## Known differences\n\n| Id | Inputs | Reason |\n|---|---|---|\n")
        for kid, _, _, _, _, why, _ in known:
            f.write(f"| {kid} | {known_counts[kid]} | {why} |\n")
        f.write("\nWhere they were found:\n\n| Id | Format | Failure | Inputs |\n|---|---|---|---|\n")
        for (kid, n, why), cnt in sorted(known_detail.items()):
            f.write(f"| {kid} | {n} | `{why}` | {cnt} |\n")
        f.write("\n")
    f.write("## Formats\n\n")
    f.write("| Format | Inputs | Ada ok | Python ok | Leaves (seed) | Leaves (all same) | same | known | different | exception | no result |\n|---|---|---|---|---|---|---|---|---|---|---|\n")
    for n in work:
        p = per[n]
        c = p["c"]
        diff = c["value"] + c["ada-fails"] + c["py-fails"]
        f.write(f"| {n} | {p['files']} | {p['ok_ada']} | {p['ok_py']} | {p['leaves_seed']} | {p['leaves']} | {c['same-ok'] + c['same-failed'] + c['capped']} | {c['known']} | {diff} | {c['ada-exception']} | {c['no-result']} |\n")
    f.write("\n## Skipped and failed formats\n\n| Format | Result | Reason |\n|---|---|---|\n")
    reasons = collections.Counter()
    for n in names:
        if n in status:
            cls, detail = status[n]
            f.write(f"| {n} | {cls} | {detail.replace('|', chr(92) + '|')} |\n")
    f.write("\n## Differences\n\n")
    if not groups:
        f.write("None.\n")
    for key, g in groups.items():
        n = key[0]
        files, ada, pyr = results[n]
        best = min(g["files"], key=lambda x: (os.path.getsize(os.path.join(out, "inputs", n, x)), x))
        data = open(os.path.join(out, "inputs", n, best), "rb").read()
        f.write(f"### {n}: {label[g['cls']]}: {g['first'] or g['detail']}\n\n")
        f.write(f"- inputs: {len(g['files'])} ({', '.join(g['files'][:6])}{', ...' if len(g['files']) > 6 else ''}), kept in `diffs/{n}/`\n")
        f.write(f"- smallest: `{best}`, {len(data)} bytes: `{data.hex() if len(data) <= 96 else data[:96].hex() + '...'}`\n")
        f.write(f"- Ada: {ada[best][0]} {ada[best][2]}; Python: {pyr[best][0]} {pyr[best][2]}\n\n")

print()
print(f"formats: {len(names)}, compared {len(work)}, skipped {len(skipped)}, build failed {len(build_failed)}")
print(f"inputs: {allinputs}; parsed by Ada {sum(per[n]['ok_ada'] for n in work)}, by Python {sum(per[n]['ok_py'] for n in work)}")
print(f"leaves compared (inputs with the same dump): {sum(per[n]['leaves'] for n in work)}")
for c in ncls:
    print(f"  {label[c]:18} {tot[c]:6}")
for kid, cnt in known_counts.items():
    print(f"    known {kid}: {cnt}")
for key, g in groups.items():
    print(f"  DIFF {key[0]}: {label[g['cls']]}: {(g['first'] or g['detail'])[:140]} ({len(g['files'])} inputs)")
for n in build_failed:
    print(f"  BUILD FAILED {n}: {status[n][1][:150]}")
open(os.path.join(out, "bad.count"), "w").write(str(bad_inputs + len(build_failed)))
PY
echo "results: $out/results.md"

bad=$(cat "$out/bad.count")
if [ "$bad" -gt 0 ] && [ "$no_fail" -eq 0 ]; then
   exit 1
fi
exit 0
