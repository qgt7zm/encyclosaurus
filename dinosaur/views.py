from django.shortcuts import render, redirect
from django.http import HttpResponse
from django.db import connection, transaction
from django.contrib import messages
from django.contrib.auth.decorators import login_required
import datetime
import logging

# Set up logger
logger = logging.getLogger(__name__)

username_max_length = 50
password_min_length = 8

DIET_VALUES = [
    'Carnivore',
    'Herbivore',
    'Omnivore',
    'Piscivore',
    'Insectivore',
]

GAIT_VALUES = [
    'Quadrupedal',
    'Bipedal',
    'Flying',
    'Swimming',
]


@login_required(login_url='/login/') # redirect to your login URL
def submit_request(request):
    # Check if the request method is POST
    if request.method != 'POST':
        return render(request, 'encyclosaurus/submit_dinosaur.html')
    
    # Debug: Log POST data
    logger.debug(f"POST data: {request.POST}")
    
    # Validate required fields
    required_fields = [
        'genus', 'species', 'parent_clade', 'discoverer_name',
        'discoverer_year', 'range_start', 'range_end', 'weight',
        'length', 'gait', 'habitat', 'diet', 'location_name',
        'country', 'continent', 'latitude', 'longitude'
    ]
    missing_fields = check_missing_fields(request.POST, required_fields)
    if len(missing_fields) != 0:
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'error_message': f'Missing required field(s): {", ".join(missing_fields)}'
        })

    # Get researcher ID from session or request
    try:
        researcher_id = request.user.id  # user authentication is not set up yet
    except:
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'error_message': 'User authentication required. Please log in.'
        })

    try:
        # Extract dinosaur data
        dinosaur = get_dino_data(request.POST)
        
        # Extract location data
        location = get_location_data(request.POST)
        
        # Debug information
        logger.debug(f"Dinosaur data: {dinosaur}")
        logger.debug(f"Location data: {location}")
    except Exception as e:
        logger.error(f"Error extracting form data: {str(e)}")
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'error_message': f'Error processing form data: {str(e)}'
        })
    
    # Validate dinosaur data
    valid_dino, dino_error = valid_dinosaur(dinosaur)
    if not valid_dino:
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'error_message': f'Invalid dinosaur details: {dino_error}'
        })
    
    # Validate location data
    valid_loc, loc_error = valid_location(location)
    if not valid_loc:
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'error_message': f'Invalid location details: {loc_error}'
        })
    
    # Process data inside a transaction
    try:
        with transaction.atomic():
            # Add dinosaur to database
            dino_id = add_dinosaur_to_database(dinosaur)
            
            # Add or get location and link to dinosaur
            location_id = add_location_to_database(location)
            
            # Link dinosaur to location
            link_dinosaur_to_location(dino_id, location_id)
            
            # Create request for review
            request_details = f"Request to add new dinosaur: {dinosaur['genus']} {dinosaur['species']} discovered by {dinosaur['discoverer_name']} in {dinosaur['discoverer_year']}."
            create_researcher_request(researcher_id, request_details)
            
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'success_message': 'Dinosaur submission successful! Your request is pending approval.',
            'diet_values': DIET_VALUES,
            'gait_values': GAIT_VALUES
        })
    except Exception as e:
        logger.error(f"Database error: {str(e)}")
        return render(request, 'encyclosaurus/submit_dinosaur.html', {
            'error_message': f'Error during database operation: {str(e)}'
        })

@login_required(login_url='/login/') # redirect to your login URL
def update_request(request):
    # Check if the request method is POST
    if request.method != 'POST':
        return render(request, 'encyclosaurus/update_dinosaur.html')

    # Debug: Log POST data
    logger.debug(f"POST data: {request.POST}")

    # Validate required fields
    required_fields = [
        'id',
        'genus', 'species', 'parent_clade', 'discoverer_name',
        'discoverer_year', 'range_start', 'range_end', 'weight',
        'length', 'gait', 'habitat', 'diet'
    ]

    missing_fields = check_missing_fields(request.POST, required_fields)
    if len(missing_fields) != 0:
        return render(request, 'encyclosaurus/update_dinosaur.html', {
            'error_message': f'Missing required field(s): {", ".join(missing_fields)}'
        })

    # Get researcher ID from session or request
    try:
        # researcher_id = request.user.id  # user authentication is not set up yet
        researcher_id = 18  # Placeholder for researcher ID, replace with actual user ID from session
    except:
        return render(request, 'encyclosaurus/update_dinosaur.html', {
            'error_message': 'User authentication required. Please log in.'
        })

    try:
        # Extract dinosaur data
        dinosaur = get_dino_data(request.POST)
        dinosaur["id"] = request.POST["id"]

        # Debug information
        logger.debug(f"Dinosaur data: {dinosaur}")
    except Exception as e:
        logger.error(f"Error extracting form data: {str(e)}")
        return render(request, 'encyclosaurus/update_dinosaur.html', {
            'error_message': f'Error processing form data: {str(e)}'
        })

    # Process data inside a transaction
    try:
        with transaction.atomic():
            dino_id = update_dinosaur_in_database(dinosaur)

            # Create request for review
            request_details = f"Request to update dinosaur: {dinosaur['genus']} {dinosaur['species']} discovered by {dinosaur['discoverer_name']} in {dinosaur['discoverer_year']}."
            create_researcher_request(researcher_id, request_details)

        # Add success message and redirect back to the dinosaur's detail page
        messages.success(request, 'Dinosaur update successful! Your request is pending approval.')
        return redirect(f'/dinosaurs/{dinosaur["id"]}')
    except Exception as e:
        logger.error(f"Database error: {str(e)}")
        return render(request, 'encyclosaurus/update_dinosaur.html', {
            'error_message': f'Error during database operation: {str(e)}'
        })


