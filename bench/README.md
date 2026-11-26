# Benchmarks

Design decisions for the runtime are backed by measurements. This crate holds
the programs that produce them. Results and the conclusions drawn from them
are recorded in the issue tracker, because they depend on machine, compiler
and allocator.

## Running

Three scripts report different metrics:

```sh
./icount.sh [records] [max_payload]   # instructions executed, counted by Valgrind
./run.sh [records] [max_payload]      # wall-clock time and resident memory
target/run.sh [rts ...]               # instructions executed on a simulated STM32F4
```

All build three variants first. They need Alire; the compilers are fetched by
Alire on the first build. `icount.sh` also needs Valgrind, `target/run.sh`
needs Renode. In a Claude Code cloud session `.claude/hooks/session-start.sh`
installs all of them.

**Instruction counts are the primary metric.** They repeat to within 0.1
instructions per record, so small differences are meaningful, and they need no
hardware performance counters, which virtual machines often lack. They cover
user-space code only: cache misses, page faults and work done in the kernel do
not show up. `icount.sh` gets the cost of one phase as the difference between
two runs that stop at successive phases.

**Wall-clock time is the second metric**, for exactly the effects instruction
counts miss. Timings on a shared machine vary by 10 to 20 percent between
runs, and occasionally more between sessions. Run `run.sh` several times and
only trust differences well above that.

When the two metrics disagree, find out why before drawing a conclusion. One
case found so far: a pool that returns its memory to the operating system
after every run pays for page faults again on the next run, which hides most
of its advantage in time but not in instructions.

| Mode | Switches | Meaning |
|---|---|---|
| `checked` | `-O2` | run-time checks on, no inlining across units |
| `inlined` | `-O2 -gnatn` | run-time checks on |
| `proven` | `-O2 -gnatn -gnatp` | checks suppressed, as after proving their absence |

## `stream_bench`: stream designs

Parses fixed 15-byte records (`u1`, `u2le`, `u4le`, `u8be`) and reports
nanoseconds per record.

| Variant | Design |
|---|---|
| `cursor_sticky` | stream is a cursor, buffer passed to each read, failure sets a flag |
| `pointer_sticky` | stream holds a pointer to the buffer, failure sets a flag |
| `cursor_status` | as `cursor_sticky`, each read returns a status the caller checks |
| `cursor_raise` | as `cursor_sticky`, failure raises an exception |
| `block_check` | size of the whole record checked once, then decoding at fixed offsets |
| `kaitai` | the library: `Kaitai.Streams`, field by field |
| `kaitai_block` | the library: one check per record, then `Kaitai.Decoding` at fixed offsets |

The first five are hand-written designs that were compared before the library
was written. The last two measure the library itself, so that it can be held
against the design it implements.

The parsing loops are in `src/stream_runs.adb` and are shared with the target
benchmark.

## `parse_bench`: library operations against hand-written code

Usage: `parse_bench [records] [repetitions] [variant]`. Holds operations of the
library against code that does the same job directly on the buffer with a
plain index, written the way a careful C programmer would. Each measurement
models generated code: the parser of one record is a procedure that is not
inlined, takes the buffer as `in` and the stream as `in out` parameter, and is
called from a loop in `src/stream_runs.adb`, which also forms the checksum.
Variants of one group read the same data and must agree on the checksum;
`parse_bench` fails if they do not. `icount.sh` and `target/run.sh` report
instructions per record, with the cost of generating the input taken off as
with the stream designs. The input is made by `src/bench_data.adb`, which the
target program uses as well.

