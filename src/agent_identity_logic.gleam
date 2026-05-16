import agent_identity_types.{type IdentityError}

/// Generate a semantic agent ID from identity parameters.
///
/// ID format: [G-](A|S)-source-project-model[-thinking_level]
///
/// Examples (project dir):
///   A-psypi-psypi-openrouter/owl-alpha-medium
///   S-psypi-psypi-openrouter/owl-alpha
///   A-psypi-psypi-anthropic/claude-opus-4-5-high
///
/// Examples (non-project dir, global context):
///   G-A-psypi-non-project-openrouter/owl-alpha
///   G-S-psypi-non-project-openrouter/owl-alpha
///
/// The model field comes from ctx.model.id (e.g. "openrouter/owl-alpha").
/// The thinking_level is optional — only appended when non-empty.
/// When model is empty, the ID falls back to source-project only.
/// When global=True, prepends "G-" to distinguish non-project contexts.
pub fn generate_semantic_id(
  autonomous: Bool,
  source: String,
  project: String,
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

  // Build the base: [G-]prefix-source-project
  let base = global_prefix <> prefix <> "-" <> source <> "-" <> project

  // Append model if available
  let with_model = case model {
    "" -> base
    m -> base <> "-" <> m
  }

  // Append thinking_level if available (only meaningful when model is present)
  case thinking_level {
    "" -> Ok(with_model)
    tl -> Ok(with_model <> "-" <> tl)
  }
}
