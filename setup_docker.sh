#!/bin/sh
# Build the docker image and create the docker container

docker build -t django_docker . &&
    docker compose up -d --build &&
    echo "Done! View the website at http://localhost:8000" ||
    echo "Build finished with errors"
