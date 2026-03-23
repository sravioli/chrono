---
name: Bug report
about: Create a report to help us improve
title: "[BUG]"
labels: bug
assignees: sravioli
---

# Bug Report

> Please fill out the sections below. Sections marked _(optional)_ can be left
> blank if not applicable.
>
> Before submitting, check existing issues to make sure this bug hasn't already
> been reported.

## Summary (optional)

A brief description of the bug. 3–4 sentences recommended. If the issue title
already covers it, you can skip this section.

## Environment

- **OS**: (e.g. Windows 11, macOS 15.4, Ubuntu 24.04)
- **Lua runtime**: (e.g. Lua 5.1.5, LuaJIT 2.1.0-beta3)
- **chrono version/commit**: (e.g. `v1.0.0` or commit hash)
- **Timer source**: (e.g. `wall` / `cpu`, as shown in report header)

## Setup

Provide your chrono configuration and benchmark code so the issue can be
reproduced.

```lua
-- Example:
-- local chrono = require("chrono")
-- local suite = chrono.suite("test", { iterations = 1000 })
-- suite:add("bench", function() ... end)
-- local results = suite:run()
```

## Steps to reproduce

1. Step 1
2. Step 2
3. Step 3

## Observed behavior

Describe what actually happened. Avoid assumptions about the cause.

## Expected behavior (optional)

Describe what you expected to happen instead.

## Proof (optional)

Attach relevant output: benchmark results, error messages, stack traces, or
screenshots.

```text
-- paste logs or output here
```

## Configuration snippet (optional)

If the bug only appears with specific suite options, include the relevant
configuration.

```lua
-- paste config here
```

## Additional context (optional)

Any other details that might help: system load, GC settings, timer source,
LuaJIT compilation flags, etc.

---

> Template based on the [Bug Report template](https://thegooddocsproject.dev/)
> from The Good Docs Project.
