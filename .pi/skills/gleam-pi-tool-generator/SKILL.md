---
name: gleam-pi-tool-generator
description: Expert guidance for defining Pi tools using Gleam PiToolCall types and the extension generator. Use when adding new Pi tools, modifying existing tools, or understanding how Gleam types compose into extension.js. Covers the PiToolCall type, generator architecture, and how Gleam writes JS text.
---

<essential_principles>
## Core Architecture

### Pi Extension Cannot Be Compiled From Gleam
Pi requires a specific JS structure: `export default function(pi) { pi.registerTool({...}) }`.
Gleam **cannot** compile directly to this — Pi won't accept `.gleam` or `.mjs` as an extension.
A **manual bridge** file (`extension.js`) is required.

### The Generator Is a Cook, Not a Code Generator
The generator does NOT construct JS objects. It **composes text**:
1. Gleam types (`PiToolCall`) carry tool metadata
2. Gleam functions (`to_js_text`, `to_import_line`) convert that metadata to JS text strings
3. The generator concatenates all text into `extension.js`
4. Every ingredient is validated by `gleam build` before composition

### Two Sources of JS Text
1. **Compiled `.mjs` files** — Gleam functions compiled to JS, read for import paths
2. **`PiToolCall.to_js_text()`** — Gleam function that converts a PiToolCall value into a JS source text string

### Everything Is Text
The generator writes JavaScript source code as strings. Never constructs JS objects.
`extension.js` is a build artifact — generated, never hand-edited.
If an AI edits `extension.js` manually, the Gleam compiler won't catch it.
That's why nothing should bypass the generator.
</essential_principles>

<quick_start>
## Quick Start: Add a New Pi Tool

1. **Define the Gleam function** (e.g., in `my_module.gleam`)
2. **Create a `PiToolCall` value** in that module (e.g., `my_tool()`)
3. **Import it in the generator** (`extension_generator.gleam`)
4. **Add it to `all_tools()` list**
5. **Run `gleam build && gleam run -m psypi_cli/extension_generator`**
6. **`extension.js` is auto-generated**
</quick_start>

<intake>
What do you want to do?

1. Add a new Pi tool
2. Modify an existing tool's PiToolCall
3. Understand the generator architecture
4. Debug generation issues
5. Something else

**Wait for response before proceeding.**
</intake>

<routing>
| Response | Next Action |
|----------|-------------|
| 1, "new tool", "add tool" | Read `references/pi-toolcall-type.md`, then `workflows/add-new-tool.md` |
| 2, "modify", "change tool" | Read `references/pi-toolcall-type.md`, then `workflows/modify-tool.md` |
| 3, "architecture", "how it works" | Read `references/architecture.md` |
| 4, "debug", "broken" | Read `workflows/debug-generation.md` |
| 5, other | Clarify |
</routing>

<reference_index>
## Domain Knowledge

All in `references/`:

| File | Purpose |
|------|---------|
| pi-toolcall-type.md | PiToolCall type definition, fields, helpers |
| result-format.md | ResultFormat variants (RawJson, Template, CustomJs) |
| fn-arg.md | FnArg variants (JsLiteral, FromParam) |
| architecture.md | Generator architecture, text composition flow, path handling |
| type-mapping.md | Gleam types → how they compile to JS objects |
</reference_index>

<workflows_index>
## Workflows

All in `workflows/`:

| File | Purpose |
|------|---------|
| add-new-tool.md | Step-by-step: add a new Pi tool |
| modify-tool.md | Step-by-step: change an existing tool |
| debug_generation.md | Debug generator or build failures |
</workflows_index>

<success_criteria>
- New tool defined as `PiToolCall` value in its Gleam module
- Tool imported in `extension_generator.gleam` and added to `all_tools()`
- `gleam build` succeeds (validates all types)
- `gleam run -m psypi_cli/extension_generator` produces valid `extension.js`
- All tools use Gleam types, never hand-edited JS
</success_criteria>
