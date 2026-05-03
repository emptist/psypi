// main.gleam - CLI entry point + routing (~90 lines)
// Small + Pure = Resilience!

import psypi_cli/task
import psypi_cli/issue
import psypi_cli/meeting
import psypi_cli/skill
import psypi_cli/context
import psypi_cli/areflect
import psypi_cli/broadcast

pub fn main(args: List(String)) -> Result(String, String) {
  case args {
    ["task-add", title, ..rest] -> {
      let desc = get_flag(rest, "--description")
      let priority = get_priority(rest)
      case task.add_task(title, desc, priority) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error adding task")
      }
    }
    ["tasks", ..rest] -> {
      let status = get_flag(rest, "--status")
      case task.list_tasks(status) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error listing tasks")
      }
    }
    ["issue-add", title, ..rest] -> {
      let severity = get_flag(rest, "--severity")
      case issue.add_issue(title, severity) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error adding issue")
      }
    }
    ["issue-list", ..rest] -> {
      let status = get_flag(rest, "--status")
      case issue.list_issues(status) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error listing issues")
      }
    }
    ["meeting", subcmd, ..rest] -> handle_meeting(subcmd, rest)
    ["skill", subcmd, ..rest] -> handle_skill(subcmd, rest)
    ["my-id"] -> context.my_id()
    ["partner-id"] -> context.partner_id()
    ["my-session-id"] -> context.my_session_id()
    ["areflect", text] -> areflect.areflect(text)
    ["announce", message, ..rest] -> {
      let priority = get_flag(rest, "--priority")
      case broadcast.announce(message, priority) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error broadcasting")
      }
    }
    _ -> Ok("Usage: psypi <command> [options]")
  }
}

fn handle_meeting(subcmd: String, args: List(String)) -> Result(String, String) {
  case subcmd {
    "discuss" -> {
      case meeting.create_discussion(get_arg(args, 0), get_arg(args, 1)) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error creating discussion")
      }
    }
    "list" -> {
      case meeting.list_meetings(get_flag(args, "--status"), 100) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error listing meetings")
      }
    }
    "show" -> {
      case meeting.show_meeting(get_arg(args, 0)) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error showing meeting")
      }
    }
    "opinion" -> {
      case meeting.add_opinion(get_arg(args, 0), get_arg(args, 1), get_arg(args, 2)) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error adding opinion")
      }
    }
    _ -> Ok("Unknown meeting command")
  }
}

fn handle_skill(subcmd: String, args: List(String)) -> Result(String, String) {
  case subcmd {
    "list" -> {
      case skill.list_skills() {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error listing skills")
      }
    }
    "show" -> {
      case skill.show_skill(get_arg(args, 0)) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error showing skill")
      }
    }
    "search" -> {
      case skill.search_skills(get_arg(args, 0)) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error searching skills")
      }
    }
    "build" -> {
      case skill.build_skill(get_arg(args, 0), get_arg(args, 1)) {
        Ok(s) -> Ok(s)
        Error(_) -> Ok("Error building skill")
      }
    }
    _ -> Ok("Unknown skill command")
  }
}

fn get_arg(_args: List(String), _index: Int) -> String {
  // TODO: Get argument at index
  ""
}

fn get_flag(_args: List(String), _flag: String) -> String {
  // TODO: Get flag value
  ""
}

fn get_priority(_args: List(String)) -> Int {
  // TODO: Parse --priority flag
  5
}
