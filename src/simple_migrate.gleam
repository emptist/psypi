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

/// Split SQL file into individual statements by semicolon+newline.
/// Skip empty lines and comment-only lines.
fn split_statements(sql: String) -> List(String) {
  sql
  |> string.split(";\n")
  |> list.map(fn(s) { string.trim(s) })
  |> list.filter(fn(s) {
    case s {
      "" -> False
      _ -> True
    }
  })
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
          io.println("  ⚠️  " <> case e {
            db.ConnectionError(msg) -> msg
            db.QueryError(msg) -> msg
          })
          Ok(Nil)
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