| Group | Records | Variants |
|---|---|---|
| `term` | two zero-terminated strings of 0 to 12 bytes, a `u2le` | `kaitai_term`: `Read_Bytes_Term`, `Read_U2le` through the stream parameter; `kaitai_term_local`: the same on a local copy of the stream; `term_classic`: hand-written scan |
| `contents` | 4 bytes magic, a `u4le` | `kaitai_contents`: `Read_Contents`; `kaitai_contents_local`: the same on a local copy; `contents_classic`: compares the bytes, then decodes |
| `substream` | `u1` length N (4 to 16), N bytes of which a `u2le` and a `u1` are read | `kaitai_substream`: `Substream`, a parser of the body, `Join`, all through the stream parameter; `kaitai_substream_local`: the same, both parsers on local copies; `substream_classic`: explicit bounds, a parser of the body |
| `nested_copy` | 4 nested types of one `u1` each | `nested_local`: the parser of the record and that of the nested type copy the stream; `nested_outer_only`: only the parser of the record does; `nested_direct`: neither does |
| `fields<N>` | N `u1` (N = 1, 2, 3, 4, 8), read by one parser per record; N bytes of a buffer shared by all N | `fields<N>_local`: the parser copies the stream; `fields<N>_direct`: it reads through the parameter |
| `status<N>` | N `u1` (N = 1, 4, 8), the input and checksum of `fields<N>_direct` | `status<N>_sticky`: `Stream_Variants.Cursor_Sticky`, no check in the parser, the loop checks the flag; `status<N>_returned`: `Stream_Variants.Cursor_Status`, the parser checks the status after each read, returns early and reports it |
| `generated_*` | the formats of the groups `fields4`, `term` and `nested` as `formats/bench_*.ksy`, parsed by the code the compiler generates (`generated/`, made by `generate.sh`) | `generated_fields4`, `generated_term`, `generated_nested`: one generated `Parse` per record, the checksum from the accessors of the result; compare with `fields4_direct`, `kaitai_term` and `nested_direct` |
| `bits_flat`, `bits_le`, `bits_mixed`, `bits_nested` | records of bit fields, 4 bytes each (3 for `bits_nested`): `b3 b5 b12 b12` in big endian order (`flat`) and in little endian order (`le`), `b4 b4 u1 u2le` (`mixed`), and `u1` followed by a nested type of `b4 b4 b8` (`nested`); formats in `formats/bench_bits_*.ksy`, loops in `src/bit_runs.adb` | `bits_<format>_v1`: the generated `Parse`, which begins with `Align_To_Byte`; `_v2`: the same without that call (`src/bench_bits_<format>_v2.adb`); `_v3`: the body entered through `if Bits_Left (S) = 0`, the same reads in both branches; `_v3a`: as `_v3`, the branch for 0 calls `Align_To_Byte` first; `_v4`: hand-written with whole-byte reads and shifts (`src/bench_bits_hand.adb`). The records are aligned at run time in all variants; only what the compiler can know differs |
| `calls` | 4 calls of a nested parser that reads 2 `u1`; the outer parser reads nothing itself; 8 bytes | `calls_both_local`: both copy the stream; `calls_inner_local`: the outer parser passes it on, the nested one copies; `calls_direct`: neither copies |
| `xor_one`, `xor_many`, `rotate` | a record of 64 bytes processed into a 64-byte array of the package, four bytes of which enter the checksum | `kaitai_xor_one` (key `16#5A#`), `kaitai_xor_many` (5-byte key), `kaitai_rotate` (left by 3) against `xor_one_classic`, `xor_many_classic_mod` (key index by `mod`), `xor_many_classic_counter` (key index counted along and wrapped), `rotate_classic` |

`scripts/check.sh bench` runs it over all variants.

## `param_bench`: where a value from outside lives

Usage: `param_bench [records] [children] [variant] [phase]`. A child type needs a value that is not its own: a
parameter or the value of `_parent`. Today only integers, booleans and enumerations can come in (they are
parameters of `Parse` and are kept in `T`); the compiler rejects the rest. The variants hold hand-written parsers in
the style of generated code and answer where a string, a value of a user type or a stream should live. They are the
formats in `formats/outside/` (rejected by the compiler for exactly this reason), each with a parent of N children
that all need the value:

| Variant | The value of the parent is | Child accessors | Parsers |
|---|---|---|---|
| V1 | a parameter of the child's `Parse`, kept in the child's `T` | find it in `T` | `pstr_v1`, `puser_v1`, `pnav_v1` |
| V2 | a parameter of the child's `Parse`, not kept | take it as a parameter again from the caller | `pstr_v2`, `puser_v2`, `pnav_v2` |
| V2w | as V2 | the parent has an accessor that gives the value itself (`Items_Is_Key`) | `pstr_v2w`, `puser_v2w` |
| V3 | reduced by the compiler to what the child uses (`puser_v3`: the two integers `Parent_Hdr_Width` and `Parent_Hdr_Height`; `pnav_v3`: the truth of `_parent.s1 == 'foo'`), kept in `T` | find it in `T` | `puser_v3` is the parser the compiler generates today for `formats/bench_puser_v3.ksy`; `pnav_v3` is written by hand |

