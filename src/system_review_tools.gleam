import pi_tool_call.{
  type PiToolCall, PiToolCall, string_param, opt_string_param, from_param, template,
}

pub fn review_create_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-review-create",
    description: "Create a new system review. Use 'system' type for full project reviews.",
    params: [
      string_param("title"),
      opt_string_param("description"),
      opt_string_param("review_type"),
      opt_string_param("methodology"),
      opt_string_param("scope"),
      opt_string_param("project_id"),
    ],
    module: "system_review_db",
    fn_name: "create_review",
    args: [
      from_param("params.review_type || \"system\""),
      from_param("params.title || \"\""),
      from_param("params.description || \"\""),
      from_param("params.methodology || \"mixed\""),
      from_param("params.scope || \"full\""),
      from_param("params.reviewer_id || \"psypi\""),
      from_param("params.project_id || \"0d324e68-b399-4b85-bd8a-6b1ef7b46168\""),
    ],
    result_format: template("Review created: ${r.value}"),
  )
}

pub fn review_get_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-review-get",
    description: "Get a system review by ID.",
    params: [string_param("id")],
    module: "system_review_db",
    fn_name: "get_review",
    args: [from_param("params.id || \"\"")],
    result_format: template("Review: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

pub fn review_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-reviews",
    description: "List system reviews. Filter by status or review_type.",
    params: [
      opt_string_param("status"),
      opt_string_param("review_type"),
    ],
    module: "system_review_db",
    fn_name: "list_reviews",
    args: [
      from_param("params?.status || null"),
      from_param("params?.review_type || null"),
      from_param("parseInt(params?.limit || '20')"),
      from_param("parseInt(params?.offset || '0')"),
    ],
    result_format: template("Reviews: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

pub fn finding_add_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-finding-add",
    description: "Add a finding to a system review. Each finding has severity, category, and description.",
    params: [
      string_param("review_id"),
      string_param("finding_number"),
      string_param("severity"),
      string_param("category"),
      string_param("title"),
      string_param("description"),
      opt_string_param("module"),
      opt_string_param("evidence"),
      opt_string_param("impact"),
    ],
    module: "system_review_db",
    fn_name: "add_finding",
    args: [
      from_param("params.review_id || \"\""),
      from_param("parseInt(params.finding_number || '1')"),
      from_param("params.severity || \"medium\""),
      from_param("params.category || \"general\""),
      from_param("params.module || \"\""),
      from_param("params.title || \"\""),
      from_param("params.description || \"\""),
      from_param("params.evidence || \"\""),
      from_param("params.impact || \"\""),
    ],
    result_format: template("Finding added: ${r.value}"),
  )
}

pub fn finding_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-findings",
    description: "List findings for a system review. Filter by severity or status.",
    params: [
      string_param("review_id"),
      opt_string_param("severity"),
      opt_string_param("status"),
    ],
    module: "system_review_db",
    fn_name: "list_findings",
    args: [
      from_param("params.review_id || \"\""),
      from_param("params?.severity || null"),
      from_param("params?.status || null"),
      from_param("parseInt(params?.limit || '200')"),
      from_param("parseInt(params?.offset || '0')"),
    ],
    result_format: template("Findings: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

pub fn finding_count_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-finding-count",
    description: "Count findings for a system review. Filter by severity or status.",
    params: [
      string_param("review_id"),
      opt_string_param("severity"),
      opt_string_param("status"),
    ],
    module: "system_review_db",
    fn_name: "count_findings",
    args: [
      from_param("params.review_id || \"\""),
      from_param("params?.severity || null"),
      from_param("params?.status || null"),
    ],
    result_format: template("Count: ${r.value}"),
  )
}

pub fn finding_update_status_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-finding-update",
    description: "Update a finding's status. Use: open, confirmed, disputed, fixed, wont_fix, duplicate, retracted.",
    params: [
      string_param("id"),
      string_param("status"),
    ],
    module: "system_review_db",
    fn_name: "update_finding_status",
    args: [
      from_param("params.id || \"\""),
      from_param("params.status || \"open\""),
    ],
    result_format: template("Finding updated: ${r.value}"),
  )
}

pub fn review_complete_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-review-complete",
    description: "Mark a system review as completed.",
    params: [string_param("id")],
    module: "system_review_db",
    fn_name: "complete_review",
    args: [from_param("params.id || \"\"")],
    result_format: template("Review completed: ${r.value}"),
  )
}

pub fn review_severity_breakdown_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-review-severity",
    description: "Get severity breakdown for a system review's findings.",
    params: [string_param("review_id")],
    module: "system_review_db",
    fn_name: "severity_breakdown",
    args: [from_param("params.review_id || \"\"")],
    result_format: template("Severity breakdown: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}
