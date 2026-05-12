import agent_identity_types.{MissingSessionId, type IdentityError}

pub fn generate_semantic_id(
  autonomous: Bool,
  source: String,
  project: String,
  session_id: String,
  model: String,
) -> Result(String, IdentityError) {
  let prefix = case autonomous {
    True -> "A"
    False -> "S"
  }

  case autonomous, model, project, session_id {
    _, _, _, "" -> Error(MissingSessionId)
    True, m, p, sid if m != "" && p != "" -> Ok(prefix <> "-" <> m <> "-" <> p <> "-" <> sid)
    True, m, _, sid if m != "" -> Ok(prefix <> "-" <> m <> "-" <> sid)
    True, _, p, sid if p != "" -> Ok(prefix <> "-" <> source <> "-" <> p <> "-" <> sid)
    True, _, _, sid -> Ok(prefix <> "-" <> source <> "-" <> sid)
    False, _, p, sid if p != "" -> Ok(prefix <> "-" <> source <> "-" <> p <> "-" <> sid)
    False, _, _, sid -> Ok(prefix <> "-" <> source <> "-" <> sid)
  }
}
