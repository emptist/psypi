import gleeunit
import gleeunit/should
import pi_tool_call.{
  PiToolCall, args_to_js, command, command_to_js, debounced_hook, event_hook,
  event_hook_to_js, from_param, hook_call_expr, hook_import_line, lit,
  number_param, opt_string_param, params_to_js, raw_json, result_to_js,
  string_param, system_prompt_hook, template, to_import_line, to_js_text,
}
import gleam/option.{None, Some}
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn string_param_test() {
  let p = string_param("name")
  p.name |> should.equal("name")
  p.param_type |> should.equal("string")
  p.required |> should.equal(True)
}

pub fn opt_string_param_test() {
  let p = opt_string_param("query")
  p.name |> should.equal("query")
  p.param_type |> should.equal("string")
  p.required |> should.equal(False)
}

pub fn number_param_test() {
  let p = number_param("count")
  p.name |> should.equal("count")
  p.param_type |> should.equal("number")
  p.required |> should.equal(True)
}

pub fn params_to_js_empty_test() {
  params_to_js([])
  |> should.equal("{ \"type\": \"object\", \"properties\": {} }")
}

pub fn params_to_js_single_test() {
  let js = params_to_js([string_param("name")])
  should.be_true(string.contains(js, "\"name\""))
  should.be_true(string.contains(js, "\"type\": \"string\""))
  should.be_true(string.contains(js, "\"required\": [\"name\"]"))
}

pub fn params_to_js_multiple_test() {
  let js = params_to_js([string_param("name"), number_param("count")])
  should.be_true(string.contains(js, "\"name\""))
  should.be_true(string.contains(js, "\"count\""))
  should.be_true(string.contains(js, "\"type\": \"number\""))
  should.be_true(string.contains(js, "\"required\": [\"name\", \"count\"]"))
}

pub fn params_to_js_optional_not_required_test() {
  let js = params_to_js([string_param("name"), opt_string_param("hint")])
  should.be_true(string.contains(js, "\"required\": [\"name\"]"))
  should.be_false(string.contains(js, "\"required\": [\"name\", \"hint\"]"))
}

pub fn args_to_js_empty_test() {
  args_to_js([]) |> should.equal("")
}

pub fn args_to_js_literals_test() {
  args_to_js([lit("42"), lit("'hello'")])
  |> should.equal("42, 'hello'")
}

pub fn args_to_js_from_param_test() {
  args_to_js([from_param("params.query")])
  |> should.equal("params.query")
}

pub fn args_to_js_mixed_test() {
  args_to_js([lit("ctx"), from_param("params.path")])
  |> should.equal("ctx, params.path")
}

pub fn result_to_js_raw_json_test() {
  result_to_js(raw_json())
  |> should.equal("JSON.stringify(gleamValueToJson(r.value))")
}

pub fn result_to_js_template_test() {
  result_to_js(template("Result: ${r.value}"))
  |> should.equal("`Result: ${r.value}`")
}

pub fn to_js_text_basic_test() {
  let tool = PiToolCall(
    name: "read_file",
    description: "Read a file",
    params: [string_param("path")],
    module: "tool_read_file",
    fn_name: "execute",
    args: [from_param("params.path")],
    result_format: raw_json(),
  )
  let js = to_js_text(tool)
  should.be_true(string.contains(js, "pi.registerTool"))
  should.be_true(string.contains(js, "name: \"read_file\""))
  should.be_true(string.contains(js, "description: \"Read a file\""))
  should.be_true(string.contains(js, "async execute"))
  should.be_true(string.contains(js, "unwrapGleamResult"))
  should.be_true(string.contains(js, "tool_read_file_execute(params.path)"))
}

pub fn to_js_text_no_params_test() {
  let tool = PiToolCall(
    name: "status",
    description: "Get status",
    params: [],
    module: "tool_status",
    fn_name: "run",
    args: [],
    result_format: raw_json(),
  )
  let js = to_js_text(tool)
  should.be_true(string.contains(js, "name: \"status\""))
  should.be_true(string.contains(js, "\"properties\": {}"))
}

pub fn to_import_line_test() {
  let tool = PiToolCall(
    name: "read_file",
    description: "",
    params: [],
    module: "tool_read_file",
    fn_name: "execute",
    args: [],
    result_format: raw_json(),
  )
  to_import_line(tool)
  |> should.equal("import { execute as tool_read_file_execute } from \"./build/dev/javascript/psypi/tool_read_file.mjs\";")
}

