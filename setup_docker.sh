#!/bin/sh
# Build the docker image and create the docker container

docker compose up -d --build &&
    docker compose exec web python manage.py migrate &&
    echo "Done! View the website at http://localhost:8000" ||
    echo "Build finished with errors"