def get_location_data(form_data):
    return {
        "location_name": form_data["location_name"],
        "country": form_data["country"],
        "continent": form_data["continent"],
        "latitude": form_data["latitude"],
        "longitude": form_data["longitude"]
    }

def check_missing_fields(form_data, required_fields) -> list:
    missing = []
    for field in required_fields:
        if field not in form_data or not form_data[field]:
            missing.append(field)
    return missing

def get_dino_data(form_data):
    return {
        "genus": form_data["genus"],
        "species": form_data["species"],
        "parent_clade": form_data["parent_clade"],
        "discoverer_name": form_data["discoverer_name"],
        "discoverer_year": form_data["discoverer_year"],
        "range_start": form_data["range_start"],
        "range_end": form_data["range_end"],
        "weight": form_data["weight"],
        "length": form_data["length"],
        "gait": form_data["gait"],
        "habitat": form_data["habitat"],
        "diet": form_data["diet"],
        "notes": form_data.get("notes", "")
    }

def valid_dinosaur(dinosaur):
    # Check taxonomy information
    if not dinosaur["genus"] or not dinosaur["species"]:
        return False, "Genus and species are required"
    
    try:
        # Check if genus-species combo already exists
        if (dinosaur["genus"], dinosaur["species"]) in get_dinosaur_genus_species_in_database():
            return False, "A dinosaur with this genus and species already exists"
    except Exception as e:
        return False, f"Database error checking taxonomy: {str(e)}"
    
    # Check discovery information
    try:
        year = int(dinosaur["discoverer_year"])
        if year > datetime.datetime.now().year:
            return False, "Discovery year cannot be in the future"
    except (ValueError, TypeError):
        return False, "Invalid discovery year format"
    
    # Check temporal range
    try:
        range_start = float(dinosaur["range_start"])
        range_end = float(dinosaur["range_end"])
        if range_start < range_end:
            return False, "Range start must be greater than or equal to range end (older to newer)"
    except (ValueError, TypeError):
        return False, "Invalid temporal range format"
    
    # Check physical characteristics
    try:
        weight = float(dinosaur["weight"])
        length = float(dinosaur["length"])
        
        if weight <= 0:
            return False, "Weight must be greater than zero"
        
        if length <= 0:
            return False, "Length must be greater than zero"
        
        if not dinosaur["gait"] or dinosaur["gait"] not in GAIT_VALUES:
            return False, f"Gait must be {','.join(GAIT_VALUES)}"
    except (ValueError, TypeError):
        return False, "Invalid physical characteristics format"
    
    # Check ecology
    if not dinosaur["habitat"]:
        return False, "Habitat is required"
    
    if not dinosaur["diet"] or dinosaur["diet"] not in DIET_VALUES:
        print(dinosaur["diet"])
        return False, f"Diet must be {','.join(DIET_VALUES)}"
    
    return True, ""

def valid_location(location):
    # Check if all required fields are present
    if not location["location_name"]:
        return False, "Location name is required"
    
    if not location["country"]:
        return False, "Country is required"
    
    if not location["continent"]:
        return False, "Continent is required"
    
    # Check if latitude and longitude are valid
    try:
        lat = float(location["latitude"])
        lon = float(location["longitude"])
        
        # Validate latitude range (-90 to 90)
        if lat < -90 or lat > 90:
            return False, "Latitude must be between -90 and 90 degrees"
        
        # Validate longitude range (-180 to 180)
        if lon < -180 or lon > 180:
            return False, "Longitude must be between -180 and 180 degrees"
            
        return True, ""
    except (ValueError, TypeError):
        return False, "Invalid latitude or longitude format"

