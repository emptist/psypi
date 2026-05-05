// skill_loader.gleam - Skill loading utilities (pure functions!)
// Small + Pure = Resilience!
//
// IMPORTANT: Gleam types MUST mirror TypeScript types exactly!
// This Skill type matches TypeScript StoredSkill in DatabaseSkillLoader.ts
// Field names and types must be identical for seamless JSON conversion.
//
// CORRECTIONS from TS (mistakes we fix in Gleam):
// - scan_status: Use ScanStatus type instead of String
// - status: Use SkillStatus type instead of String  
// - source: Use SkillSource type instead of String
//
// Learned patterns from ../refers/gleam:
// - Use gleam/list for filtering and searching
// - Use pattern matching for validation
// - Use recursive functions for list processing

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/string
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/order.{type Order, Gt, Lt, Eq}

/// Skill source - CORRECTS TS string type
/// TS uses: source: 'clawhub' | 'local' | 'generated' | 'imported' | 'ai-built'
pub type SkillSource {
  ClawHub
  Local
  Generated
  Imported
  AiBuilt
}

/// Convert string to SkillSource (for DB decoding)
pub fn string_to_source(s: String) -> SkillSource {
  case s {
    "clawhub" -> ClawHub
    "local" -> Local
    "generated" -> Generated
    "imported" -> Imported
    _ -> AiBuilt  // Default fallback
  }
}

/// Skill status - CORRECTS TS string type  
/// TS uses: status: 'pending' | 'approved' | 'rejected' | 'blocked' | 'installed' | 'uninstalled'
pub type SkillStatus {
  SkillPending
  Approved
  Rejected
  Blocked
  Installed
  Uninstalled
}

/// Convert string to SkillStatus (for DB decoding)
pub fn string_to_skill_status(s: String) -> SkillStatus {
  case s {
    "approved" -> Approved
    "rejected" -> Rejected
    "blocked" -> Blocked
    "installed" -> Installed
    "uninstalled" -> Uninstalled
    _ -> SkillPending
  }
}

/// Scan status - CORRECTS TS string type
/// TS uses: scan_status: 'pending' | 'clean' | 'suspicious' | 'malicious' | 'reviewed'
pub type ScanStatus {
  ScanPending
  Clean
  Suspicious
  Malicious
  Reviewed
}

/// Convert string to ScanStatus (for DB decoding)
pub fn string_to_scan_status(s: String) -> ScanStatus {
  case s {
    "clean" -> Clean
    "suspicious" -> Suspicious
    "malicious" -> Malicious
    "reviewed" -> Reviewed
    _ -> ScanPending
  }
}

/// Decoder for SkillSource (converts string to SkillSource)
pub fn skill_source_decoder() -> decode.Decoder(SkillSource) {
  decode.string
  |> decode.map(string_to_source)
}

/// Decoder for SkillStatus (converts string to SkillStatus)
pub fn skill_status_decoder() -> decode.Decoder(SkillStatus) {
  decode.string
  |> decode.map(string_to_skill_status)
}

/// Decoder for ScanStatus (converts string to ScanStatus)
pub fn scan_status_decoder() -> decode.Decoder(ScanStatus) {
  decode.string
  |> decode.map(string_to_scan_status)
}

/// Full Skill decoder (for decoding DB rows into Skill type)\npub fn skill_decoder() -> decode.Decoder(Skill) {\n  use id <- decode.field("id", decode.string)\n  use project_id <- decode.field("project_id", decode.optional(decode.string))\n  use name <- decode.field("name", decode.string)\n  use description <- decode.field("description", decode.optional(decode.string))\n  use instructions <- decode.field("instructions", decode.optional(decode.string))\n  use manifest <- decode.field("manifest", decode.dynamic)\n  use source <- decode.field("source", skill_source_decoder())\n  use external_id <- decode.field("external_id", decode.optional(decode.string))\n  use version <- decode.field("version", decode.string)\n  use author <- decode.field("author", decode.optional(decode.string))\n  use tags <- decode.field("tags", decode.list(decode.string))\n  use trigger_phrases <- decode.field("trigger_phrases", decode.list(decode.string))\n  use anti_patterns <- decode.field("anti_patterns", decode.list(decode.string))\n  use quick_start <- decode.field("quick_start", decode.optional(decode.string))\n  use examples <- decode.field("examples", decode.list(decode.string))\n  use emoji <- decode.field("emoji", decode.optional(decode.string))\n  use category <- decode.field("category", decode.optional(decode.string))\n  use content <- decode.field("content", decode.dynamic)\n  use safety_score <- decode.field("safety_score", decode.int)\n  use scan_status <- decode.field("scan_status", scan_status_decoder())\n  use verified <- decode.field("verified", decode.bool)\n  use status <- decode.field("status", skill_status_decoder())\n  use permissions <- decode.field("permissions", decode.list(decode.string))\n  use is_enabled <- decode.field("is_enabled", decode.bool)\n  use use_count <- decode.field("use_count", decode.int)\n  use rating <- decode.field("rating", decode.float)\n  use downloads <- decode.field("downloads", decode.int)\n  use last_used_at <- decode.field("last_used_at", decode.optional(decode.string))\n  use installed_at <- decode.field("installed_at", decode.optional(decode.string))\n  use created_at <- decode.field("created_at", decode.string)\n  use updated_at <- decode.field("updated_at", decode.string)\n  use builder <- decode.field("builder", decode.optional(decode.string))\n  use maintainer <- decode.field("maintainer", decode.optional(decode.string))\n  use embedding <- decode.field("embedding", decode.optional(decode.list(decode.float)))\n\n  decode.success(Skill(\n    id:, project_id:, name:, description:, instructions:,\n    manifest:, source:, external_id:, version:, author:,\n    tags:, trigger_phrases:, anti_patterns:, quick_start:,\n    examples:, emoji:, category:, content:, safety_score:,\n    scan_status:, verified:, status:, permissions:,\n    is_enabled:, use_count:, rating:, downloads:,\n    last_used_at:, installed_at:, created_at:, updated_at:,\n    builder:, maintainer:, embedding:,\n  ))\n}

