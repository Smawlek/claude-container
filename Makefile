.PHONY: build run shell claude yolo clean logs help

IMAGE_NAME   := claude-dev
PROJECT_PATH ?= ./workspace

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker compose build

run: ## Start a bash shell in the container
	docker compose run --rm claude

claude: ## Start Claude CLI interactively
	docker compose run --rm claude claude

yolo: ## Start Claude CLI in full auto mode (--dangerously-skip-permissions)
	docker compose run --rm claude yolo-claude

shell: ## Start a bash shell (alias for run)
	docker compose run --rm claude bash

clean: ## Remove the built image and stopped containers
	docker compose down --rmi local --remove-orphans

logs: ## Show Docker daemon logs from inside the container
	docker compose run --rm claude cat /tmp/dockerd.log
