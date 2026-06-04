import gleam/io
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/string
import db
import simplifile

pub type MigrateError {
  ConnectionError(String)
  QueryError(String)
  FileError(String)
}

fn db_error_to_migrate_error(e: db.DbError) -> MigrateError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Split SQL file into individual statements.
/// Handles PostgreSQL dollar-quoted strings ($$...$$) that may contain
/// semicolons without being statement boundaries.
fn split_statements(sql: String) -> List(String) {
  do_split(sql, False, "", [])
}

fn do_split(
  sql: String,
  in_dollar: Bool,
  current: String,
  acc: List(String),
) -> List(String) {
  case string.length(sql) {
    0 -> {
      let stmt = string.trim(current)
      case stmt {
        "" -> list.reverse(acc)
        _ -> list.reverse([stmt, ..acc])
      }
    }
    _ -> {
      let rest = string.drop_left(sql, 1)
      let char = string.slice(sql, 0, 1)
      case in_dollar {
        True -> {
          case string.starts_with(sql, "$$") {
            True -> do_split(string.drop_left(rest, 1), False, current <> "$$", acc)
            False -> do_split(rest, True, current <> char, acc)
          }
        }
        False -> {
          case string.starts_with(sql, "$$") {
            True -> do_split(string.drop_left(rest, 1), True, current <> "$$", acc)
            False -> {
              case char {
                ";" -> {
                  let stmt = string.trim(current)
                  case stmt {
                    "" -> do_split(rest, False, "", acc)
                    _ -> do_split(rest, False, "", [stmt, ..acc])
                  }
                }
                _ -> do_split(rest, False, current <> char, acc)
              }
            }
          }
        }
      }
    }
  }
}

/// Remove SQL comments (-- ...) from a statement to avoid sending bare comments to pg
fn strip_comment_line(stmt: String) -> String {
  case string.starts_with(stmt, "--") {
    True -> ""
    False -> stmt
  }
}

pub fn run_statement(sql: String) -> promise.Promise(Result(Nil, MigrateError)) {
  db.with_connection(fn(conn) {
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> {
          let msg = case e {
            db.ConnectionError(m) -> m
            db.QueryError(m) -> m
          }
          io.println("  ⚠️  Migration statement failed: " <> msg)
          Error(db_error_to_migrate_error(e))
        }
        Ok(_) -> Ok(Nil)
      }
    })
  }, db_error_to_migrate_error)
}

pub fn run_sql(sql: String) -> promise.Promise(Result(Nil, MigrateError)) {
  let statements =
    sql
    |> split_statements
    |> list.map(strip_comment_line)
    |> list.filter(fn(s) { s != "" })
  run_statements(statements)
}

fn run_statements(stmts: List(String)) -> promise.Promise(Result(Nil, MigrateError)) {
  case stmts {
    [] -> promise.resolve(Ok(Nil))
    [stmt, ..rest] -> {
      promise.await(run_statement(stmt), fn(result) {
        case result {
          Error(_) -> promise.resolve(result)
          Ok(_) -> run_statements(rest)
        }
      })
    }
  }
}

pub fn run_all_migrations() -> promise.Promise(Result(List(String), MigrateError)) {
  let migrations_dir = "src/migrations"
  case simplifile.read_directory(migrations_dir) {
    Error(_) -> promise.resolve(Error(FileError("Cannot read migrations dir")))
    Ok(files) -> {
      files
        |> list.filter(fn(f) { string.ends_with(f, ".sql") })
        |> list.sort(by: string.compare)
        |> run_migration_files
    }
  }
}

fn run_migration_files(files: List(String)) -> promise.Promise(Result(List(String), MigrateError)) {
  case files {
    [] -> promise.resolve(Ok([]))
    [file, ..rest] -> {
      let path = "src/migrations/" <> file
      case simplifile.read(path) {
        Error(e) -> promise.resolve(Error(FileError("Cannot read " <> path <> ": " <> simplifile.describe_error(e))))
        Ok(sql) -> {
          promise.await(run_sql(sql), fn(result) {
            case result {
              Error(e) -> promise.resolve(Error(e))
              Ok(_) -> {
                io.println("Ran: " <> file)
                promise.await(run_migration_files(rest), fn(rest_result) {
                  case rest_result {
                    Error(e) -> promise.resolve(Error(e))
                    Ok(done) -> promise.resolve(Ok([file, ..done]))
                  }
                })
              }
            }
          })
        }
      }
    }
  }
}

pub fn main() -> promise.Promise(Int) {
  io.println("Running all psypi migrations...")
  run_all_migrations()
  |> promise.map(fn(result) {
    case result {
      Ok(files) -> {
        io.println("\nMigrations complete: " <> int.to_string(list.length(files)) <> " file(s) run")
        0
      }
      Error(e) -> {
        io.println("Migration error: " <> case e {
          FileError(msg) -> msg
          ConnectionError(msg) -> msg
          QueryError(msg) -> msg
        })
        1
      }
    }
  })
}
