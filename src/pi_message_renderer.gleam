// pi_message_renderer.gleam — Pi message renderer registration
//
// Generates JS code to register custom message renderers for the Pi extension.

import gleam/list
import gleam/string

/// Generate the autonomic-wakeup message renderer registration
pub fn autonomic_wakeup_renderer() -> String {
  [
    "  // Register custom renderer for A-agentbot (autonomic) wake-up messages",
    "  pi.registerMessageRenderer('autonomic-wakeup', (message, options, theme) => {",
    "    const { expanded } = options;",
    "    let text = theme.fg('accent', '[A-agentbot] ');",
    "    text += theme.fg('warning', message.content);",
    "    if (expanded && message.details) {",
    "      text += '\\n' + theme.fg('dim', JSON.stringify(message.details, null, 2));",
    "    }",
    "    return new Text(text, 0, 0);",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
