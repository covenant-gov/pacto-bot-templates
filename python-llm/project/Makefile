.DEFAULT_GOAL := help

.PHONY: help install test validate clean

help: ## Show all targets and their summaries
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' | sort

install: ## Install the bot package in editable mode
	pip install -e bots/{{bot_id}}

test: ## Run the bot tests
	pytest bots/{{bot_id}}/tests

validate: ## Compile and test the bot
	python -m compileall bots/{{bot_id}}
	pytest bots/{{bot_id}}/tests

clean: ## Remove caches and virtual environment
	rm -rf .venv .pytest_cache
	find bots/{{bot_id}} -type d -name __pycache__ -exec rm -rf {} +
