import agent_identity_types.{type IdentityContext, type IdentityError, MissingSessionId}

pub fn generate_semantic_id(
  ctx: IdentityContext,
) -> Result(String, IdentityError) {
  let prefix = case ctx.is_idle {
    True -> "A"
    False -> "S"
  }

  let global_prefix = case ctx.global {
    True -> "G-"
    False -> ""
  }

  case ctx.model {
    "" -> Error(MissingSessionId)
    _ -> {
      let base =
        global_prefix
        <> prefix
        <> "-"
        <> ctx.project
        <> "-"
        <> ctx.source
        <> "-"
        <> ctx.model

      case ctx.thinking_level {
        "" -> Ok(base)
        tl -> Ok(base <> "-" <> tl)
      }
    }
  }
}
