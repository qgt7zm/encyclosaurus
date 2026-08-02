from django.db import connection
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required, user_passes_test
from django.db import connection
from django.contrib import messages
from django.http import Http404

from dinosaur.views import DIET_VALUES, GAIT_VALUES

def staff_check(user):
    return user.is_authenticated and user.is_staff

def home(request):
    return render(request, 'encyclosaurus/base.html')

def login(request):
    return render(request, 'encyclosaurus/login.html')

@login_required(login_url='/login/') # redirect to your login URL
def submit_dinosaur(request):
    context = {
        'diet_values': DIET_VALUES,
        'gait_values': GAIT_VALUES,
    }
    return render(request, 'encyclosaurus/submit_dinosaur.html', context)

def interactive_map(request):
    # Get dinosaur data from the database
    dinos = []
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT d.id, d.genus, location_name, country, continent, latitude, longitude"
            " FROM DinosaurLocationSummaries dls"
            " JOIN Dinosaurs d ON d.genus = dls.dino_genus"
        )
        result = cursor.fetchall()

        for dino_id, dino_genus, location_name, country, continent, latitude, longitude in result:
            dino_info = {
                "id": dino_id,
                "genus": dino_genus,
                "location": continent.lower().replace(' ', '-'),
                "location_name": location_name,
                "country": country,
                "latitude": latitude,
                "longitude": longitude
            }
            dinos.append(dino_info)

    context = {
        "dinos": dinos
    }
    return render(request, 'encyclosaurus/interactive_map.html', context)

def browse_dinosaurs(request):
    dinos = []

    # Get form input
    keyword = request.GET.get("keyword", "")


    with connection.cursor() as cursor:
        if keyword == "":
            # No input or empty input
            cursor.execute(
                "SELECT id, genus, species, parent_name, range_start, range_end"
                " FROM DinosaurSummaries"
            )
        else:
            # String contains keyword, case-insensitive
            search_keyword = f"%{keyword}%"  # <Make sure % symbols are inside quotes
            cursor.execute(
                "SELECT id, genus, species, parent_name, range_start, range_end"
                " FROM DinosaurSummaries"
                " WHERE genus ILIKE %s OR species ILIKE %s OR parent_name ILIKE %s",
                [search_keyword, search_keyword, search_keyword]
            )
        result = cursor.fetchall()

        for dino_id, genus, species, parent_name, range_start, range_end in result:
            dino_info = {
                "id": dino_id,
                "genus": genus,
                "species": species,
                "clade": parent_name,
                "range_start": range_start,
                "range_end": range_end,
            }
            dinos.append(dino_info)

    context = {
        "dinos": dinos,
        "keyword": keyword
    }
    return render(request, 'encyclosaurus/browse_dinosaurs.html', context)

def view_dinosaur(request, dino_id):
    with connection.cursor() as cursor:
        context = get_all_dino_info(cursor, dino_id)
    return render(request, 'encyclosaurus/dinosaur_info.html', context)

@login_required(login_url='/login/') # redirect to your login URL
def update_dinosaur(request, dino_id):
    with connection.cursor() as cursor:
        context = get_all_dino_info(cursor, dino_id)
    context |= {
        'diet_values': DIET_VALUES,
        'gait_values': GAIT_VALUES,
    }
    return render(request, 'encyclosaurus/update_dinosaur.html', context)

@user_passes_test(staff_check, login_url='/login/') # redirect to your login URL
def requests(request):
    dino_requests = []
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT request_id, Researchers.institution, last_update_timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York' as local_time, status, details"
            " FROM Requests JOIN Researchers"
            " ON Requests.researcher_id = Researchers.id"
            " WHERE status = 'PENDING'"
            " ORDER BY last_update_timestamp DESC"
        )
        result = cursor.fetchall()

        for request_id, researcher_name, timestamp, status, details in result:
            request_info = {
                "id": request_id,
                "name": researcher_name,
                "timestamp": timestamp,
                "status": status,
                "details": details,
            }
            dino_requests.append(request_info)

    context = {
        "requests": dino_requests
    }
    return render(request, 'encyclosaurus/requests.html', context)

def accept_request(request, request_id):
    with connection.cursor() as cursor:
        cursor.execute(
            "UPDATE requests " +
            "SET status = 'APPROVED' " +
            "WHERE request_id = " + str(request_id) + ";"
        )
    messages.success(request, "The request has been accepted!")
    return requests(request)

def reject_request(request, request_id):
    with connection.cursor() as cursor:
        cursor.execute(
            "UPDATE requests " +
            "SET status = 'REJECTED' " +
            "WHERE request_id = " + str(request_id) + ";"
        )
    messages.success(request, "The request has been rejected!")
    return requests(request)

