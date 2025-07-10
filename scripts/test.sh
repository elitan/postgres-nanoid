#!/bin/bash
# Run specific test or all tests

if [ $# -eq 0 ]; then
    echo "Available tests:"
    echo "  basic       - Basic functionality tests"
    echo "  benchmark   - Performance benchmarks"
    echo "  sortability - Legacy sortability comparison"
    echo "  all         - Run all tests"
    echo ""
    echo "Usage: $0 <test_name>"
    exit 1
fi

TEST_NAME="$1"

case $TEST_NAME in
    basic)
        echo "Running basic tests..."
        docker-compose exec postgres psql -U postgres -d nanoid_test -f /tests/basic_test.sql
        ;;
    benchmark)
        echo "Running benchmark tests..."
        docker-compose exec postgres psql -U postgres -d nanoid_test -f /tests/benchmark.sql
        ;;
    sortability)
        echo "Running legacy sortability comparison..."
        docker-compose exec postgres psql -U postgres -d nanoid_test -f /tests/sortability_test.sql
        ;;
    all)
        echo "Running all tests..."
        echo "=== BASIC TESTS ==="
        docker-compose exec postgres psql -U postgres -d nanoid_test -f /tests/basic_test.sql
        echo ""
        echo "=== LEGACY SORTABILITY COMPARISON ==="
        docker-compose exec postgres psql -U postgres -d nanoid_test -f /tests/sortability_test.sql
        echo ""
        echo "=== BENCHMARK TESTS ==="
        docker-compose exec postgres psql -U postgres -d nanoid_test -f /tests/benchmark.sql
        ;;
    *)
        echo "Unknown test: $TEST_NAME"
        echo "Run '$0' without arguments to see available tests."
        exit 1
        ;;
esac