.PHONY: setup build migrate seed start minimal clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Full first-time setup (deps, DB, build, migrate, seed)
	bash bin/setup.sh

build: ## Build Gleam → JS and regenerate extension.js
	rm -rf build/ && gleam build
	node bin/ppi.mjs --generate-only 2>/dev/null || gleam run -m extension_generator

migrate: ## Run database migrations
	gleam run -m simple_migrate

seed: ## Seed initial data (idempotent)
	gleam run -m seed

start: ## Start Pi with psypi
	node bin/ppi.mjs

minimal: ## Start Pi in minimal mode (no session/skills)
	node bin/ppi.mjs --minimal

clean: ## Clean build artifacts
	rm -rf build/ extension.js
