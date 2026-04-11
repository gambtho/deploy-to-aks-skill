.PHONY: build test test-llm test-all lint

build:                          ## Build monolithic SKILL.copilot.md for Copilot CLI
	python3 scripts/build-skill.py

test: build                     ## Run structural tests (rebuilds monolith first)
	pytest tests/structural/ -v

test-llm:                       ## Run LLM behavioral tests (requires Copilot CLI)
	pytest tests/llm/ -v --timeout=120 --reruns=1

test-all: test test-llm         ## Run all tests (structural + LLM)

lint:                           ## Lint test code
	ruff check tests/ scripts/
	ruff format --check tests/ scripts/
