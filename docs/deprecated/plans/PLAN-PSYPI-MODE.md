# Plan: Add `normal` and `minimal` modes to psypi

## Goal
Provide two operating modes for psypi so that it works out‑of‑the‑box with a 4 K‑token model (e.g. Qwen 3‑4B) while still supporting the full‑featured prompt for larger‑context models.

| Mode    | Prompt composition                                                                            |
|---------|---------------------------------------------------------------------------------------------|
| `normal`| Loads **all skills**, the full **AGENTS.md**, and the complete built‑in tool list.          |
| `minimal`| Skips **skills** and **AGENTS.md**, keeps only a minimal set of tools (`read`, `bash`).      |

The mode is stored in the Pi settings under the key `psypiMode` (`"normal"` | `"minimal"`).

---

## Steps

1. **Add a persistent setting**
   - Edit (or create) `~/.pi/agent/settings.json` and add:
   ```json
   {
     "psypiMode": "normal"
   }
   ```
   - Projects can override it locally by adding the same key to `.pi/settings.json`.

2. **Helper module to read the flag**
   - File: `src/psypi_mode.gleam`
   ```gleam
   import gleam/result.{Ok, Error}
   import gleam/json.{decode, encode}
   import gleam/string
   import pi "pi"
   import pi.settings.{SettingsManager}

   // Returns "normal" if the key is missing or malformed.
   pub fn current_mode(ctx: pi.ExtensionContext) -> String {
     let raw = ctx.settings.get("psypiMode") |> Result.from_option("")
     case raw {
       Ok(v) -> case decode(v, string) {
         Ok(mode) -> mode
         Error(_) -> "normal"
       }
       Error(_) -> "normal"
     }
   }
   ```
   - This module can be imported anywhere a `ExtensionContext` is available.

3. **Make the system‑prompt builder respect the mode**
   - Edit `src/extension_generator.gleam` (where the args for the runtime are built).
   - Add a small function that mutates the `Args` based on the mode:
   ```gleam
   import psypi_mode

   pub fn apply_mode(args: Args, ctx: pi.ExtensionContext) -> Args {
     let mode = psypi_mode.current_mode(ctx)
     case mode {
       "minimal" ->
         // Disable everything that blows the token budget.
         args
           |> Arg.set_no_skills(true)
           |> Arg.set_no_context_files(true)
           // Keep only a minimal tool whitelist.
           |> Arg.set_no_tools(true)
           |> Arg.set_tools(["read", "bash"]) // re‑enable the two we need
       _ ->
         // Normal mode – leave args untouched.
         args
     }
   }
   ```
   - In the `generate()` function (or wherever the `Args` are assembled before calling `pi.start`) call `apply_mode(args, ctx)`.

4. **Expose a slash‑command to switch modes on‑the‑fly**
   - Add a new command registration (e.g., in `src/commands.gleam`):
   ```gleam
   pi.registerCommand("mode", {
     description: "Switch between normal/minimal psypi modes",
     handler: fn(args, ctx) {
       let target =
         case List.head(args) {
           Some(v) -> v
           None    -> "normal"
         }
       // Persist the new mode in the settings file.
       SettingsManager.set("psypiMode", encode(target))
       ctx.ui.notify("psypi mode set to " <> target, "info")
       // Optionally trigger a reload so the change takes effect immediately.
       ctx