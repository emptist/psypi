# Gleam Code Quality Audit — 2026-05-20

## Summary
Reviewed all 70 Gleam source files (~8,600 lines) in `src/`. The architecture is solid — the PiToolCall generator pattern works well, FFI is properly isolated, and the extension.js auto-generation is correct. Main issues are code duplication and some dead code.

## Architecture Strengths
1. **PiToolCall generator pattern** — Clean separation: Gleam defines tools as values, generator composes JS text
2. **FFI isolation** — Only 2 FFI files (`pi_extension_ffi.mjs`, `node_ffi.mjs`), both use correct `new Ok(value)` / `new Error(error)` pattern
3. **Type safety** — Custom types for all domain concepts, exhaustive case expressions
4. **Pure Gleam where possible** — Uses `simplifile`, `gleam_json`, `filepath` instead of custom FFI
5. **Small modules** — Most modules are under 300 lines

## Issues Found

### High Priority
| Issue | File | Fix |
|-------|------|-----|
| TaskStatus decoder case mismatch | `task.gleam` | Add uppercase patterns to `string_to_status()` — **FIXED** |
| Insufficient shell escaping in commit | `tool_commit.gleam` | Properly sanitize all shell metacharacters |

### Medium Priority
| Issue | File | Fix |
|-------|------|-----|
| Duplicate `decode_all_results` in 6+ modules | Multiple | Extract to `src/decode_utils.gleam` |
| Duplicate `db_error_to_*` in ~17 modules | Multiple | Generic error handling approach |
| `config.gleam` get_env is a stub | `config.gleam` | Implement FFI or remove |
| `identity.gleam` redundant with `agent_identity.gleam` | `identity.gleam` | Remove or consolidate |
| `parse_context_window` uses string parsing | `hook_on_agent_end.gleam` | Use gleam_json decoder |
| `housekeeping()` is a test stub | `monitor_ai.gleam` | Remove or implement properly |
| `db.gleam` hardcodes project_id | `db.gleam` | Use env var |

### Low Priority
| Issue | File | Fix |
|-------|------|-----|
| Unused types in broadcast | `broadcast.gleam` | Remove or use properly |
| Unused position param in meeting | `meeting.gleam` | Remove parameter |

## Module Size Analysis
| Lines | File | Recommendation |
|-------|------|----------------|
| 607 | `monitor_ai.gleam` | Split into monitor_ai/, monitor_health/, monitor_suggest/ |
| 529 | `hook_on_agent_end.gleam` | Split into hook_agent_end/, prompt_builder/ |
| 513 | `pi_tool_call.gleam` | Acceptable — core type definitions |
| 404 | `meeting.gleam` | Split into meeting_db/, meeting_tools/ |
| 347 | `skill.gleam` | Split into skill_db/, skill_tools/ |
| 346 | `skill_loader.gleam` | Review — may be dead code |
| 328 | `extension_generator.gleam` | Acceptable — generator needs all imports |
| 327 | `inter_review.gleam` | Split into inter_review_db/, inter_review_tools/ |
| 320 | `broadcast.gleam` | Remove unused types first |
| 314 | `task.gleam` | Split into task_db/, task_tools/ |
| 310 | `issue_db.gleam` | Acceptable |
| 297 | `areflect.gleam` | Acceptable |
| 294 | `monitor.gleam` | Review — may be dead code |
| 272 | `event_hooks.gleam` | Acceptable |
| 248 | `directive.gleam` | Acceptable |
| 226 | `code_version.gleam` | Acceptable |

## Dead Code Analysis
- `src/identity.gleam` — Redundant with `agent_identity.gleam`
- `src/monitor.gleam` — May be dead (monitor_ai.gleam has the active code)
- `src/skill_loader.gleam` — May be dead (skill.gleam has the active code)
- `src/config_reader.gleam` — May be dead
- `src/activity_log.gleam` — May be dead
- `src/array_helpers.gleam` — May be dead
- `src/bitwise_ops.gleam` — May be dead
- `src/cache_utils.gleam` — May be dead
- `src/cmd_utils.gleam` — May be dead (replaced by simplifile)
- `src/context.gleam` — May be dead
- `src/data_utils.gleam` — May be dead
- `src/date_utils.gleam` — May be dead
- `src/encoding_utils.gleam` — May be dead
- `src/error_utils.gleam` — May be dead
- `src/execute_cmd.gleam` — May be dead (replaced by simplifile)
- `src/hash_utils.gleam` — May be dead
- `src/json_utils.gleam` — May be dead (replaced by gleam_json)
- `src/log_utils.gleam` — May be dead
- `src/math_ops.gleam` — May be dead
- `src/math_utils.gleam` — May be dead
- `src/package_json.gleam` — May be dead
- `src/path_utils.gleam` — May be dead (replaced by filepath)
- `src/result_utils.gleam` — May be dead
- `src/simple_migrate.gleam` — May be dead
- `src/string_ops.gleam` — May be dead
- `src/string_utils.gleam` — May be dead
- `src/system_info.gleam` — May be dead
- `src/text_ops.gleam` — May be dead
- `src/time_ops.gleam` — May be dead
- `src/time_utils.gleam` — May be dead
- `src/tool_consult.gleam` — Minimal (placeholder implementation)
- `src/validation.gleam` — May be dead
- `src/validation_utils.gleam` — May be dead

**Recommendation**: Audit all "May be dead" modules. If confirmed dead, move to `.deprecated/` directory.

## Gleam Best Practices Compliance

### ✅ Good
- Exhaustive case expressions (compiler enforces this)
- Custom types for domain concepts
- Pipe operator usage
- Proper FFI syntax with `@external`
- Type aliases for complex types
- Labelled arguments in functions

### ⚠️ Needs Improvement
- Module size (several > 300 lines)
- Code duplication (decode_all_results, db_error_to_*)
- Dead code cleanup
- Some modules use `list.map` + `list.try_map` where `list.try_fold` would be cleaner

### ❌ Anti-patterns Found
- String parsing JSON instead of using gleam_json decoder
- Hardcoded configuration values in source
- Test stubs left in production code
- Insufficient input sanitization (shell command injection risk)

*Audit by: S-agentbot on 2026-05-20*
