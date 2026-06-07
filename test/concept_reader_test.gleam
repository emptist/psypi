//// Integration test runner for concept_reader.
//// Run with: gleam run -m concept_reader_test
//// Requires PostgreSQL with psypi database and migration 058+ applied.

import concept_reader
import gleam/bool
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/option
import gleam/string

pub fn main() {
  io.println("=== Concept Reader Integration Tests ===\n")
  promise.await(run_all_tests(), fn(_result) {
    io.println("\n=== All tests complete ===")
    promise.resolve(Nil)
  })
}

fn run_all_tests() -> promise.Promise(Nil) {
  promise.await(test_lookup_is_archived(), fn(_) {
    promise.await(test_lookup_is_active(), fn(_) {
      promise.await(test_lookup_append_only(), fn(_) {
        promise.await(test_lookup_turn_based_dialogue(), fn(_) {
          promise.await(test_lookup_a_bot(), fn(_) {
            promise.await(test_lookup_s_bot(), fn(_) {
              promise.await(test_lookup_debounce_timer(), fn(_) {
                promise.await(test_lookup_zero_handwritten_js(), fn(_) {
                  promise.await(test_lookup_unknown_concept(), fn(_) {
                    promise.await(test_list_all_concepts(), fn(_) {
                      promise.await(test_list_by_category(), fn(_) {
                        promise.await(test_all_concepts_have_required_fields(), fn(_) {
                          promise.await(test_all_concepts_have_anti_patterns(), fn(_) {
                            promise.await(test_all_concepts_have_related(), fn(_) {
                              promise.resolve(Nil)
                            })
                          })
                        })
                      })
                    })
                  })
                })
              })
            })
          })
        })
      })
    })
  })
}

fn pass(name: String) -> Nil {
  io.println("  PASS: " <> name)
  Nil
}

fn fail(name: String, msg: String) -> Nil {
  io.println("  FAIL: " <> name <> " — " <> msg)
  Nil
}

fn test_lookup_is_archived() -> promise.Promise(Nil) {
  let name = "lookup is_archived"
  promise.await(concept_reader.lookup_concept("is_archived"), fn(result) {
    case result {
      Ok(concept) ->
        case concept.term == "is_archived (Primary Gate)"
          && string.contains(concept.definition, "primary visibility gate")
          && concept.category == "database" {
          True -> pass(name)
          False ->
            fail(
              name,
              "term=" <> concept.term <> " category=" <> concept.category,
            )
        }
      Error(e) -> fail(name, e)
    }
    promise.resolve(Nil)
  })
}

fn test_lookup_is_active() -> promise.Promise(Nil) {
  let name = "lookup is_active"
  promise.await(concept_reader.lookup_concept("is_active"), fn(result) {
    case result {
      Ok(concept) ->
        case concept.term == "is_active (Business Flag)"
          && string.contains(concept.definition, "NOT a versioning field") {
          True -> pass(name)
          False ->
            fail(
              name,
              "term=" <> concept.term <> " def_missing=NOT_a_versioning_field",
            )
        }
      Error(e) -> fail(name, e)
    }
    promise.resolve(Nil)
  })
}

fn test_lookup_append_only() -> promise.Promise(Nil) {
  let name = "lookup append-only"
  promise.await(concept_reader.lookup_concept("append-only"), fn(result) {
    case result {
      Ok(concept) ->
        case string.contains(concept.definition, "never UPDATEd in place")
          && list.contains(concept.related_concepts, "is_archived")
          && list.contains(concept.related_concepts, "is_active") {
          True -> pass(name)
          False ->
            fail(
              name,
              "related=" <> string.join(concept.related_concepts, ","),
            )
        }
      Error(e) -> fail(name, e)
    }
    promise.resolve(Nil)
  })
}

