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
# Install from LuaRocks
luarocks install chrono

# Run benchmarks (auto-discovers bench/*_bench.lua)
chrono

# Or specify files explicitly
chrono --file bench/string_bench.lua --iterations 500 --warmup 100 --format pretty
```

Run `chrono --help` for all flags.

For terminal formats (`text` and `pretty`), chrono streams each benchmark
result as it completes. Use `--defer-print` to restore buffered output.
JSON output stays deferred so each suite remains a clean machine-readable
document. See [Installation](#installation) for setup.

## Installation

```sh
# Core library + CLI executable
luarocks install chrono

# Optional: native high-resolution timer (requires a C compiler)
luarocks install chrono-clock

# Windows with Zig: explicitly set compiler and linker
luarocks install chrono-clock CC="zig cc" LD="zig cc"

# Windows with MSYS2/MinGW: from the MSYS2 shell
# luarocks install chrono-clock
```

After installation, the `chrono` command is available system-wide (installed
into your LuaRocks bin directory, typically in your `PATH`).

## Configuration (`.chrono`)

chrono loads a `.chrono` file from the working directory if present. The format
is a Lua table returned from the file:

```lua
return {
  default = {
    ROOT       = { "bench/" },
    pattern    = "_bench",
    format     = "pretty",
    defer_print = false,
    iterations = 500,
    warmup     = 100,
  },
}
```

| Field          | Type   | Default      | Description                               |
| -------------- | ------ | ------------ | ----------------------------------------- |
| `ROOT`         | table  | `{"bench/"}` | Directories to search for benchmark files |
| `pattern`      | string | `"_bench"`   | Lua pattern matched against filenames     |
| `format`       | string | `"text"`     | Output format (`text`, `pretty`, `json`)  |
| `defer_print`  | bool   | `false`      | Buffer terminal output until suite end    |
| `iterations`   | number | 100          | Measurement iterations                    |
| `warmup`       | number | 0            | Warmup iterations                         |
| `timer_source` | string | `"wall"`     | `"wall"` or `"cpu"`                       |

All other suite options (`min_time`, `batch_size`, `gc_off`, `gc_collect`,
`randomize`, `out_of_process`) are also supported.

### Streaming Output

For `text` and `pretty` output formats, chrono streams each benchmark result
as it completes. This provides live feedback for long benchmark runs.

- **Default:** Streaming enabled (`defer_print = false`)
- **To buffer output:** Use `--defer-print` on CLI or `defer_print = true` in `.chrono`
- **JSON output:** Always deferred (buffered per-file) to maintain valid JSON documents

When streaming is active, chrono prints the suite header once, emits each
benchmark's statistics as it finishes, and then prints a summary line:

```
Benchmark Suite: My Suite
Runtime: Lua 5.1  |  Timer: os.clock()

  [1] string.rep
         mean    0.042 ms        min    0.038 ms      median    0.041 ms
       stddev    0.003 ms        max    0.051 ms         p95    0.048 ms
      ops/sec    23.81  K    samples        1000         p99    0.050 ms
        total   42.123 ms

  [2] concatenation
         ...

