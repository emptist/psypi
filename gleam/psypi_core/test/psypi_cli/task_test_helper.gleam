import gleam/dynamic

@external(javascript, "./task_test_helper.ffi.mjs", "makeTaskRow1")
pub fn make_task_row_1() -> dynamic.Dynamic

@external(javascript, "./task_test_helper.ffi.mjs", "makeTaskRow2")
pub fn make_task_row_2() -> dynamic.Dynamic

@external(javascript, "./task_test_helper.ffi.mjs", "makeIdRow")
pub fn make_id_row() -> dynamic.Dynamic