fn test_lookup_turn_based_dialogue() -> promise.Promise(Nil) {
  let name = "lookup turn-based-dialogue"
  promise.await(
    concept_reader.lookup_concept("turn-based-dialogue"),
    fn(result) {
      case result {
        Ok(concept) ->
          case string.contains(concept.definition, "take turns")
            && list.contains(concept.related_concepts, "a-bot") {
            True -> pass(name)
            False ->
              fail(
                name,
                "related=" <> string.join(concept.related_concepts, ","),
              )
          }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}

fn test_lookup_a_bot() -> promise.Promise(Nil) {
  let name = "lookup a-bot"
  promise.await(concept_reader.lookup_concept("a-bot"), fn(result) {
    case result {
      Ok(concept) ->
        case string.contains(concept.definition, "NO tools")
          && string.contains(concept.definition, "Check") {
          True -> pass(name)
          False -> fail(name, "definition missing expected content")
        }
      Error(e) -> fail(name, e)
    }
    promise.resolve(Nil)
  })
}

fn test_lookup_s_bot() -> promise.Promise(Nil) {
  let name = "lookup s-bot"
  promise.await(concept_reader.lookup_concept("s-bot"), fn(result) {
    case result {
      Ok(concept) ->
        case string.contains(concept.definition, "Plan/Do/Act") {
          True -> pass(name)
          False -> fail(name, "definition missing Plan/Do/Act")
        }
      Error(e) -> fail(name, e)
    }
    promise.resolve(Nil)
  })
}

fn test_lookup_debounce_timer() -> promise.Promise(Nil) {
  let name = "lookup debounce-timer"
  promise.await(concept_reader.lookup_concept("debounce-timer"), fn(result) {
    case result {
      Ok(concept) ->
        case string.contains(concept.definition, "setTimeout") {
          True -> pass(name)
          False -> fail(name, "definition missing setTimeout")
        }
      Error(e) -> fail(name, e)
    }
    promise.resolve(Nil)
  })
}

fn test_lookup_zero_handwritten_js() -> promise.Promise(Nil) {
  let name = "lookup zero-handwritten-js"
  promise.await(
    concept_reader.lookup_concept("zero-handwritten-js"),
    fn(result) {
      case result {
        Ok(concept) ->
          case string.contains(concept.definition, "three mechanisms") {
            True -> pass(name)
            False -> fail(name, "definition missing 'three mechanisms'")
          }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}

fn test_lookup_unknown_concept() -> promise.Promise(Nil) {
  let name = "lookup unknown concept returns error"
  promise.await(
    concept_reader.lookup_concept("nonexistent-concept"),
    fn(result) {
      case result {
        Ok(_) -> fail(name, "expected error, got Ok")
        Error(e) ->
          case string.contains(e, "Concept not found") {
            True -> pass(name)
            False -> fail(name, "unexpected error: " <> e)
          }
      }
      promise.resolve(Nil)
    },
  )
}

fn test_list_all_concepts() -> promise.Promise(Nil) {
  let name = "list all concepts returns >= 8"
  promise.await(
    concept_reader.list_concepts(option.None),
    fn(result) {
      case result {
        Ok(concepts) ->
          case list.length(concepts) >= 8 {
            True ->
              pass(name <> " (" <> int.to_string(list.length(concepts)) <> ")")
            False ->
              fail(
                name,
                "got " <> int.to_string(list.length(concepts)) <> " concepts",
              )
          }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}

fn test_list_by_category() -> promise.Promise(Nil) {
  let name = "list by category=database returns 2"
  promise.await(
    concept_reader.list_concepts(option.Some("database")),
    fn(result) {
      case result {
        Ok(concepts) -> {
          let count = list.length(concepts)
          let all_db =
            list.all(concepts, fn(c) { c.category == "database" })
          case count == 2 && all_db {
            True -> pass(name)
            False ->
              fail(
                name,
                "got "
                  <> int.to_string(count)
                  <> " concepts, all_db="
                  <> bool.to_string(all_db),
              )
          }
        }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}

fn test_all_concepts_have_required_fields() -> promise.Promise(Nil) {
  let name = "all concepts have required fields"
  promise.await(
    concept_reader.list_concepts(option.None),
    fn(result) {
      case result {
        Ok(concepts) -> {
          let all_valid = list.all(concepts, fn(c) {
            string.length(c.concept_key) > 0
            && string.length(c.term) > 0
            && string.length(c.definition) > 10
            && string.length(c.category) > 0
          })
          case all_valid {
            True -> pass(name)
            False -> fail(name, "some concepts missing required fields")
          }
        }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}

fn test_all_concepts_have_anti_patterns() -> promise.Promise(Nil) {
  let name = "all concepts have anti_patterns"
  promise.await(
    concept_reader.list_concepts(option.None),
    fn(result) {
      case result {
        Ok(concepts) -> {
          let all_have = list.all(concepts, fn(c) {
            string.length(c.anti_patterns) > 0
          })
          case all_have {
            True -> pass(name)
            False -> fail(name, "some concepts missing anti_patterns")
          }
        }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}

fn test_all_concepts_have_related() -> promise.Promise(Nil) {
  let name = "all concepts have related_concepts"
  promise.await(
    concept_reader.list_concepts(option.None),
    fn(result) {
      case result {
        Ok(concepts) -> {
          let all_have = list.all(concepts, fn(c) {
            c.related_concepts != []
          })
          case all_have {
            True -> pass(name)
            False -> fail(name, "some concepts missing related_concepts")
          }
        }
        Error(e) -> fail(name, e)
      }
      promise.resolve(Nil)
    },
  )
}
