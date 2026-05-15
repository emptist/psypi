import agent_identity_types.{type IdentityError}

/// Generate a semantic agent ID from identity parameters.
///
/// ID format: (A|S)-source-project-model[-thinking_level]
///
/// Examples:
///   A-psypi-psypi-openrouter/owl-alpha-medium
///   S-psypi-psypi-openrouter/owl-alpha
///   A-psypi-psypi-anthropic/claude-opus-4-5-high
///
/// The model field comes from ctx.model.id (e.g. "openrouter/owl-alpha").
/// The thinking_level is optional — only appended when non-empty.
/// When model is empty, the ID falls back to source-project only.
pub fn generate_semantic_id(
  autonomous: Bool,
  source: String,
  project: String,
  model: String,
  thinking_level: String,
) -> Result(String, IdentityError) {
  let prefix = case autonomous {
    True -> "A"
    False -> "S"
  }

  // Build the base: prefix-source-project
  let base = prefix <> "-" <> source <> "-" <> project

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