| Format | Parent | Child needs |
|---|---|---|
| `pstr` | a string of 4 bytes, N, N strings of 4 bytes | `key`, a string parameter: its length (`size: key.length`) and the comparison `body == key` |
| `puser` | `width` and `height` (`u2le`), N, N children | `hdr`, a parameter of the user type `header`: `hdr.height` as a size and `x < hdr.width and y < hdr.height` |
| `pnav` | `"foo\|"` or `"bar\|"`, N, N children | `_parent.s1`, a string of the parent: `if: _parent.s1 == 'foo'` and the instance `_parent.s1 == 'foo'` |

`phase` says how far a run goes, which is how a cost is told from the cost of the part before it: 1 parses the
parents (`Parse` of the parent walks the N children once), 2 also walks the children with the cursor (`Next`) and reads
a field of each that needs nothing from outside, 3 also reads what needs the value; 0 parses nothing. `icount.sh` and
`target/run.sh` print the cost of `Parse` per parent and of `Next` and of the access per child. The variants of a
format must agree on the checksum of every phase; `param_bench` fails if they do not. `param_bench 1 1 sizes` prints
the sizes of the types of the child and the parent in bytes. The parsers and the loops are in `src/pstr_v*.ad?`,
`src/puser_v*.ad?`, `src/pnav_v*.ad?`, `src/param_runs.adb` (the data in `src/param_data.adb`); `target/` has one
program, `target_param`, that takes variant, N and phase from the unit `Target_Param_Config`, which `target/run.sh`
writes for each measurement (`PARAM_DIR`).

`outside_proof/outside_proof.gpr` is for GNATprove: the parsers and the callers in `src/outside_callers.ads` that walk
a parent and read each child. It is not a benchmark and no part of `scripts/check.sh`.

```sh
cd outside_proof && alr exec -- gnatprove -P outside_proof.gpr --no-subprojects --level=1
```

## `arith_bench`: protection against overflow in expressions

Usage: `arith_bench [records] [variant]`. Parses the records of `stream_bench`
and computes two expressions from each, `c * b + a - 7` and `d * b + c`. The
types show that the first cannot overflow. The second does not overflow for
the input used, which the compiler cannot know.

| Variant | Design |
|---|---|
| `plain` | no protection; what protection costs is measured against this |
| `guarded` | `Kaitai.Arithmetic`: a function per operation tells whether it would overflow, and the parser asks before it computes |
| `guarded_where_needed` | the same, but only for the expression whose types do not rule out an overflow |
| `checked` | a value carries a validity flag that the operators hand on |
| `flagged` | a procedure per operation with a flag that stays false after an overflow |

## `repeat_bench`: expressions that use the elements of a repetition

Usage: `repeat_bench [elements] [repetitions] [variant] [none]`. A generated parser does not keep the elements of a
repetition whose elements have a variable size; `Next` and `Get_X` parse them again. This group measures what an
expression that is evaluated while parsing, and that needs an element, costs on top of that, and what the cheaper forms
cost that the compiler could generate for some shapes of expression. The compiler rejects such expressions today
(`formats/unsupported/rep_*.ksy` are the descriptions, with the error the compiler gives). The generated parts are
`Bench_Rep` (an element is `len : u1`, `name : len bytes`, `v : u1`; `formats/bench_rep.ksy`), `Bench_Rep_Fixed` (the
elements are `u1`, which is what the compiler supports today; `Index_Fixed`) and `Bench_Rep_Empty` (elements that may
read nothing, `formats/bench_rep_empty.ksy`). The parsers of `src/rep_use.ads` are written by hand in the style of
generated code over them; the loops that stand for the `Parse` of the parent are in `src/rep_runs.adb`, which is in SPARK
and is proven with the parsers (`kaitai_bench_prove.gpr`). The input of N elements is made by `src/rep_data.adb`. A
program parses it `repetitions` times (default 1) and prints a checksum; variants of one group must agree, and the
program fails if they do not. `icount.sh` gets the cost of one run as the difference between 9 runs and 1 run, divided by
8, in mode `proven` only.

