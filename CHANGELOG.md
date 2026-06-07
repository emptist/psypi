# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-07

### Added
- A/S dual-agent architecture (Autonomic + Somatic) with alternating activation
- 44 Pi agent tools for task/issue/skill/meeting/memory/learning management
- 7 event hooks (agent_start, agent_end, tool_call, prompt_build, session, model_change, thinking)
- Identity resolution system with project-aware agent IDs
- Append-only versioning for agent_souls and agent_jobs
- PostgreSQL database layer via node_pg FFI
- Pi extension generator (Gleam → extension.js)
- DB migration runner (`simple_migrate`)
- Seed system for agent souls and jobs
- System review and finding tracking
- Broadcast and meeting system for cross-agent communication
- Learning insights and memory search

### Changed
- Replaced raw FFI file operations with `simplifile` library
- Fixed CWD resolution to use `process.cwd()` instead of Pi's `projectDir`
- Migrated `FnArgument`/`ParamSrc` type system for parameterized tool definitions

### Removed
- Dead code: `project_ffi.mjs`, `time_utils_ffi.mjs`, unused Node.js FFI functions
- Debug artifacts and session planning files
