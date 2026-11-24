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
