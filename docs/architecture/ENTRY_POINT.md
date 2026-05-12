# Entry Point: bin/psypi.mjs

## Overview

`bin/psypi.mjs` is the **hand-written Node.js entry point** for psypi. It bridges Gleam-compiled code with the Pi runtime.

## What is psypi?

**psypi = Psyche + Pi**

psypi is NOT dependent on Pi — it IS a Pi extension written in Gleam:
- **Pi**: The coding agent runtime (from `refers/pi/`)
- **psypi**: A Pi extension that adds:
  - Identity system (Worker/Monitor via `A-`/`S-` IDs)
  - SOUL-based personality storage in database
  - Monitor functionality (event-driven, autonomous)

## Relationship: Pi ⊂ psypi

```
┌─────────────────────────────────────────────────────────────┐
│                         psypi                                │
│                   (Pi Extension in Gleam)                    │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                       Pi                               │   │
│  │  (coding agent runtime from refers/pi/)              │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  + Identity system (A-/S- IDs)                             │
│  + SOUL in database                                         │
│  + Monitor hooks and tools                                  │
└─────────────────────────────────────────────────────────────┘
```

When you run `psypi`:
1. Loads Gleam code → generates `extension.js`
2. Spawns `pi -e extension.js`
3. Pi runs with psypi extension loaded

**`pi` vs `psypi`:**
- `pi` - bare Pi runtime, no psypi features
- `psypi` - Pi + psypi extension + Gleam tools + identity system

## Why Hand-Written?

Gleam compiles to ES modules (`.mjs`), not executable files. We need a Node.js entry point to:

1. Dynamically import Gleam-compiled modules
2. Generate `extension.js` at runtime
3. Spawn the Pi process with the generated extension

## Source Code

```javascript
#!/usr/bin/env node
// psypi entry point: generate extension.js from Gleam, then spawn Pi

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { writeFileSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Import the compiled Gleam generator
const { generate } = await import(
  join(__dirname, '../build/dev/javascript/psypi/extension_generator.mjs')
);

// Path to extension.js
const extensionPath = join(__dirname, '../extension.js');

// Step 1: Generate extension.js from Gleam PiToolCall values
const content = generate();
writeFileSync(extensionPath, content, 'utf8');

// Step 2: Spawn Pi with the generated extension
const piBin = 'pi';
const args = process.argv.slice(2);
const piArgs = ['-e', extensionPath, ...args];

const child = spawn(piBin, piArgs, {
  stdio: 'inherit',
  shell: false
});

child.on('close', (code) => {
  process.exit(code || 0);
});

child.on('error', (err) => {
  console.error('Failed to start Pi:', err.message);
  process.exit(1);
});
```

## Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    bin/psypi.mjs (Entry)                     │
│                      Hand-written Node.js                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 1: Import Gleam-compiled module                        │
│                                                              │
│  import { generate } from                                    │
│    '../build/dev/javascript/psypi/extension_generator.mjs'  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 2: Generate extension.js                               │
│                                                              │
│  const content = generate();                                 │
│  writeFileSync('extension.js', content);                     │
│                                                              │
│  This creates the Pi extension from:                         │
│  - All PiToolCall values (tools)                             │
│  - All PiEventHook values (event hooks)                      │
│  - All PiCommandReg values (slash commands)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 3: Spawn Pi process                                    │
│                                                              │
│  spawn('pi', ['-e', 'extension.js', ...args]);              │
│                                                              │
│  Passes through any command-line arguments to Pi.            │
└─────────────────────────────────────────────────────────────┘
```

## File Pipeline

```
src/extension_generator.gleam       (Gleam source)
         │
         ▼ gleam build
build/dev/javascript/psypi/         (Compiled output)
  extension_generator.mjs
         │
         ▼ bin/psypi.mjs imports and calls generate()
extension.js                        (Generated Pi extension)
         │
         ▼ pi -e extension.js
Pi runtime                          (Running with psypi tools)
```

## Key Design Decisions

### 1. Dynamic Import

```javascript
const { generate } = await import(
  join(__dirname, '../build/dev/javascript/psypi/extension_generator.mjs')
);
```

Uses dynamic `import()` because:
- Gleam compiles to ES modules
- Path is resolved at runtime
- Allows for flexible project structure

### 2. Generate at Runtime

```javascript
const content = generate();
writeFileSync(extensionPath, content, 'utf8');
```

`extension.js` is generated **every time** psypi starts because:
- Ensures latest code is always used
- No stale extension.js issues
- Single source of truth: Gleam code

### 3. Spawn Pi with Inherited I/O

```javascript
const child = spawn(piBin, piArgs, {
  stdio: 'inherit',
  shell: false
});
```

- `stdio: 'inherit'` - Pi's output goes directly to terminal
- `shell: false` - More secure, direct process spawn

## Path Convention

The import path must match the Gleam project name in `gleam.toml`:

```toml
name = "psypi"  # → build/dev/javascript/psypi/
```

If the project name changes, the path in `bin/psypi.mjs` must be updated.

## Related Files

| File                            | Purpose                                     |
| ------------------------------- | ------------------------------------------- |
| `src/extension_generator.gleam` | Gleam source for extension generator        |
| `src/pi_tool_call.gleam`        | PiToolCall, PiEventHook, PiCommandReg types |
| `extension.js`                  | Generated Pi extension (git-ignored)        |
| `gleam.toml`                    | Project name determines output path         |

## Common Issues

### Path Mismatch

If you see:
```
Error: Cannot find module '../build/dev/javascript/psypi/extension_generator.mjs'
```

Check:
1. `gleam.toml` has correct `name = "psypi"`
2. `gleam build` has been run
3. Path in `bin/psypi.mjs` matches project name

### Stale extension.js

If tools are missing after code changes:
1. `extension.js` is regenerated on every start
2. Ensure `gleam build` was run after changes
