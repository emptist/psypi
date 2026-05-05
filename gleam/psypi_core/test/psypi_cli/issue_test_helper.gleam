import gleam/dynamic

@external(javascript, "./issue_test_helper.ffi.mjs", "makeIssueRow1")
pub fn make_issue_row_1() -> dynamic.Dynamic

@external(javascript, "./issue_test_helper.ffi.mjs", "makeIssueRow2")
pub fn make_issue_row_2() -> dynamic.Dynamic

@external(javascript, "./issue_test_helper.ffi.mjs", "makeIdRow")
pub fn make_id_row() -> dynamic.Dynamic
