// issue_tools.gleam — Issue Pi tool registrations

import gleam/option.{Some}
import pi_tool_call.{
  type PiToolCall, PiToolCall, string_param, opt_string_param, param, opt_param, int_param, template,
}

pub fn issue_add_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issue-add",
    description: "Add a new issue. project_url is auto-resolved from git remote or cwd.",
    params: [
      string_param("title"),
      opt_string_param("description"),
      opt_string_param("severity"),
      opt_string_param("issue_type"),
    ],
    module: "issue_db",
    fn_name: "add",
    args: [
      param("title", Some("")),
      param("description", Some("")),
      param("severity", Some("medium")),
      param("issue_type", Some("bug")),
      param("created_by", Some("psypi")),
    ],
    result_format: template("Issue added: ${r.value}"),
  )
}

pub fn issue_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issues",
    description: "List issues. Pass project_id=ALL to show all projects.",
    params: [
      opt_string_param("status"),
      opt_string_param("severity"),
      opt_string_param("issue_type"),
      opt_string_param("project_id"),
    ],
    module: "issue_db",
    fn_name: "list",
    args: [
      opt_param("status"),
      opt_param("severity"),
      opt_param("issue_type"),
      opt_param("project_id"),
      int_param("limit", 50),
      int_param("offset", 0),
    ],
    result_format: template("Issues: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

pub fn issue_count_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issue-count",
    description: "Count issues. Pass project_id=ALL to count all projects.",
    params: [
      opt_string_param("status"),
      opt_string_param("severity"),
      opt_string_param("issue_type"),
      opt_string_param("project_id"),
    ],
    module: "issue_db",
    fn_name: "count",
    args: [
      opt_param("status"),
      opt_param("severity"),
      opt_param("issue_type"),
      opt_param("project_id"),
    ],
    result_format: template("Count: ${r.value}"),
  )
}

pub fn issue_get_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issue-get",
    description: "Get a single issue by ID. Only returns issues belonging to the current project.",
    params: [string_param("id")],
    module: "issue_db",
    fn_name: "get",
    args: [param("id", Some(""))],
    result_format: template("Issue: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

pub fn issue_resolve_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issue-resolve",
    description: "Resolve an issue by ID. Only resolves issues belonging to the current project.",
    params: [
      string_param("id"),
      opt_string_param("resolution"),
    ],
    module: "issue_db",
    fn_name: "resolve",
    args: [
      param("id", Some("")),
      param("resolution", Some("resolved")),
    ],
    result_format: template("Issue resolved: ${r.value}"),
  )
}
