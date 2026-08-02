-- Dinosaur Database Initialization Script

-- Drop existing views first to avoid dependency issues
DROP VIEW IF EXISTS DinosaurLocationCounts;
DROP VIEW IF EXISTS DinosaurLocationSummaries;
DROP VIEW IF EXISTS DinosaurSummaries;
DROP VIEW IF EXISTS CladeParents;

-- Drop existing tables if they exist to avoid conflicts
DROP TABLE IF EXISTS request_details_log;
DROP TABLE IF EXISTS request_status_log;
DROP TABLE IF EXISTS request_deletion_log;
DROP TABLE IF EXISTS request_creation_log;
DROP TABLE IF EXISTS requests;
DROP TABLE IF EXISTS DinosaurLocations;
DROP TABLE IF EXISTS Locations;
DROP TABLE IF EXISTS Dinosaurs;
DROP TABLE IF EXISTS Clades;
DROP TABLE IF EXISTS Researchers;
DROP TABLE IF EXISTS Users;

-- 1. User Management System
-- Create Users table
CREATE TABLE Users (
    Id SERIAL PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    Email VARCHAR(255) NOT NULL UNIQUE,
    Password VARCHAR(255) NOT NULL,
    SiteManager BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create Researchers table with foreign key relationship to Users
CREATE TABLE Researchers (
    Id INTEGER PRIMARY KEY,
    Institution VARCHAR(255) NOT NULL,
    FOREIGN KEY (Id) REFERENCES Users(Id) ON DELETE CASCADE
);

-- 2. Taxonomic Classification System
-- Create Clades table
CREATE TABLE Clades (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE, -- Clade name should be unique
    rank TEXT NOT NULL DEFAULT 'Clade', -- Old taxonomic rank
    parent_id INT, -- Parent clade, should only be null if "root"
    FOREIGN KEY (parent_id) REFERENCES Clades(id)
);

-- Function to get clade id by name
CREATE OR REPLACE FUNCTION get_clade_id(
    clade_name TEXT
)
RETURNS INT
AS $$
DECLARE
    clade_id INT;
BEGIN
    SELECT id FROM Clades WHERE name = clade_name
    INTO clade_id;
RETURN clade_id;
END;
$$
LANGUAGE plpgsql;

-- Procedure to add a clade
CREATE OR REPLACE PROCEDURE create_clade(
    name TEXT,
    parent_name TEXT,
    rank TEXT DEFAULT 'Clade'
)
AS $$
BEGIN
    INSERT INTO Clades
    (name, parent_id, rank) VALUES
    (name, (SELECT get_clade_id(parent_name)), rank);
END;
$$
LANGUAGE plpgsql;

-- 3. Dinosaur Information
-- Create Dinosaurs table
CREATE TABLE Dinosaurs (
    id SERIAL PRIMARY KEY,
    
    -- Taxonomy
    genus TEXT NOT NULL,
    species TEXT NOT NULL,
    parent_id INT, -- Parent clade may be null if new discovery
    UNIQUE (genus, species), -- Binomial name must be unique
    FOREIGN KEY (parent_id) REFERENCES Clades(id)
        ON DELETE SET NULL, -- Don't delete dino if clade deleted
    
    -- Discovery
    discoverer_name TEXT NOT NULL, -- Usually last name
    discoverer_year INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Valid', -- Scientific consensus over taxa
    CHECK (discoverer_year > 0), -- Year should be positive

    -- Temporal range (million years ago)
    range_start FLOAT NOT NULL,
    range_end FLOAT NOT NULL,
    CHECK (range_start >= range_end), -- Start should be before (older than) end
    -- Though range could be zero if lacking data

    -- Physical features
    weight FLOAT NOT NULL, -- kilograms
    "length" FLOAT NOT NULL, -- meters
    gait TEXT NOT NULL,
    CHECK (weight > 0), -- Weight should be positive
    CHECK ("length" > 0), -- Length should be positive

    -- Ecology
    habitat TEXT NOT NULL,
    diet TEXT NOT NULL,

    -- Misc
    notes TEXT -- Additional notes for article
);

-- Procedure to add a dinosaur
CREATE OR REPLACE PROCEDURE create_dinosaur(
    genus TEXT,
    species TEXT,
    parent_name TEXT,
    discoverer_name TEXT,
    discoverer_year INT,
    range_start FLOAT,
    range_end FLOAT,
    weight FLOAT,
    "length" FLOAT,
    gait TEXT,
    habitat TEXT,
    diet TEXT
)
AS $$
BEGIN
    INSERT INTO Dinosaurs(
        genus, species, parent_id,
        discoverer_name, discoverer_year,
        range_start, range_end,
        weight, "length", gait,
        habitat, diet
    ) VALUES (
        genus, species, (SELECT get_clade_id(parent_name)),
        discoverer_name, discoverer_year,
        range_start, range_end,
        weight, "length", gait,
        habitat, diet
    );
END;
$$
LANGUAGE plpgsql;

-- 4. Location Information
-- Create Locations table
CREATE TABLE Locations (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE, -- Usually name of rock formation
    country TEXT NOT NULL,
    continent TEXT NOT NULL,
    
    -- Coordinates
    latitude FLOAT NOT NULL, -- North +90ยบ to South -90ยบ
    longitude FLOAT NOT NULL, -- East +180ยบ to West -180ยบ
    CHECK (latitude >= -90 AND latitude <= 90),
    CHECK (longitude >= -180 AND longitude <= 180)
);

-- Create DinosaurLocations junction table
CREATE TABLE DinosaurLocations (
    dino_id INT NOT NULL,
    location_id INT NOT NULL,
    FOREIGN KEY (dino_id) REFERENCES Dinosaurs(id)
        ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES Locations(id)
        ON DELETE CASCADE,
    PRIMARY KEY (dino_id, location_id)
);

-- Procedure to add dino location
CREATE OR REPLACE PROCEDURE create_dino_location(
    dino_genus TEXT,
    location_name TEXT
)
AS $$
BEGIN
    INSERT INTO DinosaurLocations
    (dino_id, location_id) VALUES
    (
        (SELECT id FROM Dinosaurs WHERE genus = dino_genus),
        (SELECT id FROM Locations WHERE name = location_name)
    );
END;
$$
LANGUAGE plpgsql;

-- 5. Request Management System
-- Create Requests table
CREATE TABLE requests (
    request_id SERIAL PRIMARY KEY, 
    researcher_id INT NOT NULL, 
    last_update_timestamp TIMESTAMP NOT NULL, 
    status TEXT NOT NULL, 
    details TEXT NOT NULL, 
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')), 
    FOREIGN KEY(researcher_id) REFERENCES Researchers(Id)
);

-- Create logging tables for request actions
CREATE TABLE request_creation_log (
    request_id INT PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL
);

CREATE TABLE request_deletion_log (
    request_id INT PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL
);

CREATE TABLE request_status_log (
    entry_id SERIAL PRIMARY KEY,
    request_id INT,
    timestamp TIMESTAMP NOT NULL,
    old_status TEXT NOT NULL,
    new_status TEXT NOT NULL
);

CREATE TABLE request_details_log (
    entry_id SERIAL PRIMARY KEY,
    request_id INT,
    timestamp TIMESTAMP NOT NULL,
    old_details TEXT NOT NULL,
    new_details TEXT NOT NULL
);

-- Request logging triggers
CREATE OR REPLACE FUNCTION update_request_creation_log() 
RETURNS TRIGGER AS $create_request_table$
BEGIN
    INSERT INTO request_creation_log(request_id, timestamp) 
    VALUES(NEW.request_id, CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$create_request_table$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER create_request_trigger 
AFTER INSERT ON requests 
FOR EACH ROW EXECUTE FUNCTION update_request_creation_log();

CREATE OR REPLACE FUNCTION update_request_deletion_log() 
RETURNS TRIGGER AS $delete_request_table$
BEGIN
    INSERT INTO request_deletion_log(request_id, timestamp) 
    VALUES(OLD.request_id, CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$delete_request_table$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER delete_request_trigger 
AFTER DELETE ON requests 
FOR EACH ROW EXECUTE FUNCTION update_request_deletion_log();

CREATE OR REPLACE FUNCTION update_request_status_log() 
RETURNS TRIGGER AS $request_status_table$
BEGIN
    IF (OLD.status <> NEW.status) THEN
        INSERT INTO request_status_log(request_id, timestamp, old_status, new_status) 
        VALUES(NEW.request_id, CURRENT_TIMESTAMP, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$request_status_table$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER request_status_update_trigger 
AFTER UPDATE ON requests 
FOR EACH ROW EXECUTE FUNCTION update_request_status_log();

CREATE OR REPLACE FUNCTION update_request_details_log() 
RETURNS TRIGGER AS $request_details_table$
BEGIN
    IF (OLD.details <> NEW.details) THEN
        INSERT INTO request_details_log(request_id, timestamp, old_details, new_details) 
        VALUES(NEW.request_id, CURRENT_TIMESTAMP, OLD.details, NEW.details);
    END IF;
    RETURN NEW;
END;
$request_details_table$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER request_details_update_trigger 
AFTER UPDATE ON requests 
FOR EACH ROW EXECUTE FUNCTION update_request_details_log();

-- 6. Views for Common Queries
-- View for clade hierarchy
CREATE OR REPLACE VIEW CladeParents AS
    SELECT Clades.name, Clades.rank,
    Parents.name AS parent_name, Parents.rank AS parent_rank
    FROM Clades LEFT JOIN Clades AS Parents
    ON Clades.parent_id = Parents.id
    ORDER BY Parents.name;

-- View for dinosaur summaries
CREATE OR REPLACE VIEW DinosaurSummaries AS
    SELECT Dinosaurs.id, genus, species, Clades.name AS parent_name,
        range_start, range_end
    FROM Dinosaurs LEFT JOIN Clades
        ON Dinosaurs.parent_id = Clades.id
    ORDER BY genus, species;

-- View for users + institution (if applicable)
CREATE OR REPLACE VIEW users_with_institutions AS
    SELECT u.Id, u.Username, u.Email, u.SiteManager,
    CASE 
        WHEN r.Institution IS NOT NULL THEN TRUE 
        ELSE FALSE 
    END AS is_researcher, r.Institution
    FROM Users u
    LEFT JOIN Researchers r ON u.Id = r.Id
    ORDER BY u.Id;

-- View for dinosaur locations
CREATE OR REPLACE VIEW DinosaurLocationSummaries AS
    SELECT Dinosaurs.genus AS dino_genus, Locations.name AS location_name,
        country, continent, latitude, longitude
    FROM DinosaurLocations JOIN Locations
        ON DinosaurLocations.location_id = Locations.id
    JOIN Dinosaurs
        ON DinosaurLocations.dino_id = Dinosaurs.id;

-- View for location dinosaur counts (with aggregate function)
CREATE OR REPLACE VIEW DinosaurLocationCounts AS
    SELECT location_name, country, continent, COUNT(dino_genus) AS count_dinos
    FROM DinosaurLocationSummaries
    GROUP BY location_name, country, continent
    ORDER BY location_name;

-- 7. Insert Sample Data
-- Insert sample Users
INSERT INTO Users (Username, Email, Password, SiteManager) VALUES
    ('admin1', 'admin1@example.com', 'hashed_password_123', TRUE),
    ('admin2', 'admin2@example.com', 'hashed_password_456', TRUE),
    ('researcher1', 'researcher1@university.edu', 'hashed_password_789', FALSE),
    ('researcher2', 'researcher2@institute.org', 'hashed_password_abc', FALSE),
    ('researcher3', 'researcher3@college.edu', 'hashed_password_def', FALSE),
    ('hybrid_user', 'hybrid@example.com', 'hashed_password_ghi', TRUE);

-- Insert sample Researchers
INSERT INTO Researchers (Id, Institution) VALUES
    (3, 'University of Science'),
    (4, 'Research Institute of Technology'),
    (5, 'College of Advanced Studies'),
    (6, 'Global Research Center');

-- Add example clades
CALL create_clade('Reptilia', NULL, 'Class');
CALL create_clade('Dinosauria', 'Reptilia');
CALL create_clade('Ornithischia', 'Dinosauria');
CALL create_clade('Saurischia', 'Dinosauria');
CALL create_clade('Sauropoda', 'Saurischia');
CALL create_clade('Theropoda', 'Saurischia');
CALL create_clade('Tyrannosauridae', 'Theropoda', 'Family');
CALL create_clade('Pterosauria', 'Reptilia', 'Order');

-- Add example dinosaurs (using original code)
CALL create_dinosaur(
    'Ankylosaurus', 'magniventis', 'Ornithischia',
    'Brown', 1908,
    68, 66,
    8000, 8, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Brachiosaurus', 'altithorax', 'Sauropoda',
    'Riggs', 1903,
    155, 143,
    46900, 22, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Diplodocus', 'carnegii', 'Sauropoda',
    'Hatcher', 1901,
    154, 152,
    14800, 26, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Sinraptor', 'dongi', 'Theropoda',
    'Currie and Zhao', 1994,
    160, 160,
    1300, 7.6, 'Bipedal',
    'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
    'Spinosaurus', 'aegyptiacus', 'Theropoda',
    'Stromer', 1015,
    100, 94,
    7400, 14, 'Bipedal',
    'Amphibious', 'Piscivore'
);
CALL create_dinosaur(
    'Stegosaurus', 'stenops', 'Ornithischia',
    'Marsh', 1877,
    155, 145,
    3500, 6.5, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Triceratops', 'horridus', 'Ornithischia',
    'Marsh', 1889,
    68, 66,
    10000, 9, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Tyrannosaurus', 'rex', 'Tyrannosauridae',
    'Osborn', 1905,
    72.7, 66,
    7224, 12.4, 'Bipedal',
    'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
    'Velociraptor', 'mongoliensis', 'Theropoda',
    'Osborn', 1924,
    75, 71,
    19.7, 2.1, 'Bipedal',
    'Terrestrial', 'Carnivore'
);

-- Add example locations (using original code)
INSERT INTO Locations
    (name, country, continent, latitude, longitude) VALUES
    ('Hell Creek Formation', 'United States', 'North America', 46.9, -101.5),
    ('Morrison Formation', 'United States', 'North America', 39.7, -105.2),
    ('Shishugou Formation', 'China', 'Asia', 44.5, 90.2)
    ON CONFLICT DO NOTHING;

-- Add dino-location associations
CALL create_dino_location('Tyrannosaurus', 'Hell Creek Formation');
CALL create_dino_location('Triceratops', 'Hell Creek Formation');
CALL create_dino_location('Stegosaurus', 'Morrison Formation');
CALL create_dino_location('Sinraptor', 'Shishugou Formation');

-- Add sample requests
INSERT INTO requests (researcher_id, last_update_timestamp, status, details) VALUES
    (3, NOW(), 'PENDING', 'Request to update the weight estimate for Tyrannosaurus rex to 9000kg based on new findings.'),
    (4, NOW(), 'APPROVED', 'Request to add a new fossil location for Velociraptor in the Nemegt Formation.'),
    (5, NOW(), 'REJECTED', 'Request to change the diet of Stegosaurus to omnivore - insufficient evidence.'),
    (3, NOW(), 'PENDING', 'Request to add newly discovered species Allosaurus jimmadseni.');
