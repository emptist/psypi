import gleam/javascript/promise
import gleam/io
import db

pub type SeedError {
  DbError(db.DbError)
}

fn db_error_to_seed_error(e: db.DbError) -> SeedError {
  case e {
    db.ConnectionError(msg) -> DbError(db.ConnectionError(msg))
    db.QueryError(msg) -> DbError(db.QueryError(msg))
  }
}

fn seed_idempotent(
  label: String,
  sql: String,
) -> promise.Promise(Result(Nil, SeedError)) {
  db.with_connection(fn(conn) {
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Ok(_) -> {
          io.println("  " <> label <> ": done")
          Ok(Nil)
        }
        Error(e) -> {
          io.println("  " <> label <> ": error - " <> case e {
            db.ConnectionError(msg) -> msg
            db.QueryError(msg) -> msg
          })
          Error(db_error_to_seed_error(e))
        }
      }
    })
  }, db_error_to_seed_error)
}

fn seed_agent_souls() -> promise.Promise(Result(Nil, SeedError)) {
  seed_idempotent(
    "agent_souls",
    "INSERT INTO agent_souls (id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, content) SELECT 'A','Autonomic','AutonomicBot','autonomic','PDCA Check between S sessions — inter-review, behavior compliance, anti-stupidity, follow-up enforcement','event','autonomous','agent_end','# A' WHERE NOT EXISTS (SELECT 1 FROM agent_souls WHERE id_prefix='A'); INSERT INTO agent_souls (id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, content) SELECT 'S','Somatic','SomaticBot','somatic','PDCA Do — prompt-driven task execution, follow A feedback, plan before do','prompt','reactive','user prompt, A message','# S' WHERE NOT EXISTS (SELECT 1 FROM agent_souls WHERE id_prefix='S')"
  )
}

fn seed_psypi_config() -> promise.Promise(Result(Nil, SeedError)) {
  seed_idempotent(
    "psypi_config",
    "INSERT INTO psypi_config (key, value) VALUES ('monitor_debounce_ms','300000'), ('last_wakeup',''), ('idle_since','0'), ('last_a_session_at','') ON CONFLICT (key) DO NOTHING"
  )
}

fn seed_agent_prefixes() -> promise.Promise(Result(Nil, SeedError)) {
  seed_idempotent(
    "agent_prefixes",
    "INSERT INTO agent_prefixes (prefix, name, description) SELECT 'A','AutonomicBot','Autonomic monitor' WHERE NOT EXISTS (SELECT 1 FROM agent_prefixes WHERE prefix='A'); INSERT INTO agent_prefixes (prefix, name, description) SELECT 'S','SomaticBot','Somatic executor' WHERE NOT EXISTS (SELECT 1 FROM agent_prefixes WHERE prefix='S'); INSERT INTO agent_prefixes (prefix, name, description) SELECT 'G','GlobalBot','Global no-git' WHERE NOT EXISTS (SELECT 1 FROM agent_prefixes WHERE prefix='G')"
  )
}

pub fn main() -> promise.Promise(Int) {
  io.println("Seeding psypi initial data...")
  io.println("")

  promise.await(seed_agent_souls(), fn(r1) {
    promise.await(seed_psypi_config(), fn(r2) {
      promise.await(seed_agent_prefixes(), fn(r3) {
        case r1, r2, r3 {
          Ok(_), Ok(_), Ok(_) -> {
            io.println("")
            io.println("Seed complete!")
            promise.resolve(0)
          }
          Error(e), _, _ -> {
            io.println("")
            io.println("Seed failed: " <> seed_error_to_string(e))
            promise.resolve(1)
          }
          _, Error(e), _ -> {
            io.println("")
            io.println("Seed failed: " <> seed_error_to_string(e))
            promise.resolve(1)
          }
          _, _, Error(e) -> {
            io.println("")
            io.println("Seed failed: " <> seed_error_to_string(e))
            promise.resolve(1)
          }
        }
      })
    })
  })
}

fn seed_error_to_string(e: SeedError) -> String {
  case e {
    DbError(db.ConnectionError(msg)) -> "DB connection: " <> msg
    DbError(db.QueryError(msg)) -> "DB query: " <> msg
  }
}
