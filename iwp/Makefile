.PHONY: verify lint fmt types test test-fast db-up db-reset clean

UV ?= uv

verify: lint types test

lint:
	$(UV) run ruff check src tests
	$(UV) run ruff format --check src tests

fmt:
	$(UV) run ruff format src tests
	$(UV) run ruff check --fix src tests

types:
	$(UV) run mypy

test:
	$(UV) run pytest

test-fast:
	$(UV) run pytest -m "not slow"

db-up:
	./scripts/db-up.sh

db-reset:
	$(UV) run python -m iwp.db.migrate --reset

clean:
	rm -rf .pytest_cache .mypy_cache .ruff_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
