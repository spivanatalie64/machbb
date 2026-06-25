# machbb — mach, but better

**Maintainer:** Natalie (AcreetionOS)  
**Language:** GNU Guile — for software freedom.  
**Part of:** [AcreetionOS](https://acreetionos.org)

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

## Train on yourself

```bash
./train.sh
```

Collects git history, writing samples, and shell history into a training dataset for fine-tuning a language model on your personal style.

## About

This repository was scaffolded with assistance from an AI agent. The agent's configuration, prompts, and operational knowledge are documented in `.opencode/agents/` — these files explain what the agent is, how it operates, and how to customize it for your own use. The agent is designed to be transparent about its role and capabilities.
