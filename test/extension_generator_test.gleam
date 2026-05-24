import gleeunit
import gleeunit/should
import extension_generator
import gleam/list
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn all_tools_not_empty_test() {
  extension_generator.all_tools() |> list.is_empty() |> should.be_false()
}

pub fn all_tools_have_names_test() {
  let tools = extension_generator.all_tools()
  should.be_true(list.all(tools, fn(t) { string.length(t.name) > 0 }))
}

pub fn all_tools_have_modules_test() {
  let tools = extension_generator.all_tools()
  should.be_true(list.all(tools, fn(t) { string.length(t.module) > 0 }))
}

pub fn all_tools_have_fn_names_test() {
  let tools = extension_generator.all_tools()
  should.be_true(list.all(tools, fn(t) { string.length(t.fn_name) > 0 }))
}

pub fn all_tools_unique_names_test() {
  let tools = extension_generator.all_tools()
  let names = list.map(tools, fn(t) { t.name })
  let unique = list.unique(names)
  list.length(names) |> should.equal(list.length(unique))
}

pub fn all_event_hooks_not_empty_test() {
  extension_generator.all_event_hooks() |> list.is_empty() |> should.be_false()
}

pub fn all_commands_not_empty_test() {
  extension_generator.all_commands() |> list.is_empty() |> should.be_false()
}

pub fn generate_produces_extension_js_test() {
  let js = extension_generator.generate()
  should.be_true(string.contains(js, "export default function(pi)"))
  should.be_true(string.contains(js, "pi.registerTool"))
  should.be_true(string.contains(js, "pi.on("))
  should.be_true(string.contains(js, "registerAutonomicWakeupRenderer"))
}

pub fn generate_has_do_not_edit_header_test() {
  let js = extension_generator.generate()
  should.be_true(string.contains(js, "DO NOT EDIT"))
  should.be_true(string.contains(js, "extension_generator"))
}

pub fn generate_has_imports_test() {
  let js = extension_generator.generate()
  should.be_true(string.contains(js, "import {"))
  should.be_true(string.contains(js, "unwrapGleamResult"))
  should.be_true(string.contains(js, "gleamValueToJson"))
}

pub fn generate_has_all_hooks_test() {
  let js = extension_generator.generate()
  should.be_true(string.contains(js, "pi.on('agent_end'"))
  should.be_true(string.contains(js, "pi.on('agent_start'"))
  should.be_true(string.contains(js, "pi.on('before_agent_start'"))
  should.be_true(string.contains(js, "pi.on('tool_call'"))
  should.be_true(string.contains(js, "pi.on('tool_result'"))
}

pub fn generate_has_debounce_test() {
  let js = extension_generator.generate()
  should.be_true(string.contains(js, "setTimeout"))
  should.be_true(string.contains(js, "debounceMs"))
}

pub fn generate_has_system_prompt_hook_test() {
  let js = extension_generator.generate()
  should.be_true(string.contains(js, "systemPrompt: r.value"))
}

pub fn generate_no_raw_js_strings_test() {
  let js = extension_generator.generate()
  should.be_false(string.contains(js, "function unwrapGleamResult"))
  should.be_false(string.contains(js, "function gleamValueToJson"))
}

pub fn generate_no_send_message_in_hooks_test() {
  let js = extension_generator.generate()
  should.be_false(string.contains(js, "pi_extension_pi_send_message"))
}
