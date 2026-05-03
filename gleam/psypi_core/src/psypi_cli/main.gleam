// main.gleam - CLI entry point + routing (~90 lines)
// Small + Pure = Resilience!


import gleam/string
import psypi_cli/task
import psypi_cli/issue
import psypi_cli/meeting
import psypi_cli/skill
import psypi_cli/context
import psypi_cli/areflect
import psypi_cli/broadcast

pub fn main(args: List(String)) -> Result(Nil, String) {
  case args {
    ["task-add", title, ..rest] -> {
      let desc = get_flag(rest, "--description")
      let priority = get_priority(rest)
      task.add_task(title, desc, priority)
    }
    ["tasks", ..rest] -> {
      let status = get_flag(rest, "--status")
      task.list_tasks(status)
    }
    ["issue-add", title, ..rest] -> {
      let severity = get_flag(rest, "--severity")
      issue.add_issue(title, severity)
    }
    ["issue-list", ..rest] -> {
      let status = get_flag(rest, "--status")
      issue.list_issues(status)
    }
    ["meeting", subcmd, ..rest] -> handle_meeting(subcmd, rest)
    ["skill", subcmd, ..rest] -> handle_skill(subcmd, rest)
    ["my-id"] -> context.my_id()
    ["partner-id"] -> context.partner_id()
    ["my-session-id"] -> context.my_session_id()
    ["areflect", text] -> areflect.areflect(text)
    ["announce", message, ..rest] -> {
      let priority = get_flag(rest, "--priority")
      broadcast.announce(message, priority)
    }
    _ -> Ok("Usage: psypi <command> [options]")
  }
}

fn handle_meeting(subcmd: String, args: List(String)) -> Result(String, String) {
  case subcmd {
    "discuss" -> meeting.create_discussion(get_arg(args, 0), get_arg(args, 1))
    "list" -> meeting.list_meetings(get_flag(args, "--status"), 100)
    "show" -> meeting.show_meeting(get_arg(args, 0))
    "opinion" -> meeting.add_opinion(get_arg(args, 0), get_arg(args, 1), get_arg(args, 2))
    _ -> Ok("Unknown meeting command")
  }
}

fn handle_skill(subcmd: String, args: List(String)) -> Result(String, String) {
  case subcmd {
    "list" -> skill.list_skills()
    "show" -> skill.show_skill(get_arg(args, 0))
    "search" -> skill.search_skills(get_arg(args, 0))
    "build" -> skill.build_skill(get_arg(args, 0), get_arg(args, 1))
    _ -> Ok("Unknown skill command")
  }
}

fn get_arg(args: List(String), index: Int) -> String {
  // TODO: Get argument at index
  ""
}

fn get_flag(args: List(String), flag: String) -> String {
  // TODO: Get flag value
  ""
}

fn get_priority(args: List(String)) -> Int {
  // TODO: Parse --priority flag
  5
}
