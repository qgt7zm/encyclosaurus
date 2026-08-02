# Encyclosaurus

## Description

You've heard of _thesaurus_, now get ready for... Encyclosaurus!

Encyclosaurus is a comprehensive database of dinosaur taxa by researchers, for researchers. View taxonomic, biologic, ecologic, and temporal information for the latest discoveries. If you're not satisfied with the information, create your own researcher account and submit information requests for our team to review.

Going on an expedition? We've got you covered! Browse a world map with major excavation sites by taxa to plan your next trip. 

## My Contributions

I word with 3 other students to create this project for CS 4750 (Database Systems) at UVA. Throughout the course, we learned how to implement read-only views, stored procedures, union queries, and role-base access control. For finer contorl, we used raw SQL commands instead of the Django ORM. Our group also won the second-best class project.

I pitched the project idea and contributed the starter data. I created the browser dinosaurs view that lists entries and allows searching by keyword and attribute. I also created the dinosaur view that details information for individual entries, along with corresponding data from the locations table.

## Instructions

### Docker (Recommended)

1. Build the docker image and create the container: `./setup_docker.sh`.
2. Visit the development server: http://127.0.0.1:8000/.
3. Copy .env.blank into .env and enter your secret key and database credentials.
4. Terminate the development server: `docker compose stop`.

### Venv

1. (Optional) Create a Python virtual environment: `python3 -m venv venv/`.
2. Install project dependencies: `pip3 install -r requirements.txt`.
3. Copy .env.blank into .env and enter your secret key and database credentials.
4. Populate your database with the tables and records provided in init.sql.
5. Run the local development server: `python3 manage.py runserver`.
6. Visit the development server: http://127.0.0.1:8000/.
