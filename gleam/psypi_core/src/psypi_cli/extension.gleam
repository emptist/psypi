// extension.gleam - Pi Extension (compiles to extension.mjs!)
// This is the Pi TUI extension with all psypi tools!
// Compiled to .mjs - Pi can load this!

import gleam/javascript/promise
import psypi_cli/agent_identity as agent_id
import psypi_cli/task
import psypi_cli/issue
import psypi_cli/skill
import psypi_cli/monitor_ai
import psypi_cli/learning
import psypi_cli/broadcast
import psypi_cli/areflect
import psypi_cli/inter_review as inter_review
import psypi_cli/db

// Tool registration function - called by Pi TUI
pub fn register_tools() {
  // Register all psypi tools for Pi TUI
  // This function will be called by the .mjs file
  // Each module exports its tool registration
  
  // Agent Identity tools
  agent_id.register_tools()
  
  // Task tools
  task.register_tools()
  
  // Issue tools
  issue.register_tools()
  
  // Skill tools
  skill.register_tools()
  
  // Monitor AI tools
  monitor_ai.register_tools()
  
  // Learning tools
  learning.register_tools()
  
  // Broadcast tools
  broadcast.register_tools()
  
  // Areflect tool
  areflect.register_tool()
  
  // Inter-review tools
  inter_review.register_tools()
}

// Main entry point for Pi extension
pub fn main() {
  register_tools()
}