/// Skill record type - MUST match TypeScript StoredSkill field names!
/// But we CORRECT the mistake of using String for status/source/scan_status
/// Following task.gleam pattern: use custom types for better type safety
/// See: src/kernel/services/DatabaseSkillLoader.ts
pub type Skill {
  Skill(
    id: String,
    project_id: Option(String),
    name: String,
    description: Option(String),
    instructions: Option(String),
    manifest: Dynamic,  // JSONB in DB
    source: SkillSource,  // CORRECTED: was String in TS
    external_id: Option(String),
    version: String,
    author: Option(String),
    tags: List(String),
    trigger_phrases: List(String),
    anti_patterns: List(String),
    quick_start: Option(String),
    examples: List(String),
    emoji: Option(String),
    category: Option(String),
    content: Dynamic,  // JSONB in DB
    safety_score: Int,
    scan_status: ScanStatus,  // CORRECTED: was String in TS
    verified: Bool,
    status: SkillStatus,  // CORRECTED: was String in TS
    permissions: List(String),
    is_enabled: Bool,
    use_count: Int,
    rating: Float,
    downloads: Int,
    last_used_at: Option(String),
    installed_at: Option(String),
    created_at: String,
    updated_at: String,
    builder: Option(String),
    maintainer: Option(String),
    embedding: Option(List(Float)),
  )
}

/// Filter approved and enabled skills
/// (Pure function - no side effects!)
/// Now uses SkillStatus type (corrected from TS string)
pub fn filter_approved_skills(
  skills: List(Skill),
) -> List(Skill) {
  list.filter(skills, fn(skill) {
    skill.status == Approved && skill.is_enabled && skill.safety_score >= 70
  })
}

/// Search skills by name (case-insensitive)
/// Uses gleam/string patterns learned from stdlib
pub fn search_skills_by_name(
  skills: List(Skill),
  search_term: String,
) -> List(Skill) {
  let search_lower = string.lowercase(search_term)
  
  list.filter(skills, fn(skill) {
    let name_lower = string.lowercase(skill.name)
    string.contains(name_lower, search_lower)
  })
}

/// Find skill by name (returns first match)
/// Uses recursive search (gleam/list doesn't have find())
pub fn find_skill_by_name(
  skills: List(Skill),
  name: String,
) -> Option(Skill) {
  let name_lower = string.lowercase(name)
  find_by_name_loop(skills, name_lower)
}

/// Recursive helper for find_skill_by_name
fn find_by_name_loop(
  skills: List(Skill),
  name_lower: String,
) -> Option(Skill) {
  case skills {
    [] -> None
    [skill, ..rest] -> {
      let skill_name_lower = string.lowercase(skill.name)
      case skill_name_lower == name_lower {
        True -> Some(skill)
        False -> find_by_name_loop(rest, name_lower)
      }
    }
  }
}

/// Filter skills by tag
pub fn filter_skills_by_tag(
  skills: List(Skill),
  tag: String,
) -> List(Skill) {
  list.filter(skills, fn(skill) {
    list.contains(skill.tags, tag)
  })
}

/// Sort skills by safety_score (descending)
/// Uses list.sort with custom comparator
pub fn sort_skills_by_safety_score(
  skills: List(Skill),
) -> List(Skill) {
  list.sort(skills, fn(a, b) {
    case a.safety_score >= b.safety_score {
      True -> Gt
      False -> Lt
    }
  })
}

/// Validate skill data
/// Uses pattern matching with guards (learned from clause_guard_test.gleam)
/// Now uses proper types (corrected from TS)
pub fn validate_skill(skill: Skill) -> Bool {
  case skill {
    Skill(name: "", ..) -> False  // Empty name invalid
    Skill(safety_score: score, ..) if score < 0 || score > 100 -> False
    Skill(status: s, ..) if s != Approved && s != SkillPending && s != Rejected -> False
    _ -> True  // Valid
  }
}

/// Extract trigger phrases from skills
/// Uses list.flat_map pattern
pub fn extract_all_trigger_phrases(
  skills: List(Skill),
) -> List(String) {
  list.flat_map(skills, fn(skill) {
    skill.trigger_phrases
  })
}

/// Count skills by status
/// Uses list.count with pattern matching
/// Now uses SkillStatus type
pub fn count_skills_by_status(
  skills: List(Skill),
  status: SkillStatus,
) -> Int {
  list.count(skills, fn(skill) {
    skill.status == status
  })
}

/// Check if skill matches search criteria
/// Complex condition using multiple fields
pub fn matches_search_criteria(
  skill: Skill,
  search_term: Option(String),
  min_safety_score: Int,
) -> Bool {
  case search_term {
    None -> skill.safety_score >= min_safety_score
    
    Some(term) -> {
      let name_lower = string.lowercase(skill.name)
      let term_lower = string.lowercase(term)
      let name_matches = string.contains(name_lower, term_lower)
      
      name_matches && skill.safety_score >= min_safety_score
    }
  }
}
