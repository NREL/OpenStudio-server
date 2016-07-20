#!/bin/bash

# Main function to build and run the container
function run_docker {
  echo "Building Docker Containers"
  docker-compose -f docker-compose.yml -f docker-compose.test.yml build
  docker-compose -f docker-compose.yml -f docker-compose.test.yml up
}

run_docker()
