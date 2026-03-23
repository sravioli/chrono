# chrono Contributing Guide

Welcome to the chrono contributing guide, and thank you for your interest.

We accept the following types of contributions:

- **Source code** — bug fixes, new features, and improvements to the
  benchmarking engine, statistics, timer, or reporter modules. See [Environment
  setup](#environment-setup), [Best practices](#best-practices), and
  [Contribution workflow](#contribution-workflow).
- **Documentation** — improvements to the README, inline LuaLS annotations, or
  issue templates. See [Text formats](#text-formats).
- **Bug reports** — reproducible issues filed through the [bug report
  template](ISSUE_TEMPLATE/bug_report.md). See [Report issues and
  bugs](#report-issues-and-bugs).

At this time, we do not accept:

- Translations
- Social media or outreach contributions

## Overview

chrono is a zero-dependency benchmarking engine for **Lua 5.1** and
**LuaJIT 2.x**. It provides a library API for creating benchmark suites, a
CLI for running benchmark files, dual wall-clock / CPU timers, rich statistics,
and multiple output formats (text, pretty, JSON). See the
[README](readme.md) for full usage details.

## Ground rules

Before contributing, read our [Code of
Conduct](code_of_conduct.md) to learn more about our community guidelines and
expectations.

## Share ideas

To propose a new idea:

1. Check existing [issues](https://github.com/sravioli/chrono/issues) to avoid
   duplicates.
2. Open a new issue describing the idea, its motivation, and, if applicable, a
   rough implementation approach.
3. Wait for feedback from a maintainer before starting work.

## Before you start

Before contributing, ensure you have the following:

- A [GitHub account](https://docs.github.com/en/get-started/signing-up-for-github/signing-up-for-a-new-github-account)
- [Git](https://git-scm.com/) installed
- [Lua 5.1+](https://www.lua.org/) or [LuaJIT 2.x](https://luajit.org/)
  installed
- A C compiler (`cc`) — optional, for the native high-resolution timer
- [GNU Make](https://www.gnu.org/software/make/) — for building the C module
  and running common tasks
- [StyLua](https://github.com/JohnnyMorganz/StyLua) installed (for code
  formatting)
- [Luacheck](https://github.com/mpeterv/luacheck) installed (for static
  analysis)
- [Selene](https://kampfkarren.github.io/selene/) installed (for additional
  static analysis with custom Lua 5.1 + LuaJIT standard library)
- [Busted](https://lunarmodules.github.io/busted/) installed (for running tests)

## Environment setup

1. Fork the repository on GitHub.
2. Clone your fork:

   ```sh
   git clone https://github.com/<your-username>/chrono.git
   cd chrono
   ```

3. (Optional) Build the native high-resolution timer:

   ```sh
   make
   ```

4. Verify that StyLua runs without errors:

   ```sh
   stylua --check .
   ```

5. Run linters:

   ```sh
   luacheck lua/ cli.lua verify.lua bench/
   selene --display-style=quiet lua/ cli.lua verify.lua bench/
   ```

6. Run the test suite:

   ```sh
   busted
   ```

## Common tasks

```sh
# Build the native timer
make build

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

## Best practices

- **One concern per commit.** Keep commits focused on a single change.
- **Format before committing.** Run `stylua .` to format all Lua files.
  The project uses 2-space indentation, Unix (LF) line endings, double quotes,
  and omitted call parentheses where safe. See [`.stylua.toml`](../.stylua.toml)
  for the full configuration.
- **Keep `require` blocks sorted.** StyLua's `sort_requires` is enabled; let it
  handle ordering.
- **Annotate types.** LuaLS type annotations live inline in the source files
  under `lua/chrono/`. Update or add `---@class`, `---@field`, `---@param`, and
  `---@return` annotations when changing public APIs.
- **Pass all linters.** The project enforces a zero-warning policy with both
  [Luacheck](https://github.com/mpeterv/luacheck) and
  [Selene](https://kampfkarren.github.io/selene/) (using a custom
  `chrono_std.yml` standard library). Run both locally before submitting:

  ```sh
  stylua --check .     # or `stylua .` to auto-fix
  luacheck lua/ cli.lua verify.lua bench/
  selene --display-style=quiet lua/ cli.lua verify.lua bench/
  ```

- **Run the test suite.** Tests use [Busted](https://lunarmodules.github.io/busted/).
  Run `busted --verbose` before submitting changes. Add or update tests in
  `spec/` when modifying public behaviour.
- **Module organization.** Each top-level feature is a separate `.lua` file in
  `lua/chrono/`.

## Contribution workflow

### Fork and clone

See [Environment setup](#environment-setup). For a general guide on the
fork-and-branch workflow, read [Using the Fork-and-Branch Git
Workflow](https://blog.scottlowe.org/2015/01/27/using-fork-branch-git-workflow/).

### Report issues and bugs

Use the [bug report template](ISSUE_TEMPLATE/bug_report.md) to file issues.
Include your OS, Lua/LuaJIT version, chrono version or commit, relevant
code, and steps to reproduce the bug.

### Commit messages

This project uses [Conventional
Commits](https://www.conventionalcommits.org/) enforced by
[Cocogitto](https://docs.cocogitto.io/). Every commit message must follow the
format:

```text
<type>[(scope)]: <description>
```

**Standard types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`ci`, `build`, `revert`.

**Project-specific types:**

| Type      | Purpose                         | In changelog? |
| --------- | ------------------------------- | ------------- |
| `chore`   | Miscellaneous maintenance tasks | No            |
| `hotfix`  | Urgent bug fixes                | Yes           |
| `release` | Release bookkeeping             | Yes           |

Examples:

```text
fix(cache): handle nil TTL in compute()
feat(state): add async background writes
docs: update README usage section
chore: bump stylua config
```

### Branch creation

Create a descriptive branch from `main`:

```sh
git switch -c feat/my-new-feature main
```

Use the commit type as the branch prefix (e.g. `fix/`, `feat/`, `docs/`).

### Pull requests

1. Push your branch to your fork.
2. Open a pull request against `main` on
   [sravioli/chrono](https://github.com/sravioli/chrono).
3. Fill in a description of the changes and reference any related issues.
4. Ensure StyLua formatting passes (`stylua --check .`).
5. Ensure tests pass (`busted --verbose`).
6. A maintainer will review the PR. If you don't receive feedback within a
   reasonable time, leave a comment on the PR to request a review.

### Releases

Releases are automated. When a maintainer bumps the version with `cog bump`,
Cocogitto creates a SemVer tag and pushes it. A GitHub Actions workflow then
generates a changelog and publishes a GitHub release. Contributors do not need
to manage releases.

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

### Text formats

- **Source code** is written in Lua. Format with StyLua.
- **Documentation** (README, issue templates, contributing guide) is written in
  Markdown.

## Licensing

Code contributions are licensed under the [GNU General Public License
v2](../LICENSE). Documentation contributions are licensed under [Creative
Commons Attribution-NonCommercial 4.0 International](../LICENSE-DOCS).

---

> Template based on the [Contributing Guide
> template](https://thegooddocsproject.dev/) from The Good Docs Project.
