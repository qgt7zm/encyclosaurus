# Source: https://www.docker.com/blog/how-to-dockerize-django-app/

# Python version
FROM python:3.14-slim

# App directory
RUN mkdir /app
WORKDIR /app
# COPY . /app/ # Production: Ship website with image

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Pip packages
RUN pip install --upgrade pip
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Database initialization
COPY init.sql /docker-entrypoint-initdb.d/

# Django server
EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