2 benchmark(s) | 0 error(s)
```

CLI flags override `.chrono` values. Each benchmark file must `return` a
suite object.

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

| Flag               | Description                                    | Default  |
| ------------------ | ---------------------------------------------- | -------- |
| `--lua <interp>`   | Re-run under a different interpreter           | –        |
| `--file <path>`    | Benchmark file to run (repeatable)             | –        |
| `--root <dir>`     | Root directory for discovery (repeatable)      | `bench/` |
| `--pattern <pat>`  | Lua filename pattern for discovery             | `_bench` |
| `--format <fmt>`   | Output format: `text`, `pretty`, or `json`     | `text`   |
| `--defer-print`    | Buffer `text`/`pretty` output per suite        | off      |
| `--no-defer-print` | Stream `text`/`pretty` output live _(default)_ | on       |
| `--timer <src>`    | `wall` or `cpu`                                | `wall`   |
| `--iterations N`   | Measurement iterations per benchmark           | 100      |
| `--warmup N`       | Warmup iterations before measurement           | 0        |
| `--min-time S`     | Minimum measurement seconds                    | 0        |
| `--batch-size N`   | Calls per timed iteration (for fast functions) | 1        |
| `--gc-off`         | Disable garbage collection during measurement  | –        |
| `--gc-collect`     | Force garbage collection between benchmarks    | –        |
| `--randomize`      | Randomize benchmark execution order            | –        |
| `--out-of-process` | Run each benchmark in a child process          | –        |
| `--help`           | Print usage information and exit               | –        |

**Switching runtimes:** `chrono --lua luajit` re-executes the entire CLI
under LuaJIT (or any other interpreter). This lets you compare Lua vs
LuaJIT results without separate installs.

**Auto-discovery:** When no `--file` arguments are given, chrono recursively
searches `--root` directories for `.lua` files matching `--pattern`
(default: `bench/*_bench.lua`). Each file must `return` a suite object.

## Timer sources

The engine auto-selects the best available timer in this priority order:

### Wall-clock timers

| Runtime | Priority | Mechanism                                         | Resolution |
| ------- | -------- | ------------------------------------------------- | ---------- |
| PUC Lua | 1        | `chrono.clock` C module                           | ~1 ns      |
| PUC Lua | 2        | `os.clock()` fallback (CPU time, not wall)        | ~1 ms      |
| LuaJIT  | 1        | FFI (`QueryPerformanceCounter` / `clock_gettime`) | ~1–100 ns  |
| LuaJIT  | 2        | `os.clock()` fallback (CPU time, not wall)        | ~1 ms      |

### CPU timers

| Runtime | Priority | Mechanism                                                                | Resolution |
| ------- | -------- | ------------------------------------------------------------------------ | ---------- |
| PUC Lua | 1        | `chrono.clock` C module (`CLOCK_PROCESS_CPUTIME_ID` / `GetProcessTimes`) | ~1 ns      |
| PUC Lua | 2        | `os.clock()` fallback                                                    | ~1 ms      |
| LuaJIT  | 1        | FFI (`GetProcessTimes` / `CLOCK_PROCESS_CPUTIME_ID`)                     | ~100 ns    |
| LuaJIT  | 2        | `os.clock()` fallback                                                    | ~1 ms      |

> **macOS note:** On macOS < 10.12, the C module uses `mach_absolute_time`
> instead of `clock_gettime` for wall-clock timing. On 10.12+, POSIX
> `clock_gettime(CLOCK_MONOTONIC)` is available and preferred.

The `chrono.clock` C module is skipped on LuaJIT because FFI is preferred and
the C module may be compiled against an incompatible Lua ABI. Both wall-clock
and CPU-time timers follow this priority independently. The report header
always shows which timer backend was actually used.

## Building the native timer (optional)

The `chrono.clock` C module provides nanosecond-resolution timing on **any**
Lua version (5.1+), not just LuaJIT. It is optional — everything works without
it, just at lower timer resolution.

### Linux / macOS

Requires Lua headers (`lua5.1-dev`, `lua5.4-dev`, etc.) and `pkg-config` or
LuaRocks for auto-detection. The included Makefile detects Lua headers via:

1. LuaRocks introspection (when available)
2. `pkg-config` (if installed)
3. Standard system paths (`/usr/include`, `/usr/local/include`)

```sh
make clock
# — or manually with explicit paths —
cc -O2 -shared -fPIC -I/usr/include/lua5.1 -o c/chrono/clock.so c/clock.c -lrt
```

### Windows

Windows does not ship with a C compiler or `make`, so you need to install them
first. After installing a compiler, build with explicit include/library paths:

#### Option A — Zig (recommended, single download, no PATH pain)

1. Download the latest **zig** archive from <https://ziglang.org/download/> and
   extract it to a convenient location (e.g. `C:\zig`).
2. Either add that folder to your `PATH`, or pass it directly to `make`:

   ```sh
   make clock CC="zig cc"
   ```

   If Lua headers are not auto-detected, specify them explicitly:

   ```sh
   make clock CC="zig cc" LUA_INCDIR=C:/path/to/lua/include LUA_LIB=lua51
   ```

#### Option B — MSYS2 / MinGW-w64

1. Install [MSYS2](https://www.msys2.org/).
2. From the **MSYS2 UCRT64** shell, install toolchain and make:

   ```sh
   pacman -S mingw-w64-ucrt-x86_64-gcc make
   ```

3. Build from the MSYS2 shell:

   ```sh
   make clock LUA_INCDIR=/path/to/lua/include LUA_LIB=lua51
   ```

#### Option C — MSVC (Developer Command Prompt)

Open a **Developer Command Prompt** or **Developer PowerShell** and compile
directly:

```sh
cl /O2 /LD c/clock.c /Ic:\path\to\lua\include lua51.lib /Fe:c/chrono/clock.dll
```

Replace `lua51` with the library name matching your Lua version.

### Makefile variables

| Variable     | Default (auto-detected)     | Description                             |
| ------------ | --------------------------- | --------------------------------------- |
| `CC`         | `cc`                        | C compiler (`zig cc`, `gcc`, `cl`, …)   |
| `LUA_INCDIR` | via `pkg-config`/`luarocks` | Path to the Lua header directory        |
| `LUA_LIBDIR` | (empty on Unix)             | Path to the Lua library directory       |
| `LUA_LIB`    | `lua54` (Windows only)      | Lua library name to link (e.g. `lua51`) |

The Makefile builds the module into `c/chrono/` automatically; `cli.lua`
sets `package.cpath` to find it there.

### Using with LuaRocks

When installing `chrono-clock` via LuaRocks on Windows, explicitly provide your
compiler and linker:

```sh
luarocks install chrono-clock CC="zig cc" LD="zig cc"
```

This ensures LuaRocks uses your chosen compiler (not the system default) and
links correctly with your Lua installation.

## Reproducibility tips

- Pin CPU frequency / disable turbo boost for stable results.
- Close unnecessary background processes.
- Use `warmup` to let LuaJIT compile traces before measurement.
- Increase `iterations` or use `min_time` for very fast functions.
- Use `batch_size` for sub-microsecond operations to reduce clock granularity
  noise.
- Run benchmarks multiple times and compare across runs.

## Contributing

### Running the tests

Tests use [busted](https://lunarmodules.github.io/busted/). A `.busted` config
is included in the repository root.

```sh
busted
```

The project also enforces code quality checks:

- **StyLua** — Code formatting (automatic style enforcement)
- **Luacheck** — Static analysis for common errors and style violations
- **Selene** — Static analyzer with custom Lua 5.1 + LuaJIT standard library
  (`chrono_std.yml`) to properly recognize jit, package.config, and other globals

All checks are run in CI on every push and pull request. To run locally:

```sh
stylua --check .     # or `stylua .` to auto-fix
luacheck lua/ cli.lua verify.lua bench/
selene --display-style=quiet lua/ cli.lua verify.lua bench/
```

### Development

#### Required tools

- Lua 5.1+ or LuaJIT 2.0+ (for running)
- cc (any C compiler for optional native timer)
- GNU Make (for building the C module)
- Busted (for tests): `luarocks install busted`

#### Common tasks

```sh
# Build the native timer
make clock

# Run all tests
make test

# Verify timer auto-detection
make verify

# Run specific linter
luacheck lua/chrono/

# Auto-format code
stylua .

# Clean build artifacts
make clean
```

#### Project conventions

- **Code style:** StyLua 2-space indentation, Unix line endings
- **Linting:** Luacheck + Selene with zero-warning policy
- **Testing:** Busted with 100% pass rate required
- **Module organization:** Each top-level feature is a separate .lua file in
  `lua/chrono/`

### Releasing to LuaRocks

The project publishes two packages to [LuaRocks](https://luarocks.org):

| Package        | Rockspec (dev)                | Rockspec (stable)                         |
| -------------- | ----------------------------- | ----------------------------------------- |
| `chrono`       | `chrono-scm-1.rockspec`       | `rockspecs/chrono-X.Y.Z-1.rockspec`       |
| `chrono-clock` | `chrono-clock-scm-1.rockspec` | `rockspecs/chrono-clock-X.Y.Z-1.rockspec` |

#### Dev uploads

Dev (`scm`) rockspecs live at the repository root. They are uploaded
automatically on every tagged push with `--force --skip-pack` (no `.src.rock`
artifact). This keeps the development channel always up-to-date.

#### Stable releases

Versioned rockspecs live in `rockspecs/`. When a tag matching the rockspec
version exists (e.g. tag `v1.0.0` matches `chrono-1.0.0-1.rockspec`), the
workflow:

1. Uploads the rockspec to LuaRocks.
2. Builds a `.src.rock` archive.
3. Uploads the `.src.rock` alongside the rockspec.

#### Release checklist

1. Create a versioned rockspec in `rockspecs/`:
   ```sh
   cp chrono-scm-1.rockspec rockspecs/chrono-1.0.0-1.rockspec
   ```
2. Edit the copy: set `version = "1.0.0-1"` and update `source.tag`.
3. Repeat for `chrono-clock` if the native timer changed.
4. Add the new paths to the `rockspecs` input in `.github/workflows/release.yaml`.
5. Commit, tag, and push:
   ```sh
   git tag v1.0.0
   git push --tags
   ```
6. The release workflow creates a GitHub release and then publishes both dev
   and stable rocks to LuaRocks in parallel.

#### Required secret

Add a repository secret named `LUAROCKS_API_KEY` containing your LuaRocks API
key. The workflow uses `--temp-key` to avoid persisting credentials.

## Compatibility

**Lua Versions:**

- Lua 5.1.x through 5.4.x (code written in 5.1-compatible syntax)
- LuaJIT 2.0.5+ (auto-detected and preferred for FFI-based timers)
- No external Lua dependencies for the core library

**Platforms:** Linux, macOS, Windows

**Tools & CI:**

- Build: GNU Make (required for native timer compilation)
- Tests: Busted test runner
- Linting: Luacheck (0 warnings target) and Selene (0 errors target)
- Code Formatting: StyLua (automatic formatting)
- Code Coverage: Luacov with Coveralls integration

**Optional:**

- `chrono.clock` C module for nanosecond-resolution timing on plain Lua
- FFI available on LuaJIT for high-resolution wall-clock and CPU timers

## License

Code is licensed under the [GNU General Public License v2](../LICENSE). Documentation
is licensed under [Creative Commons Attribution-NonCommercial 4.0 International](../LICENSE-DOCS).
