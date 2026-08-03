#!/bin/sh
# Name: start_docker.sh
# Purpose: Build the docker image and create the docker container
# Usage: ./start_docker.sh

docker compose up -d --build &&
    docker compose exec web python manage.py migrate &&
    echo "Done! View the website at http://localhost:8000" ||
    echo "Build finished with errors"