| Variant | What a run does |
|---|---|
| `a_parse` | `Bench_Rep.Parse` of the input: the elements are walked once |
| `a_get_first`, `a_get_mid`, `a_get_last` | `a_parse`, then `Get_Items` for the element 0, N / 2, N - 1 |
| `a_next_all`, `a_get_all` | `a_parse`, then all elements with `Next`, and with `Get_Items` in a loop |
| `index_mod`, `index_get`, `index_fixed_mod`, `index_fixed` | N references `idx : u4`, `tag : size items[idx].len` after the elements. `index_get`: `Bench_Rep.Get_Items (idx)` for the size; `index_mod`: the size is `idx mod 8`, which is the same number, without access; `index_fixed`: the elements are `u1` and `Bench_Rep_Fixed.Items (idx)` decodes one from the buffer; `index_fixed_mod`: as `index_mod` for those elements |
| `last_eos`, `last_get`, `last_kept` | `tail : size items.last.len` after the elements. `last_get`: `Get_Items (N - 1)`; `last_kept`: `Parse` keeps the last element in the value (`Last_Kept`); `last_eos`: the same bytes read as `size-eos`, without access |
| `prev_naive`, `prev_carried` | `links[_index - 1].len` as the size of a field of the element `links[_index]`, in the repetition `links` itself. `prev_naive`: the element parser finds the one before with `Get_Naive`; `prev_carried`: the loop hands the `len` of the element before on, as a parameter, and the cursor of `Next` carries it. Both run `Parse` and then `Next` over all elements |
| `other_get`, `other_lockstep` | `items[_index - 1].len` as the size of a field of the element `blocks[_index]`, a repetition of its own. `other_get`: `Get_Items (_index - 1)`; `other_lockstep`: the loop goes through `items` alongside and hands the `len` of the element before on |
| `index_worst` | the input that costs most for its size: N elements of 2 bytes, then N / 4 references of 4 bytes, each to the last element; `index_get` on it |
| `empty_parse`, `empty_get`, `empty_get_stop` | a 5-byte input with a count of N and elements that read nothing: `Parse` (which stops at the first element that read nothing), `Get_Items (N - 1)` of the generated parser, and the same where `Get_Stop` stops there as well (`src/rep_empty.adb`) |

`prev_naive` takes 2 ** N parses and is run for N up to 16 only. `target/run_rep.sh` runs the group on the simulated
STM32F4.

## `instance_bench`: instances with a position that `seq` needs

Usage: `instance_bench [records] [variant] [none]`. The compiler rejects an expression of `seq` that uses an instance
with a position (`formats/unsupported/bench_inst_*.ksy`). Two ways to generate it are compared. D1: the instance is
parsed again at every use, in `Parse` where the expression needs it and in the accessor procedure as today. D2: it is
parsed once at its first use in `Parse` and kept in the value; the accessor is a function that returns it. The packages
`Bench_Inst_*_D1` and `_D2` in `src/` are written by hand from what the compiler generates for the same description
without the use (`formats/bench_inst_*.ksy`, `generated/`), in the style of generated code. Records of 18 to 68 bytes are
parsed one by one, each from a stream of its own over a slice of the buffer (`src/inst_data.adb`), by the loops of
`src/inst_runs.adb`, which are in SPARK and are proven with the parsers (`kaitai_bench_prove.gpr`).

| Description | The use | Instance |
|---|---|---|
| `int` | `chunks` has `num_chunks` elements (8 chunks of two `u4`) | `num_chunks`, a `u4` at the position size - 4 |
| `user` | `numbers` has `header.qty` elements, `entries` ends at `_ == header.limit` | `header`, a type of `qty : u2`, `limit : s2`, `tag : 2 bytes` (a slice) at size - 6 |
| `until` | only `entries` ends at `_ == header.limit`, so the first use is in the loop | `header` as above; D2 asks `Has_Header` in every turn |

`int_d1_parse` and `int_d2_parse` parse the record and read everything in `seq`; the `_access` variants then ask for the
instance four times through the accessor, so that the cost of one access is a quarter of the difference. Variants of one
group agree on the checksum. `icount.sh` gets the cost of one record as the difference between 1100 and 100 records,
divided by 1000. `target/run_inst.sh` runs the group on the simulated STM32F4 and prints the size of the value of each
variant, which is also what `T'Object_Size` says.

## `float_bench`: asking whether a floating point operation is defined

