// areflect.gleam - All-in-one reflection (~50 lines)
// Small + Pure = Resilience!



pub type ReflectError {
  ParseError(String)
  DatabaseError(String)
}

pub fn areflect(text: String) -> Result(String, ReflectError) {
  // Parse markers: [LEARN], [ISSUE], [TASK], etc.
  let learnings = parse_learnings(text)
  let issues = parse_issues(text)
  let tasks = parse_tasks(text)
  
  // Save to database
  case save_all(learnings, issues, tasks) {
    Ok(_) -> Ok("Reflection saved")
    Error(e) -> Error(DatabaseError(e))
  }
}

fn parse_learnings(text: String) -> List(String) {
  // TODO: Parse [LEARN] markers
  []
}

fn parse_issues(text: String) -> List(String) {
  // TODO: Parse [ISSUE] markers
  []
}

fn parse_tasks(text: String) -> List(String) {
  // TODO: Parse [TASK] markers
  []
}

fn save_all(learnings: List(String), issues: List(String), tasks: List(String)) -> Result(Nil, String) {
  // TODO: Save to PostgreSQL
  Ok(Nil)
}
