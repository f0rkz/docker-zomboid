.DEFAULT_GOAL := help

IMAGE_NAME ?= docker-zomboid

.PHONY: build down help integration logs run start stop test

help:
	@echo "Project Zomboid dedicated server"
	@echo
	@echo "Targets:"
	@echo "  build        Build the local image"
	@echo "  test         Run fast entrypoint tests"
	@echo "  integration  Download, start, and stop a real server"
	@echo "  run          Build and start the server"
	@echo "  logs         Follow server logs"
	@echo "  start        Start the existing server"
	@echo "  stop         Stop the server gracefully"
	@echo "  down         Remove the container and network (preserves data)"

build:
	docker build --tag "$(IMAGE_NAME):latest" .

test:
	bash tests/entrypoint.sh

integration:
	bash tests/integration.sh

run:
	docker compose up --detach --build

logs:
	docker compose logs --follow zomboid

start:
	docker compose start zomboid

stop:
	docker compose stop zomboid

down:
	docker compose down
