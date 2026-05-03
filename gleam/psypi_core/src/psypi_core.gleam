// psypi_core.gleam - Core Gleam module for psypi
// Type-safe, functional core logic

import gleam/string

// Session ID types
pub type SessionID {
  SessionID(value: String)
}

// Agent ID types  
pub type AgentID {
  AgentID(value: String, prefix: String)
}

// Create a new session ID with validation
pub fn new_session_id(uuid: String) -> Result(SessionID, String) {
  case string.length(uuid) {
    len if len >= 32 -> Ok(SessionID(value: uuid))
    _ -> Error("Invalid UUID: must be at least 32 characters")
  }
}

// Parse agent ID from string (format: PREFIX-value, value can contain hyphens)
pub fn parse_agent_id(id: String) -> Result(AgentID, String) {
  case string.split(id, "-") {
    [prefix, .._rest] -> Ok(AgentID(value: id, prefix: prefix))
    _ -> Error("Invalid agent ID format: expected PREFIX-value")
  }
}

// Validate session ID is from Pi TUI
pub fn is_valid_pi_session(id: SessionID) -> Bool {
  let SessionID(value: uuid) = id
  // UUID v7 starts with timestamp bits, but for simplicity check length
  string.length(uuid) >= 32
}

// Format agent ID for display
pub fn format_agent_id(agent: AgentID) -> String {
  let AgentID(value: id, prefix: p) = agent
  p <> ":" <> id
}

// Utility: join strings with delimiter
pub fn join_strings(strings: List(String), delimiter: String) -> String {
  string.join(strings, delimiter)
}
