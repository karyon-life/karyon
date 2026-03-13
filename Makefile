.PHONY: all build clean up down deps help run run-server

all: deps build up

help:
	@echo "Karyon Organism Build System"
	@echo ""
	@echo "Targets:"
	@echo "  deps        Fetch Elixir dependencies"
	@echo "  build       Compile Elixir (and future Rust) components"
	@echo "  up          Start backing services (Memgraph, XTDB) via Docker"
	@echo "  down        Stop backing services"
	@echo "  run         Start backing services and launch app in IEx"
	@echo "  run-server  Start backing services and launch app in server mode"
	@echo "  clean       Remove build artifacts"

deps:
	cd app && mix deps.get

build:
	cd app/rhizome/native/rhizome_nif && cargo build --release
	cd app/sensory/native/sensory_nif && cargo build --release
	cd app && mix compile

up:
	docker compose up -d

down:
	docker compose down

test:
	cd app && mix test

test-native:
	cd app/rhizome/native/rhizome_nif && cargo test
	cd app/sensory/native/sensory_nif && cargo test

run: up
	./bin/run

run-server: up
	./bin/run --server

clean:
	cd app && mix clean
	cd app/rhizome/native/rhizome_nif && cargo clean
	cd app/sensory/native/sensory_nif && cargo clean
