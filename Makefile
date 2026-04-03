.PHONY: test test-llm test-all lint

test:                           ## Run structural tests
	pytest tests/structural/ -v

test-llm:                       ## Run LLM behavioral tests (requires Copilot CLI)
	pytest tests/llm/ -v --timeout=120 --reruns=1

test-all: test test-llm         ## Run all tests (structural + LLM)

lint:                           ## Lint test code
	ruff check tests/
	ruff format --check tests/
