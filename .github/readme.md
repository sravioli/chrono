# chrono

[![Tests](https://img.shields.io/github/actions/workflow/status/sravioli/chrono/tests.yaml?label=Tests&logo=Lua)](https://github.com/sravioli/chrono/actions?workflow=tests)
[![Lint](https://img.shields.io/github/actions/workflow/status/sravioli/chrono/lint.yaml?label=Lint&logo=Lua)](https://github.com/sravioli/chrono/actions?workflow=lint)

A zero-dependency benchmarking engine for **Lua 5.1** and **LuaJIT 2.x**.

## Features

- **Library API** – create suites, add benchmarks, run and collect results
  programmatically.
- **CLI** – run benchmark files from the command line with configurable flags.
- **Dual timer** – wall-clock (high-resolution via FFI on LuaJIT) or CPU time
  via `os.clock()`, selectable per run.
- **Rich statistics** – mean, min/max, standard deviation, median, p95, p99,
  ops/sec.
- **Three output formats** – plain text, ANSI-colored pretty print, and
  machine-readable JSON.
- **GC control** – disable GC during measurement (`gc_off`) or force collection
  between benchmarks (`gc_collect`).
- **Randomization** – shuffle benchmark execution order to reduce ordering bias.
- **Out-of-process execution** – run each benchmark in an isolated child process.
- **Benchmark filtering** – skip benchmarks with user-defined or built-in filter
  functions.
- **JIT awareness** – optional JIT trace statistics collection and timer
  pre-compilation verification on LuaJIT.
- **Error isolation** – a failing benchmark reports an error without crashing the
  suite.

## Quick start

### Library usage

```lua
local chrono = require("chrono")

local suite = chrono.suite("My Suite", {
    iterations = 1000,
    warmup     = 100,
})

suite:add("string.rep", function()
    local _ = string.rep("x", 100)
end)

suite:add("concatenation", function()
    local s = ""
    for i = 1, 100 do s = s .. "x" end
end)

local results = suite:run()
chrono.report(results, "pretty") -- ANSI-colored output
-- chrono.report(results, "text") -- plain text
-- chrono.report(results, "json") -- machine-readable JSON
```

### Single benchmark

```lua
local chrono = require("chrono")

local result = chrono.run("quick test", function()
    local t = {}
    for i = 1, 100 do t[i] = i end
end, { iterations = 500 })

chrono.report(result, "text")
```

### CLI

```sh
lua cli.lua --file examples/cli_sample.lua \
    --iterations 500 --warmup 100 --format pretty
```

Run `lua cli.lua --help` for all flags.

## API reference

### `chrono.suite(name, opts) -> Suite`

Create a benchmark suite.

| Option             | Type     | Default | Description                           |
| ------------------ | -------- | ------- | ------------------------------------- |
| `iterations`       | number   | 100     | Measurement iterations per benchmark  |
| `warmup`           | number   | 0       | Warmup iterations (useful for JIT)    |
| `min_time`         | number   | 0       | Minimum measurement time in seconds   |
| `batch_size`       | number   | 1       | Calls per timed iteration             |
| `timer_source`     | string   | "wall"  | `"wall"` or `"cpu"`                   |
| `setup`            | function | nil     | Called before each iteration          |
| `teardown`         | function | nil     | Called after each iteration           |
| `gc_off`           | boolean  | false   | Disable GC during measurement         |
| `gc_collect`       | boolean  | false   | Force GC between suite benchmarks     |
| `randomize`        | boolean  | false   | Shuffle benchmark execution order     |
| `out_of_process`   | boolean  | false   | Run each benchmark in a child process |
| `collect_jitstats` | boolean  | false   | Collect JIT trace statistics (LuaJIT) |

### `Suite:add(name, fn [, opts]) -> Suite`

Add a benchmark case. Returns `self` for chaining. Per-benchmark `opts`
override suite defaults.

### `Suite:filter(fn) -> Suite`

Add a filter function. Returns `self` for chaining. The filter is called with
`(name, opts)` for each benchmark; if it returns `true, reason` the benchmark
is skipped.

```lua
suite:filter(function(name, opts)
    if name:match("^slow") then
        return true, "skipping slow benchmarks"
    end
end)
```

### `Suite:run([run_opts]) -> results`

Execute all benchmarks. `run_opts` override suite defaults (but not
per-benchmark overrides).

### `chrono.run(name, fn [, opts]) -> result`

Run a single benchmark outside a suite.

### `chrono.format(results, fmt) -> string`

Format results as `"text"`, `"pretty"`, or `"json"`.

### `chrono.report(results, fmt)`

Shortcut: format + print to stdout.

### `chrono.filters`

Built-in filter functions:

| Filter                       | Description                                       |
| ---------------------------- | ------------------------------------------------- |
| `chrono.filters.require_ffi` | Skip benchmarks that require FFI when unavailable |

### `chrono.devnull`

A no-op write sink with `devnull.write(...)` and `devnull.file` (a file-like
object). Useful for suppressing benchmark-produced output.

## Result schema

Each benchmark result contains:

| Field        | Type   | Description                         |
| ------------ | ------ | ----------------------------------- |
| `name`       | string | Benchmark display name              |
| `n`          | number | Number of measured samples          |
| `mean`       | number | Arithmetic mean (seconds)           |
| `stddev`     | number | Sample standard deviation (seconds) |
| `min`        | number | Fastest sample (seconds)            |
| `max`        | number | Slowest sample (seconds)            |
| `median`     | number | 50th percentile (seconds)           |
| `p95`        | number | 95th percentile (seconds)           |
| `p99`        | number | 99th percentile (seconds)           |
| `ops_sec`    | number | Operations per second (1 / mean)    |
| `total_time` | number | Total wall/cpu time spent (seconds) |
| `jitstats`   | table  | JIT trace events _(optional)_       |

If the benchmark errors, the result instead has an `error` field with the
message.

Suite results wrap individual results:

```lua
{
    suite_name      = "...",
    runtime         = "LuaJIT",      -- or "Lua"
    runtime_version = "LuaJIT 2.1.0-beta3",
    timer_source    = "QueryPerformanceCounter",
    benchmarks      = { result1, result2, ... },
    skipped         = { { name = "...", reason = "..." }, ... },  -- if any
}
```

> **Note:** `timer_source` is hoisted to the suite level since it is the same
> for all benchmarks in a run. For single-benchmark results from `chrono.run()`,
> `timer_source` remains on the result itself.

## CLI flags

| Flag               | Description                           | Default |
| ------------------ | ------------------------------------- | ------- |
| `--file <path>`    | Benchmark file to load (**required**) | –       |
| `--format <fmt>`   | `text`, `pretty`, or `json`           | text    |
| `--timer <src>`    | `wall` or `cpu`                       | wall    |
| `--iterations N`   | Measurement iterations                | 100     |
| `--warmup N`       | Warmup iterations                     | 0       |
| `--min-time S`     | Minimum measurement seconds           | 0       |
| `--batch-size N`   | Calls per timed iteration             | 1       |
| `--gc-off`         | Disable GC during measurement         | –       |
| `--gc-collect`     | Force GC between suite benchmarks     | –       |
| `--randomize`      | Randomize benchmark execution order   | –       |
| `--out-of-process` | Run each benchmark in a child process | –       |
| `--help`           | Print usage                           | –       |

The benchmark file must `return` a suite object.

## Timer sources

The engine auto-selects the best available timer in this priority order:

| Runtime | Priority | Mechanism                                         | Resolution |
| ------- | -------- | ------------------------------------------------- | ---------- |
| PUC Lua | 1        | `chrono.clock` C module                           | ~1 ns      |
| PUC Lua | 2        | `os.clock()` fallback                             | ~1 ms      |
| LuaJIT  | 1        | FFI (`QueryPerformanceCounter` / `clock_gettime`) | ~1–100 ns  |
| LuaJIT  | 2        | `os.clock()` fallback                             | ~1 ms      |

The `chrono.clock` C module is skipped on LuaJIT because FFI is preferred and
the C module may be compiled against an incompatible Lua ABI. Both wall-clock
and CPU-time timers follow this priority independently. The report header
always shows which timer backend was actually used.

### Building the native timer (optional)

The `chrono.clock` C module provides nanosecond-resolution timing on **any**
Lua version (5.1+), not just LuaJIT. It is optional — everything works without
it, just at lower timer resolution.

#### Linux / macOS

Requires Lua headers (`lua5.1-dev`, `lua5.4-dev`, etc.) and `pkg-config` or
LuaRocks for auto-detection:

```sh
make
# — or manually —
cc -O2 -shared -fPIC -I/usr/include/lua5.1 -o c/chrono/clock.so c/clock.c -lrt
```

#### Windows

Windows does not ship with a C compiler or `make`, so you need to install them
first. Pick **one** of the options below.

##### Option A — Zig (recommended, single download, no PATH pain)

1. Download the latest **zig** archive from <https://ziglang.org/download/> and
   extract it somewhere (e.g. `C:\zig`).
2. Add that folder to your `PATH`, or pass it directly to `make`:

   ```sh
   make -C c CC="zig cc"
   ```

   If your Lua headers are not found automatically, point the Makefile at them:

   ```sh
   make -C c CC="zig cc" LUA_INCDIR=C:/path/to/lua/include LUA_LIB=lua51
   ```

##### Option B — MSYS2 / MinGW-w64

1. Install [MSYS2](https://www.msys2.org/).
2. From the **MSYS2 UCRT64** shell, install the toolchain and `make`:

   ```sh
   pacman -S mingw-w64-ucrt-x86_64-gcc make
   ```

3. Run the build (from the MSYS2 shell):

   ```sh
   make -C c LUA_INCDIR=/path/to/lua/include LUA_LIB=lua51
   ```

##### Option C — MSVC (Developer Command Prompt)

Open a **Developer Command Prompt** or **Developer PowerShell** and compile
directly:

```sh
cl /O2 /LD c/clock.c /Ic:\path\to\lua\include lua51.lib /Fe:c/chrono/clock.dll
```

Replace `lua51` with the library name matching your Lua version.

#### Makefile variables

| Variable     | Default (auto-detected)     | Description                             |
| ------------ | --------------------------- | --------------------------------------- |
| `CC`         | `cc`                        | C compiler (`zig cc`, `gcc`, `cl`, …)   |
| `LUA_INCDIR` | via `pkg-config`/`luarocks` | Path to the Lua header directory        |
| `LUA_LIBDIR` | (empty on Unix)             | Path to the Lua library directory       |
| `LUA_LIB`    | `lua54` (Windows only)      | Lua library name to link (e.g. `lua51`) |

The Makefile builds the module into `c/chrono/` automatically; the `.busted`
config and `cli.lua` both set `package.cpath` to find it there.

## Reproducibility tips

- Pin CPU frequency / disable turbo boost for stable results.
- Close unnecessary background processes.
- Use `warmup` to let LuaJIT compile traces before measurement.
- Increase `iterations` or use `min_time` for very fast functions.
- Use `batch_size` for sub-microsecond operations to reduce clock granularity
  noise.
- Run benchmarks multiple times and compare across runs.

## Project structure

```
chrono/
├── cli.lua                       CLI entry point
├── verify.lua                    Timer detection sanity check
├── Makefile                      Top-level targets (delegates to c/)
├── c/
│   ├── Makefile                  Builds chrono.clock C module
│   └── clock.c                   Native high-resolution timer
├── lua/chrono/
│   ├── init.lua                  Main module & suite API
│   ├── runner.lua                Benchmark execution engine
│   ├── statistics.lua            Statistical computations
│   ├── timer.lua                 Timer abstraction (auto-detects best source)
│   ├── subprocess.lua            Out-of-process execution via io.popen
│   ├── devnull.lua               No-op write sink
│   ├── jitstats.lua              LuaJIT trace statistics collector
│   ├── jitutil.lua               JIT pre-compilation verification
│   └── reporters/
│       ├── text.lua              Plain-text reporter
│       ├── pretty.lua            ANSI-colored UTF-8 box-drawing reporter
│       └── json.lua              Machine-readable JSON reporter
├── examples/
│   ├── basic.lua                 Library usage example
│   └── cli_sample.lua            CLI usage example
└── spec/
    ├── smoke_spec.lua            End-to-end API tests
    └── stats_spec.lua            Statistics correctness tests
```

## Running the tests

Tests use [busted](https://lunarmodules.github.io/busted/). A `.busted` config
is included in the repository root.

```sh
busted
```

## Compatibility

- Lua 5.1.x, 5.2+, 5.4+ (syntax is 5.1-compatible)
- LuaJIT 2.0.5+
- No external Lua dependencies
- Optional: `chrono.clock` C module for high-resolution timing on plain Lua

## License

Code is licensed under the [GNU General Public License v2](../LICENSE). Documentation
is licensed under [Creative Commons Attribution-NonCommercial 4.0 International](../LICENSE-DOCS).