Usage: `float_bench [records] [variant]`. Parses records of 15 bytes
(`x: f8le`, `y: f4le`, `n: u2le`, `k: u1`), whose floats are finite and between
2**(-20) and 2**20 in magnitude, and computes from `x` and `y` with the operators of
Ada and with the functions of `Kaitai.Float_Arithmetic`, which ask first. The parser of
a record is not inlined and takes the stream as a parameter, as in `arith_bench`. A
variant of an operation that asks is held against the one that does not; both must
give the checksum, which `scripts/check.sh bench` verifies. Every variant of an operation mixes `x`, `y` and the
result into the checksum, and `nop` parses, converts and mixes `x`, `y` and `x` again,
so that a variant minus `nop` is the cost of the operation, and a guarded variant
minus the plain one is the cost of asking.

| Variant | Computes per record |
|---|---|
| `add_plain`, `add_guarded` | `x + y`, `y` converted to `F64`, with `Add_OK` first in the second |
| `add_lit_plain`, `add_lit_guarded` | `x + 0.05` |
| `sub_plain`, `sub_guarded` | `x - y` |
| `mul_plain`, `mul_guarded` | `x * y` |
| `to_i_plain`, `to_i_guarded` | `x.to_i`; the plain one is hand-written with `Floor` and `Ceiling`, the other asks `Truncate_OK` first |
| `expr_plain`, `expr_guarded` | the four expressions `x + 0.05`, `x * y`, `y * y + 1.0`, `x.to_i` |
| `expr_guarded_where_needed` | the same, but `y * y + 1.0` is not asked, since `y` is an f4 and cannot make it overflow |

On a target a `Long_Float` operation is a call of the soft-float library, so that
the programs for `target/` show the cost of an operation that the host does not.

## `target/`: the stream designs on a low-end target

A crate of its own that cross-compiles the stream benchmark for an STM32F4
(Cortex-M4) and runs it in Renode. The simulator counts the instructions
exactly, so this shows what a design costs on a 32-bit microcontroller rather
than on the development machine.

```sh
target/run.sh                                   # light run-time library
target/run.sh light-stm32f4 embedded-stm32f4    # both profiles
```

`light-stm32f4` is the profile the zero-copy variant of the generated code has
to run on; `embedded-stm32f4` is the smallest one the heap variant may assume.
`cursor_raise` is left out because a light run-time library has no exception
propagation. The program prints through semihosting, so no peripheral setup is
needed.

## `memory_bench`: memory management strategies

Parses records of `tag: u1`, `len: u2le`, `payload: len bytes` and keeps the
result in different ways. Reported per strategy: build, traverse and teardown
in nanoseconds per record, picking a random element in nanoseconds per access,
and resident memory per record in bytes.

| Strategy | Storage |
|---|---|
| `lazy` | nothing stored, records re-parsed on access |
| `index_arena` | array provided up front, payload as slice into the input |
| `index_owned` | as above, payload copied into a byte buffer provided up front |
| `vector_values` | growable heap array of nodes |
| `vector_reserved` | heap array of nodes with capacity known before parsing |
| `ada_vector` | `Ada.Containers.Vectors` of nodes |
| `ptr_malloc` | one heap object per node |
| `ptr_pool` | one object per node from a bump allocator (user-defined storage pool) |
| `ptr_pool_kept` | as above, the pool keeps its memory between runs |
| `ptr_subpool` | one object per node from an Ada 2012 subpool |
| `owned_malloc` | node and payload copy as separate heap objects |
| `owned_pool` | node and payload copy from the bump allocator |
| `owned_pool_kept` | as above, the pool keeps its memory between runs |
| `owned_subpool` | node and payload copy from an Ada 2012 subpool |

Each strategy runs in its own process, so the memory figure is not influenced
by the strategy before it. The figure is taken after building; a growable
array needs more than that while it grows.

## Coding style

The style is shared by all projects of the repository and defined in
`../kaitai_style.gpr`: lines of at most 120 characters, layout by `gnatformat`,
comments in GNAT style (`--` followed by two spaces), and casing checked by the
compiler.

```sh
alr exec -- gnatformat -P kaitai_bench.gpr           # format
alr exec -- gnatformat -P kaitai_bench.gpr --check   # verify, for CI
```

`gnatformat` comes from Alire: `alr install gnatformat_bin`, then add
`~/.alire/bin` to `PATH`. Style violations show up as warnings during the
build.
