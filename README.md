# machbb — mach, but better

**Maintainer:** Natalie (AcreetionOS)  
**Language:** GNU Guile — for software freedom.  
**Part of:** [AcreetionOS](https://acreetionos.org)

A modern replacement for Firefox's `mach` build tool, built for **Acreedom** (GNU IceCat fork) and **AcreetionOS**.

## Quick Start

```bash
# Initialize a new project
machbb init my-project acreedom

# Fetch the source
machbb fetch acreedom

# Install dependencies
machbb bootstrap

# Configure the build
machbb configure

# Build with all cores
machbb build -j $(nproc)

# Run what you built
machbb run
```

## Usage

```
Usage: machbb COMMAND [OPTIONS...] [ARGS...]

Core Commands:
  init [DIR] [NAME] [SOURCE]  Initialize a build project
  fetch [TYPE] [DEST]         Download Firefox/IceCat source code
  bootstrap [list|status]     Install build dependencies
  configure [OPTIONS...]      Configure the build with mozconfig
  build [-j N] [TARGETS...]   Build the project

Testing & Quality:
  test [SUITE]                Run tests
  lint [--fix]                Run linter
  check                       Verify build configuration

Package & Run:
  package                     Package the build output
  run [ARGS...]               Run the built browser

Maintenance:
  clean [--all]               Remove build artifacts
  status                      Show build status and environment
  env                         Show/set build environment variables
  profile [list|NAME]         List or apply build profiles
  patches                     Manage patches

Options:
  -j, --jobs N     Number of parallel jobs
  -q, --quiet      Suppress command output
  -n, --dry-run    Show what would be done
```

## Requirements

- **GNU Guile 3.0+** — the build tool itself
- **Python 3** — for Firefox's mach build system
- **Rust / Cargo** — for Firefox build
- **C/C++ toolchain** — clang, llvm, etc.
- A Firefox/IceCat/Acreedom source tree

## Features

- ✅ **Single-command builds** — `machbb build` just works
- ✅ **Auto-dependency management** — detects your package manager (apt/pacman/dnf)
- ✅ **Multi-profile support** — release, debug, profile builds
- ✅ **Smart parallel builds** — auto-detects core count
- ✅ **Patch management** — organized patches/ directory
- ✅ **Source fetching** — download Firefox/IceCat/Acreedom source
- ✅ **Build status dashboard** — see everything about your build at a glance
- ✅ **Dry-run mode** — see what would happen without doing it

## Build Profiles

```bash
machbb profile list          # List available profiles
machbb profile release       # Optimized release build
machbb profile debug         # Debug build with symbols
machbb profile profile       # Optimized with debug symbols
```

## Project Structure

```
my-project/
├── mozconfig            # Build configuration
├── patches/             # Your custom patches
│   └── *.patch
├── machbb.env           # Environment variables
├── .machbb-root         # Project root marker
├── acreedom/            # Firefox/IceCat source (after fetch)
└── obj-acreedom/        # Build output
```

## Architecture

machbb is written entirely in **GNU Guile Scheme**, organized as Guile modules:

- `machbb/cli.scm` — Command-line interface and dispatch
- `machbb/config.scm` — Project initialization, mozconfig management, profiles
- `machbb/build.scm` — Build, configure, test, clean, status
- `machbb/bootstrap.scm` — Dependency installation, environment setup
- `machbb/util.scm` — Utilities, colors, command execution, spinner

### Why GNU Guile?

- **Software freedom** — Guile is the GNU Project's official extension language
- **Scheme simplicity** — powerful macros, hygienic, elegant
- **Embeddable** — if Firefox ever moves to Guile for build, we're ready
- **Fast enough** — compiled to bytecode or native via Guile's JIT

## Train on yourself

```bash
./train.sh
```

Collects git history, writing samples, and shell history into a training dataset
for fine-tuning a language model on your personal style.

## License

MIT License — see [LICENSE](LICENSE)
