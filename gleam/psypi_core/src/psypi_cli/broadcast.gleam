// broadcast.gleam - Announcements (~30 lines)
// Small + Pure = Resilience!



pub type BroadcastError {
  DatabaseError(String)
  InvalidPriority(String)
}

pub fn broadcast(message: String, priority: String) -> Result(String, BroadcastError) {
  // Validate priority
  case priority {
    "low" | "normal" | "high" | "critical" -> Ok(Nil)
    _ -> Error(InvalidPriority("Invalid priority: " <> priority))
  }
  
  // TODO: Save to DB and broadcast
  Ok("Broadcast sent")
}

pub fn announce(message: String, priority: String) -> Result(String, BroadcastError) {
  broadcast(message, priority)
}
