// issue_tools.gleam — Issue Pi tool registrations

import pi_tool_call.{
  type PiToolCall, PiToolCall, string_param, opt_string_param, from_param, template,
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
      from_param("params.title || \"\""),
      from_param("params.description || \"\""),
      from_param("params.severity || \"medium\""),
      from_param("params.issue_type || \"bug\""),
      from_param("params.created_by || \"psypi\""),
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
      from_param("params?.status || null"),
      from_param("params?.severity || null"),
      from_param("params?.issue_type || null"),
      from_param("params?.project_id || null"),
      from_param("parseInt(params?.limit || '50')"),
      from_param("parseInt(params?.offset || '0')"),
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
      from_param("params?.status || null"),
      from_param("params?.severity || null"),
      from_param("params?.issue_type || null"),
      from_param("params?.project_id || null"),
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
    args: [from_param("params.id || \"\"")],
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
      from_param("params.id || \"\""),
      from_param("params.resolution || \"resolved\""),
    ],
    result_format: template("Issue resolved: ${r.value}"),
  )
}
