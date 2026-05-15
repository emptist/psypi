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

pub fn run_sql(sql: String) -> promise.Promise(Result(Nil, MigrateError)) {
  db.with_connection(fn(conn) {
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_migrate_error(e))
        Ok(_) -> Ok(Nil)
      }
    })
  }, db_error_to_migrate_error)
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
