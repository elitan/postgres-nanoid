#!/bin/bash
# Quick psql connection script
docker-compose exec postgres psql -U postgres -d nanoid_test "$@"