import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import psypi_cli/task
import psypi_cli/issue
import psypi_cli/meeting
import psypi_cli/skill
import psypi_cli/context
import psypi_cli/areflect
import psypi_cli/broadcast

pub fn main(args: List(String)) -> promise.Promise(String) {
  case args {
    ["task-add", title, ..rest] -> {
      let desc = get_flag(rest, "--description")
      let priority = get_priority(rest)
      promise.map(task.add(title, desc, priority, "cli"), fn(result) {
        case result {
          Ok(id) -> "Task added: " <> id
          Error(_) -> "Error adding task"
        }
      })
    }
    ["tasks", ..rest] -> {
      let status = get_flag(rest, "--status")
      let status_opt = case status {
        "" -> None
        s -> Some(s)
      }
      promise.map(task.list(status_opt), fn(result) {
        case result {
          Ok(tasks) -> {
            let task_lines = list.map(tasks, fn(t) {
              t.title <> " [" <> status_to_string(t.status) <> "]"
            })
            list.fold(task_lines, "Tasks:\n", fn(acc, line) { acc <> line <> "\n" })
          }
          Error(_) -> "Error listing tasks"
        }
      })
    }
    ["task-complete", task_id] -> {
      promise.map(task.complete(task_id), fn(result) {
        case result {
          Ok(id) -> "Task completed: " <> id
          Error(_) -> "Error completing task"
        }
      })
    }
    ["issue-add", title, ..rest] -> {
      let severity = get_flag(rest, "--severity")
      let severity_val = case severity {
        "" -> "medium"
        s -> s
      }
      promise.map(issue.add(title, "", severity_val, "bug", "cli"), fn(result) {
        case result {
          Ok(id) -> "Issue added: " <> id
          Error(_) -> "Error adding issue"
        }
      })
    }
    ["issue-list", ..rest] -> {
      let status = get_flag(rest, "--status")
      let status_opt = case status {
        "" -> None
        s -> Some(s)
      }
      promise.map(issue.list(status_opt), fn(result) {
        case result {
          Ok(issues) -> {
            let issue_lines = list.map(issues, fn(i) {
              i.title <> " [" <> severity_to_string(i.severity) <> "]"
            })
            list.fold(issue_lines, "Issues:\n", fn(acc, line) { acc <> line <> "\n" })
          }
          Error(_) -> "Error listing issues"
        }
      })
    }
    ["issue-resolve", issue_id, ..rest] -> {
      let resolution = get_arg(rest, 0)
      promise.map(issue.resolve(issue_id, resolution), fn(result) {
        case result {
          Ok(id) -> "Issue resolved: " <> id
          Error(_) -> "Error resolving issue"
        }
      })
    }
    ["meeting", subcmd, ..rest] -> handle_meeting(subcmd, rest)
    ["skill", subcmd, ..rest] -> handle_skill(subcmd, rest)
    ["my-id"] -> promise.resolve(case context.my_id() {
      Ok(id) -> id
      Error(_) -> "Error getting my id"
    })
    ["partner-id"] -> promise.resolve(case context.partner_id() {
      Ok(id) -> id
      Error(_) -> "Error getting partner id"
    })
    ["my-session-id"] -> promise.resolve(case context.my_session_id() {
      Ok(id) -> id
      Error(_) -> "Error getting session id"
    })
    ["areflect", text] -> {
      promise.map(areflect.areflect(text, "cli"), fn(result) {
        case result {
          Ok(r) -> "Reflection saved: " <> int.to_string(r.learnings) <> " learnings"
          Error(_) -> "Error saving reflection"
        }
      })
    }
    ["announce", message, ..rest] -> {
      let priority = get_flag(rest, "--priority")
      let prio = case priority {
        "high" -> broadcast.High
        "urgent" -> broadcast.Urgent
        _ -> broadcast.Normal
      }
      promise.map(broadcast.send("cli", message, prio), fn(result) {
        case result {
          Ok(id) -> "Announcement sent: " <> id
          Error(_) -> "Error broadcasting"
        }
      })
    }
    _ -> promise.resolve("Usage: psypi <command> [options]")
  }
}

fn status_to_string(s: task.TaskStatus) -> String {
  case s {
    task.Pending -> "pending"
    task.Running -> "running"
    task.Completed -> "completed"
    task.Failed -> "failed"
  }
}

fn severity_to_string(s: issue.IssueSeverity) -> String {
  case s {
    issue.Critical -> "critical"
    issue.High -> "high"
    issue.Medium -> "medium"
    issue.Low -> "low"
    issue.Cosmetic -> "cosmetic"
  }
}

fn meeting_status_to_string(s: meeting.MeetingStatus) -> String {
  case s {
    meeting.Pending -> "pending"
    meeting.Active -> "active"
    meeting.Completed -> "completed"
    meeting.Cancelled -> "cancelled"
  }
}

fn skill_status_to_string(s: skill.SkillStatus) -> String {
  case s {
    skill.Pending -> "pending"
    skill.Approved -> "approved"
    skill.Rejected -> "rejected"
    skill.Blocked -> "blocked"
    skill.Installed -> "installed"
    skill.Uninstalled -> "uninstalled"
  }
}

