import agent_identity_types.{type IdentityError, MissingSessionId}

/// Generate a semantic agent ID from identity parameters.
///
/// ID format: [G-](A|S)-project-model[-thinking_level]
///
/// Examples (project dir):
///   A-tools_ai-openrouter/owl-alpha
///   S-tools_ai-openrouter/owl-alpha
///   A-tools_ai-anthropic/claude-opus-4-5-high
///
/// Examples (non-project dir, global context):
///   G-A-non-project-openrouter/owl-alpha
///   G-S-non-project-openrouter/owl-alpha
///
/// The model field comes from ctx.model.id (e.g. "openrouter/owl-alpha").
/// The thinking_level is optional — only appended when non-empty.
/// When global=True, prepends "G-" to distinguish non-project contexts.
pub fn generate_semantic_id(
  autonomous: Bool,
  project: String,
  source: String,
  model: String,
  thinking_level: String,
  global: Bool,
) -> Result(String, IdentityError) {
  let prefix = case autonomous {
    True -> "A"
    False -> "S"
  }

  // Prepend G- for global (non-project) context
  let global_prefix = case global {
    True -> "G-"
    False -> ""
  }

  // Model is required — without it the ID is meaningless
  case model {
    "" -> Error(MissingSessionId)
    _ -> {
      // Build the base: [G-]prefix-project-provider-model
      let base = global_prefix <> prefix <> "-" <> project <> "-" <> source <> "-" <> model

      // Append thinking_level if available
      case thinking_level {
        "" -> Ok(base)
        tl -> Ok(base <> "-" <> tl)
      }
    }
  }
}