def logs(request):
    # Define the data structure that will store the log tables from the database.
    log = {
        "create": [],
        "delete": [],
        "update_status": [],
        "update_details": [],
    }
    
    # Retrieved all entries for the log tables and stored them in the data structure.
    with connection.cursor() as cursor:
        
        cursor.execute("SELECT request_id, researcher_id, timestamp FROM request_creation_log JOIN (Requests JOIN Researchers ON Requests.researcher_id = Researchers.id) USING(request_id);")
        log["create"] = cursor.fetchall()
    
        cursor.execute("SELECT request_id, researcher_id, timestamp FROM request_deletion_log JOIN (Requests JOIN Researchers ON Requests.researcher_id = Researchers.id) USING(request_id);")
        log["delete"] = cursor.fetchall()

        cursor.execute("SELECT request_id, researcher_id, timestamp, old_status, new_status FROM request_status_log JOIN (Requests JOIN Researchers ON Requests.researcher_id = Researchers.id) USING(request_id);")
        log["update_status"] = cursor.fetchall()

        cursor.execute("SELECT request_id, researcher_id, timestamp, old_details, new_details FROM request_details_log JOIN (Requests JOIN Researchers ON Requests.researcher_id = Researchers.id) USING(request_id);")
        log["update_details"] = cursor.fetchall()

    # Define the log table that will store all of the log entries.
    main_log = []

    # Add all of the entries where a request was created to the main log
    for entry in log["create"]:
        log_entry = set_core_log_entry_attributes(entry)

        request_id = log_entry["request_id"]
        researcher_id = log_entry["researcher_id"]
        timestamp = log_entry["timestamp"]

        log_entry["entry_text"] = "Researcher " + str(researcher_id) + " created Request " + str(request_id) + " on " + str(timestamp)

        add_log_entry(log_entry, main_log)

    # Add all of the entries where the status of a request was updated to the main log
    for entry in log["update_status"]:
        log_entry = set_core_log_entry_attributes(entry)

        request_id = log_entry["request_id"]
        researcher_id = log_entry["researcher_id"]
        timestamp = log_entry["timestamp"]

        old_status = entry[3]
        new_status = entry[4]

        log_entry["entry_text"] = "The status of Request " + str(request_id) + " was updated from " + old_status + " to " + new_status + " on " + str(timestamp)
        
        add_log_entry(log_entry, main_log)

    # Add all of the entries where the details of a request was updated to the main log
    for entry in log["update_details"]:
        log_entry = set_core_log_entry_attributes(entry)

        request_id = log_entry["request_id"]
        researcher_id = log_entry["researcher_id"]
        timestamp = log_entry["timestamp"]

        old_details = entry[3]
        new_details = entry[4]

        log_entry["entry_text"] = "Researcher " + str(researcher_id) + " updated the details of Request " + str(request_id) + " from " + old_details + " to " + new_details + " on " + str(timestamp)
        
        add_log_entry(log_entry, main_log)
    
    # Add all of the entries where a request was deleted to the main log
    for entry in log["delete"]:
        log_entry = set_core_log_entry_attributes(entry)

        request_id = log_entry["request_id"]
        researcher_id = log_entry["researcher_id"]
        timestamp = log_entry["timestamp"]

        log_entry["entry_text"] = "Researcher " + str(researcher_id) + " deleted Request " + str(request_id) + " on " + str(timestamp)
        
        add_log_entry(log_entry, main_log)
    
    context = {
        "log_table": main_log
    }
    
    return render(request, 'encyclosaurus/logs.html', context)

def set_core_log_entry_attributes(entry):
    # Define the data structure that will store the information for any log entry.
    log_entry = {
        "request_id": 0,
        "researcher_id": 0, 
        "timestamp": 0,
        "entry_text": "",
    }

    log_entry["request_id"] = entry[0]
    log_entry["researcher_id"] = entry[1]
    log_entry["timestamp"] = entry[2]

    return log_entry

def add_log_entry(entry, main_log):
    if (len(main_log) > 0):
        index = 0
        other_entry = main_log[index]

        while ((other_entry["timestamp"] > entry["timestamp"]) & (index < len(main_log))):
            index = index + 1
            other_entry = main_log[index]
            
        if (index < len(main_log)):
            main_log.insert(index, entry)
        else:
            main_log.append(entry)
    else:
        main_log.append(entry)

def get_all_dino_info(cursor, dino_id):
    # Check dino exists
    cursor.execute(
        "SELECT genus, species, parent_id,"
        " discoverer_name, discoverer_year, status,"
        " range_start, range_end,"
        " weight, \"length\", gait, habitat, diet,"
        " notes"
        " FROM Dinosaurs WHERE id = %s", [dino_id]
    )
    dino_info = cursor.fetchone()
    if dino_info is None:
        raise Http404(f"Dinosaur not found with id {dino_id}.")
    # Get dino facts
    (
        genus, species, parent_id,
        discoverer_name, discoverer_year, status,
        range_start, range_end,
        weight, length, gait, habitat, diet,
        notes
    ) = dino_info
    # Get related records
    clades = get_clade_tree(cursor, parent_id)
    locations = get_dino_locations(cursor, genus)
    context = {
        "id": dino_id,
        "genus": genus,
        "species": species,
        "parent_clade": clades[-1]["name"],
        "clades": clades,
        "discoverer_name": discoverer_name,
        "discoverer_year": discoverer_year,
        "status": status,
        "range_start": range_start,
        "range_end": range_end,
        "weight": weight,
        "length": length,
        "gait": gait,
        "habitat": habitat,
        "diet": diet,
        "locations": locations,
        "notes": notes if notes is not None else "",
    }
    return context

def get_dino_locations(cursor, genus):
    locations = []
    cursor.execute(
        "SELECT location_name, country, continent, latitude, longitude"
        " FROM DinosaurLocationSummaries WHERE dino_genus = %s", [genus]
    )
    result = cursor.fetchall()
    for location_name, country, continent, latitude, longitude in result:
        location = {
            "name": location_name,
            "country": country,
            "continent": continent,
            "latitude": latitude,
            "longitude": longitude,
        }
        locations.append(location)
    return locations

def get_clade_tree(cursor, parent_id):
    clades = []
    cursor.execute(
        "SELECT name, rank FROM Clades WHERE id = %s", [parent_id]
    )
    # While parent clade exists
    clade_name, clade_rank = cursor.fetchone()
    while clade_name is not None:
        clades.append({
            "name": clade_name,
            "rank": clade_rank,
        })
        cursor.execute(
            "SELECT parent_name, parent_rank FROM CladeParents WHERE name = %s", [clade_name]
        )
        clade_name, clade_rank = cursor.fetchone()
    clades.reverse()
    return clades