fn handle_meeting(subcmd: String, args: List(String)) -> promise.Promise(String) {
  case subcmd {
    "create" -> {
      let topic = get_arg(args, 0)
      promise.map(meeting.create(topic, "cli"), fn(result) {
        case result {
          Ok(id) -> "Meeting created: " <> id
          Error(_) -> "Error creating meeting"
        }
      })
    }
    "list" -> {
      let status = get_flag(args, "--status")
      let status_opt = case status {
        "" -> None
        s -> Some(s)
      }
      promise.map(meeting.list(status_opt), fn(result) {
        case result {
          Ok(meetings) -> {
            let meeting_lines = list.map(meetings, fn(m) {
              m.topic <> " [" <> meeting_status_to_string(m.status) <> "]"
            })
            list.fold(meeting_lines, "Meetings:\n", fn(acc, line) { acc <> line <> "\n" })
          }
          Error(_) -> "Error listing meetings"
        }
      })
    }
    "show" -> {
      let meeting_id = get_arg(args, 0)
      promise.map(meeting.get(meeting_id), fn(result) {
        case result {
          Ok(m) -> "Meeting: " <> m.topic <> " [" <> meeting_status_to_string(m.status) <> "]"
          Error(_) -> "Error showing meeting"
        }
      })
    }
    "opinion" -> {
      let meeting_id = get_arg(args, 0)
      let author = get_arg(args, 1)
      let perspective = get_arg(args, 2)
      promise.map(meeting.add_opinion(meeting_id, author, perspective, None, None), fn(result) {
        case result {
          Ok(id) -> "Opinion added: " <> id
          Error(_) -> "Error adding opinion"
        }
      })
    }
    "complete" -> {
      let meeting_id = get_arg(args, 0)
      let consensus = get_arg(args, 1)
      promise.map(meeting.complete(meeting_id, consensus), fn(result) {
        case result {
          Ok(id) -> "Meeting completed: " <> id
          Error(_) -> "Error completing meeting"
        }
      })
    }
    _ -> promise.resolve("Unknown meeting command")
  }
}

fn handle_skill(subcmd: String, args: List(String)) -> promise.Promise(String) {
  case subcmd {
    "list" -> {
      promise.map(skill.list(None), fn(result) {
        case result {
          Ok(skills) -> {
            let skill_lines = list.map(skills, fn(s) {
              s.name <> " [" <> s.version <> "]"
            })
            list.fold(skill_lines, "Skills:\n", fn(acc, line) { acc <> line <> "\n" })
          }
          Error(_) -> "Error listing skills"
        }
      })
    }
    "show" -> {
      let name = get_arg(args, 0)
      promise.map(skill.get(name), fn(result) {
        case result {
          Ok(s) -> "Skill: " <> s.name <> " [" <> skill_status_to_string(s.status) <> "]"
          Error(_) -> "Error showing skill"
        }
      })
    }
    "search" -> {
      let query = get_arg(args, 0)
      promise.map(skill.search(query), fn(result) {
        case result {
          Ok(skills) -> {
            let skill_lines = list.map(skills, fn(s) { s.name })
            list.fold(skill_lines, "Results:\n", fn(acc, line) { acc <> line <> "\n" })
          }
          Error(_) -> "Error searching skills"
        }
      })
    }
    "create" -> {
      let name = get_arg(args, 0)
      let desc = get_arg(args, 1)
      promise.map(skill.create(name, desc, "cli"), fn(result) {
        case result {
          Ok(id) -> "Skill created: " <> id
          Error(_) -> "Error creating skill"
        }
      })
    }
    "approve" -> {
      let skill_id = get_arg(args, 0)
      promise.map(skill.approve(skill_id, "cli"), fn(result) {
        case result {
          Ok(id) -> "Skill approved: " <> id
          Error(_) -> "Error approving skill"
        }
      })
    }
    _ -> promise.resolve("Unknown skill command")
  }
}

fn get_arg(args: List(String), index: Int) -> String {
  case index_get(args, index) {
    Some(s) -> s
    None -> ""
  }
}

fn index_get(list: List(a), index: Int) -> option.Option(a) {
  case index {
    0 -> {
      case list {
        [first, ..] -> Some(first)
        _ -> None
      }
    }
    n -> {
      case list {
        [_, ..rest] -> index_get(rest, n - 1)
        _ -> None
      }
    }
  }
}

fn get_flag(args: List(String), flag: String) -> String {
  let result = list.find_map(args, fn(arg) {
    case string.split(arg, "=") {
      [key, value] if key == flag -> Ok(value)
      _ -> Error(Nil)
    }
  })
  case result {
    Ok(s) -> s
    Error(_) -> ""
  }
}

fn get_priority(args: List(String)) -> Int {
  let prio = get_flag(args, "--priority")
  case prio {
    "critical" -> 1
    "high" -> 2
    "medium" -> 3
    "low" -> 4
    _ -> 5
  }
}