pub fn hook_import_line_test() {
  let line = hook_import_line("hook_on_agent_start", "on_agent_start")
  should.be_true(string.contains(line, "hook_on_agent_start_on_agent_start"))
  should.be_true(string.contains(line, "hook_on_agent_start.mjs"))
}

pub fn hook_call_expr_test() {
  hook_call_expr("hook_on_agent_start", "on_agent_start", [])
  |> should.equal("hook_on_agent_start_on_agent_start()")
}

pub fn hook_call_expr_with_args_test() {
  hook_call_expr("mod", "fn", [lit("42"), from_param("event")])
  |> should.equal("mod_fn(42, event)")
}

pub fn event_hook_to_js_basic_test() {
  let hook = event_hook(
    "agent_start",
    "hook_on_agent_start",
    "on_agent_start",
    [],
    None,
    pi_tool_call.SilentSuccess,
    pi_tool_call.NotifyError,
  )
  let js = event_hook_to_js(hook)
  should.be_true(string.contains(js, "pi.on('agent_start'"))
  should.be_true(string.contains(js, "async (event, ctx)"))
  should.be_true(string.contains(js, "unwrapGleamResult"))
  should.be_true(string.contains(js, "event_hooks_record_trigger('agent_start')"))
}

pub fn event_hook_to_js_with_guard_test() {
  let hook = event_hook(
    "agent_start",
    "hook_mod",
    "handler",
    [],
    Some("ctx.isIdle"),
    pi_tool_call.SilentSuccess,
    pi_tool_call.NotifyError,
  )
  let js = event_hook_to_js(hook)
  should.be_true(string.contains(js, "if (ctx.isIdle)"))
}

pub fn system_prompt_hook_to_js_test() {
  let hook = system_prompt_hook(
    "before_agent_start",
    "hook_on_before_agent_start",
    "on_before_agent_start",
    [],
    pi_tool_call.NotifyError,
  )
  let js = event_hook_to_js(hook)
  should.be_true(string.contains(js, "pi.on('before_agent_start'"))
  should.be_true(string.contains(js, "systemPrompt: r.value"))
  should.be_true(string.contains(js, "Event hook (system prompt)"))
}

pub fn debounced_hook_to_js_test() {
  let hook = debounced_hook(
    "agent_end",
    "hook_on_agent_end",
    "on_agent_end",
    [],
    "psypi_config",
    "get_debounce_ms",
    None,
    pi_tool_call.SilentSuccess,
    pi_tool_call.NotifyError,
  )
  let js = event_hook_to_js(hook)
  should.be_true(string.contains(js, "pi.on('agent_end'"))
  should.be_true(string.contains(js, "setTimeout"))
  should.be_true(string.contains(js, "debounceMs"))
  should.be_true(string.contains(js, "psypi_config_get_debounce_ms()"))
  should.be_true(string.contains(js, "Event hook (debounced)"))
}

pub fn command_to_js_test() {
  let cmd = command(
    "compact",
    "Compact conversation",
    "cmd_compact",
    "run",
    [from_param("args")],
    raw_json(),
  )
  let js = command_to_js(cmd)
  should.be_true(string.contains(js, "pi.registerCommand"))
  should.be_true(string.contains(js, "\"compact\""))
  should.be_true(string.contains(js, "Compact conversation"))
  should.be_true(string.contains(js, "cmd_compact_run(args)"))
}

pub fn command_to_js_template_result_test() {
  let cmd = command(
    "status",
    "Show status",
    "cmd_status",
    "run",
    [],
    template("Status: ${r.value}"),
  )
  let js = command_to_js(cmd)
  should.be_true(string.contains(js, "`Status: ${r.value}`"))
}

pub fn event_hook_notify_success_test() {
  let hook = event_hook(
    "test_event",
    "mod",
    "handler",
    [],
    None,
    pi_tool_call.NotifySuccess("Done!"),
    pi_tool_call.NotifyError,
  )
  let js = event_hook_to_js(hook)
  should.be_true(string.contains(js, "ctx.ui.notify('Done!', 'info')"))
}

pub fn event_hook_set_status_test() {
  let hook = event_hook(
    "test_event",
    "mod",
    "handler",
    [],
    None,
    pi_tool_call.SetStatus("phase", "reviewing"),
    pi_tool_call.NotifyError,
  )
  let js = event_hook_to_js(hook)
  should.be_true(string.contains(js, "ctx.ui.setStatus('phase', 'reviewing')"))
}
