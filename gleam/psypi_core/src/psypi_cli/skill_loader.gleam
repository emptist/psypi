// skill_loader.gleam - Skill loading utilities (pure functions!)
// Small + Pure = Resilience!
//
// Extracted from DatabaseSkillLoader.ts (913 lines → ~150 lines Gleam)
// Learned patterns from ../refers/gleam:
// - Use gleam/list for filtering and searching
// - Use pattern matching for validation
// - Use recursive functions for list processing
// - Add documentation with /// comments

import gleam/dynamic
import gleam/string
import gleam/list
import gleam/option.{type Option, Some, None}
import gleam/order.{type Order, Gt, Lt, Eq}

/// Skill record type (simplified for Gleam)
pub type Skill {
  Skill(
    id: String,
    name: String,
    description: Option(String),
    status: String,
    is_enabled: Bool,
    safety_score: Int,
    tags: List(String),
    trigger_phrases: List(String),
  )
}

/// Filter approved and enabled skills
/// (Pure function - no side effects!)
pub fn filter_approved_skills(
  skills: List(Skill),
) -> List(Skill) {
  list.filter(skills, fn(skill) {
    skill.status == "approved" && skill.is_enabled && skill.safety_score >= 70
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
pub fn validate_skill(skill: Skill) -> Bool {
  case skill {
    Skill(name: "", ..) -> False  // Empty name invalid
    Skill(safety_score: score, ..) if score < 0 || score > 100 -> False
    Skill(status: s, ..) if s != "approved" && s != "pending" && s != "rejected" -> False
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
pub fn count_skills_by_status(
  skills: List(Skill),
  status: String,
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
