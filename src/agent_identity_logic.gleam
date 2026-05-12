pub fn generate_semantic_id(
  autonomous: Bool,
  source: String,
  project: String,
  session_id: String,
  model: String,
) -> String {
  let prefix = case autonomous {
    True -> "A"
    False -> "S"
  }

  case autonomous, model, project {
    True, m, p if m != "" && p != "" -> {
      case session_id {
        "" -> prefix <> "-" <> m <> "-" <> p
        sid -> prefix <> "-" <> m <> "-" <> p <> "-" <> sid
      }
    }
    True, m, _ if m != "" -> prefix <> "-" <> m
    True, _, p if p != "" -> {
      case session_id {
        "" -> prefix <> "-" <> source <> "-" <> p
        sid -> prefix <> "-" <> source <> "-" <> p <> "-" <> sid
      }
    }
    True, _, _ -> prefix <> "-" <> source

    False, _, p if p != "" -> {
      case session_id {
        "" -> prefix <> "-" <> source <> "-" <> p
        sid -> prefix <> "-" <> source <> "-" <> p <> "-" <> sid
      }
    }
    False, _, _ -> {
      prefix <> "-" <> source <> "-unknown"
    }
  }
}
