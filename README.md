# machbb — mach, but better

Written in GNU Guile for software freedom.

A modern replacement for Firefox's `mach` build tool, built for Acreedom (GNU IceCat fork).

## Usage

```
Usage: machbb COMMAND [ARGS...]

Commands:
  init DIR        Initialize a project with mozconfig and patches/
  bootstrap       Install build dependencies
  configure       Configure the build
  build [TARGET]  Build the project
  package         Package the build output
  run [ARGS]      Run the built browser
  clean           Clean build artifacts
  status          Show build status and environment
```

## Requirements

- GNU Guile 3.0+
- Firefox/IceCat source tree

Part of the [AcreetionOS](https://acreetionos.org) project.
