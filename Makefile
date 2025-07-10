.PHONY: help up down restart logs psql test clean

# Default target
help:
	@echo "Available commands:"
	@echo "  make up         - Start the PostgreSQL container"
	@echo "  make down       - Stop the PostgreSQL container"
	@echo "  make restart    - Restart the PostgreSQL container"
	@echo "  make logs       - Show container logs"
	@echo "  make psql       - Connect to PostgreSQL"
	@echo "  make test       - Show available tests"
	@echo "  make test-basic - Run basic functionality tests"
	@echo "  make test-bench - Run performance benchmarks"
	@echo "  make test-sort  - Run legacy sortability comparison"
	@echo "  make test-all   - Run all tests"
	@echo "  make clean      - Remove containers and volumes"

up:
	docker-compose up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker-compose exec postgres pg_isready -U postgres -d nanoid_test >/dev/null 2>&1; do \
		echo "Waiting for PostgreSQL..."; \
		sleep 1; \
	done
	@echo "PostgreSQL is ready!"

down:
	docker-compose down

restart:
	docker-compose restart
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker-compose exec postgres pg_isready -U postgres -d nanoid_test >/dev/null 2>&1; do \
		echo "Waiting for PostgreSQL..."; \
		sleep 1; \
	done
	@echo "PostgreSQL is ready!"

logs:
	docker-compose logs -f postgres

psql:
	./scripts/psql.sh

test:
	./scripts/test.sh

test-basic:
	./scripts/test.sh basic

test-bench:
	./scripts/test.sh benchmark

test-sort:
	./scripts/test.sh sortability

test-all:
	./scripts/test.sh all

clean:
	docker-compose down -v
	docker system prune -f