def get_dinosaur_genus_species_in_database():
    with connection.cursor() as cursor:
        cursor.execute("SELECT genus, species FROM dinosaurs")
        result = cursor.fetchall()
        dinosaur_genus_species = set()
        for id_pairing in result:
            dinosaur_genus_species.add(id_pairing)
    return dinosaur_genus_species

def get_clade_id_in_database(clade_name):
    with connection.cursor() as cursor:
        cursor.execute("SELECT id FROM clades WHERE name = %s", [clade_name])
        result = cursor.fetchall()
        if len(result) == 0:
            return None
        return result[0][0]

def add_dinosaur_to_database(dinosaur):
    parent_clade_id = get_clade_id_in_database(dinosaur["parent_clade"])

    with connection.cursor() as cursor:
        cursor.execute("""
            INSERT INTO dinosaurs(
                genus, species, parent_id,
                discoverer_name, discoverer_year,
                range_start, range_end,
                weight, length, gait,
                habitat, diet, notes, status
                ) 
            VALUES(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id""", 
            [dinosaur["genus"], dinosaur["species"], parent_clade_id,
            dinosaur["discoverer_name"], int(dinosaur["discoverer_year"]),
            float(dinosaur["range_start"]), float(dinosaur["range_end"]),
            float(dinosaur["weight"]), float(dinosaur["length"]), dinosaur["gait"],
            dinosaur["habitat"], dinosaur["diet"], dinosaur.get("notes", ""), "pending"]
        )
        
        # Get the ID of the newly inserted dinosaur
        result = cursor.fetchone()
        if not result:
            raise Exception("Failed to insert dinosaur record")
        return result[0]


def update_dinosaur_in_database(dinosaur):
    parent_clade_id = get_clade_id_in_database(dinosaur["parent_clade"])

    with connection.cursor() as cursor:
        cursor.execute("""
            UPDATE dinosaurs
                SET genus = %s, species = %s, parent_id = %s,
                    discoverer_name = %s, discoverer_year = %s,
                    range_start = %s, range_end = %s,
                    weight = %s, length = %s, gait = %s,
                    habitat = %s, diet = %s, notes = %s, status = %s
                WHERE id = %s""",
            [dinosaur["genus"], dinosaur["species"], parent_clade_id,
            dinosaur["discoverer_name"], int(dinosaur["discoverer_year"]),
            float(dinosaur["range_start"]), float(dinosaur["range_end"]),
            float(dinosaur["weight"]), float(dinosaur["length"]), dinosaur["gait"],
            dinosaur["habitat"], dinosaur["diet"], dinosaur.get("notes", ""), "revising",
            dinosaur["id"]]
        )

        # Get the ID of the updated dinosaur
        return dinosaur["id"]

def location_exists_in_database(location_name):
    """Check if a location already exists in the database"""
    with connection.cursor() as cursor:
        cursor.execute("SELECT id FROM locations WHERE name = %s", [location_name])
        result = cursor.fetchone()
        return result is not None

def get_location_id(location_name):
    """Get the ID for a location by name"""
    with connection.cursor() as cursor:
        cursor.execute("SELECT id FROM locations WHERE name = %s", [location_name])
        result = cursor.fetchone()
        return result[0] if result else None

def add_location_to_database(location):
    """Add a new location to the database if it doesn't exist"""
    # Check if location already exists
    location_id = get_location_id(location["location_name"])
    if location_id:
        return location_id
    
    # Add new location
    with connection.cursor() as cursor:
        cursor.execute("""
            INSERT INTO locations (name, country, continent, latitude, longitude)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """, [
            location["location_name"], 
            location["country"], 
            location["continent"],
            float(location["latitude"]),
            float(location["longitude"])
        ])
        result = cursor.fetchone()
        if not result:
            raise Exception("Failed to insert location record")
        return result[0]

def link_dinosaur_to_location(dino_id, location_id):
    """Link a dinosaur to a location using the junction table"""
    with connection.cursor() as cursor:
        cursor.execute("""
            INSERT INTO DinosaurLocations (dino_id, location_id)
            VALUES (%s, %s)
        """, [dino_id, location_id])

def create_researcher_request(researcher_id, details):
    """Create a new request entry for review"""
    with connection.cursor() as cursor:
        cursor.execute("""
            INSERT INTO requests (researcher_id, last_update_timestamp, status, details)
            VALUES (%s, NOW(), %s, %s)
            RETURNING request_id
        """, [researcher_id, "PENDING", details])
        result = cursor.fetchone()
        if not result:
            raise Exception("Failed to create researcher request")
        return result[0]