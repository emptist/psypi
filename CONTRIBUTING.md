# Contributing to psypi

Thanks for your interest in contributing to psypi!

## Prerequisites

- [Gleam](https://gleam.run/) (≥ 1.0)
- [Node.js](https://nodejs.org/) (≥ 18)
- [PostgreSQL](https://www.postgresql.org/) (running on localhost:5432)
- [Pi](https://pi.dev/) (`npm install -g @earendil-works/pi-coding-agent`)

## Setup

```bash
make setup     # first-time: deps, DB, build, migrate, seed
make build     # rebuild after source changes
make migrate   # run DB migrations
make seed      # seed agent souls and jobs
make start     # start Pi with psypi
```

## Testing

```bash
gleam test     # run all tests
make test      # same, via Makefile
```

## Code Style

- **Pure Gleam** — no JS string literals in `.gleam` files
- **FFI via `@external`** — JS code goes in `src/*_ffi.mjs`, not inline
- **Append-only** for `agent_souls` and `agent_jobs` — never UPDATE in place, use `save_soul_version()` / `save_job_version()`
- **Parameterized queries** — never concatenate user input into SQL
- **No fake Gleam** — never create `pi_*.gleam` modules with JS content

## Architecture

See [AGENTS.md](AGENTS.md) for the full architecture guide, or [docs/](docs/) for design documents.

Key principles:
- A/S dual-agent model (alternating current, never simultaneous)
- `project_url()` from `process.cwd()` — never cache
- Identity computed fresh every call — never cached
- Errors via `pi.sendMessage()`, never `ctx.ui.notify()`

## PR Process

1. Fork and create a feature branch
2. Make changes, add tests if applicable
3. Run `gleam test` — all tests must pass
4. Commit with a clear message describing the change
5. Open a PR against `main`

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
