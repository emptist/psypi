# Pi UI Patterns

## Notification (fire-and-forget)

```typescript
ctx.ui.notify("Done!", "info");    // "info" | "warning" | "error"
```

## Selection Dialog

```typescript
const choice = await ctx.ui.select("Pick one:", [
  { value: "a", label: "Option A", description: "First option" },
  { value: "b", label: "Option B", description: "Second option" },
]);
// Returns value string or undefined if cancelled
```

## Confirmation

```typescript
const ok = await ctx.ui.confirm("Delete file?", "This cannot be undone");
// Returns boolean
```

## Text Input

```typescript
const name = await ctx.ui.input("Project name:", "my-project");
// Returns string or undefined if cancelled
```

## Multi-line Editor

```typescript
const text = await ctx.ui.editor("Edit config:", "default content");
// Returns string or undefined if cancelled
```

## Timed Dialog (auto-dismiss)

```typescript
const ok = await ctx.ui.confirm("Proceed?", "Auto-cancels in 5s", { timeout: 5000 });
// Returns false on timeout
```

## Custom Component (full TUI control)

```typescript
import { Text, Component } from "@earendil-works/pi-tui";

const result = await ctx.ui.custom<string>((tui, theme, keybindings, done) => {
  const text = new Text("Type a name, Enter to confirm", 1, 1);
  let buffer = "";

  text.onKey = (key) => {
    if (key === "return") { done(buffer); return true; }
    if (key === "escape") { done(""); return true; }
    if (key.length === 1) { buffer += key; text.setText(`Name: ${buffer}`); }
    return true;
  };

  return text;
});
```

## Overlay Modal (experimental)

```typescript
const result = await ctx.ui.custom<string>(
  (tui, theme, keybindings, done) => new MyModal({ onClose: done }),
  { overlay: true, overlayOptions: { anchor: "center", width: "60%" } }
);
```

## Status Bar / Widgets

```typescript
// Footer status (persistent until cleared)
ctx.ui.setStatus("my-ext", "Processing...");
ctx.ui.setStatus("my-ext", undefined); // Clear

// Widget above editor
ctx.ui.setWidget("my-widget", ["Line 1", "Line 2"]);
ctx.ui.setWidget("my-widget", undefined); // Clear

// Custom footer (replaces built-in)
ctx.ui.setFooter((tui, theme) => ({
  render(width) { return [theme.fg("dim", "Custom footer")]; },
  invalidate() {},
}));
ctx.ui.setFooter(undefined); // Restore built-in

// Terminal title
ctx.ui.setTitle("pi - my-project");
```

## Working Indicator (streaming)

```typescript
// Custom message during streaming
ctx.ui.setWorkingMessage("Analyzing codebase...");
ctx.ui.setWorkingMessage(); // Restore default

// Custom spinner frames
ctx.ui.setWorkingIndicator({
  frames: ["·", "•", "●", "•"],
  intervalMs: 120,
});
ctx.ui.setWorkingIndicator(); // Restore default
```

## Autocomplete Provider

```typescript
ctx.ui.addAutocompleteProvider((current) => ({
  async getSuggestions(lines, line, col, options) {
    const beforeCursor = (lines[line] ?? "").slice(0, col);
    const match = beforeCursor.match(/(?:^| )#([^\s#]*)$/);
    if (!match) return current.getSuggestions(lines, line, col, options);
    return {
      prefix: `#${match[1] ?? ""}`,
      items: issues.filter(i => i.startsWith(match[1])).map(i => ({
        value: i, label: i, description: `Issue ${i}`,
      })),
    };
  },
  applyCompletion(lines, line, col, item, prefix) {
    return current.applyCompletion(lines, line, col, item, prefix);
  },
  shouldTriggerFileCompletion(lines, line, col) {
    return current.shouldTriggerFileCompletion?.(lines, line, col) ?? true;
  },
}));
```

## Theme Colors

```typescript
theme.fg("toolTitle", text)  // Tool names
theme.fg("accent", text)     // Highlights
theme.fg("success", text)    // Green
theme.fg("error", text)      // Red
theme.fg("warning", text)    // Yellow
theme.fg("muted", text)      // Secondary
theme.fg("dim", text)        // Tertiary
theme.bold(text)
theme.italic(text)

// Syntax highlighting
import { highlightCode, getLanguageFromPath } from "@earendil-works/pi-coding-agent";
const highlighted = highlightCode(code, "typescript", theme);
```

## Safety Check for Non-Interactive Modes

```typescript
if (ctx.hasUI) {
  const ok = await ctx.ui.confirm("Proceed?", "Continue?");
  if (!ok) return;
}
// ctx.hasUI is false in print mode (-p) and JSON mode
```
