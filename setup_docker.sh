#!/bin/sh
# Build the docker image and create the docker container

docker build -t django_docker . &&
    docker compose up -d --build &&
    docker compose exec django-web python manage.py migrate &&
    echo "Done! View the website at http://localhost:8000" ||
    echo "Build finished with errors"
