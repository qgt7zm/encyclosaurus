--
-- Encyclosaurus Database Initialization Script
-- Postgres Version: 17+
--

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

-- Procedure to update dino clade
CREATE OR REPLACE PROCEDURE set_dino_clade(
    dino_genus TEXT,
    clade_name TEXT
)
AS $$
BEGIN
    UPDATE Dinosaurs
        SET parent_id = (SELECT get_clade_id(clade_name))
        WHERE genus = dino_genus;
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
    diet TEXT,
    notes TEXT DEFAULT ''
)
AS $$
BEGIN
    INSERT INTO Dinosaurs(
        genus, species, parent_id,
        discoverer_name, discoverer_year,
        range_start, range_end,
        weight, "length", gait,
        habitat, diet, notes
    ) VALUES (
        genus, species, (SELECT get_clade_id(parent_name)),
        discoverer_name, discoverer_year,
        range_start, range_end,
        weight, "length", gait,
        habitat, diet, notes
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
    latitude FLOAT NULL, -- North +90º to South -90º
    longitude FLOAT NOT NULL, -- East +180º to West -180º
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
    SELECT Clades.name, Clades.rank, Parents.name AS parent_name, Parents.rank AS parent_rank
    FROM Clades LEFT JOIN Clades AS Parents
    ON Clades.parent_id = Parents.id
    ORDER BY Parents.name;

-- View for dinosaur summaries
CREATE OR REPLACE VIEW DinosaurSummaries AS
    SELECT Dinosaurs.id, genus, species, Clades.name AS parent_name,
        discoverer_name, discoverer_year,
        range_start, range_end,
        "length", weight, gait, diet
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
    ('hybrid_user', 'hybrid@example.com', 'hashed_password_ghi', TRUE),
    ('alan_grant93', 'alangrant@jurassicpark.org', 'ilovedinos123', FALSE);

-- Insert sample Researchers
INSERT INTO Researchers (Id, Institution) VALUES
    (1, 'University of Science'),
    (2, 'Research Institute of Technology'),
    (3, 'College of Advanced Studies'),
    (4, 'Global Research Center'),
    (5, 'Mad Science Labs');

-- Add example clades
CALL create_clade('Reptilia', NULL, 'Class');
CALL create_clade('Dinosauria', 'Reptilia');
CALL create_clade('Ornithischia', 'Dinosauria');
CALL create_clade('Saurischia', 'Dinosauria');
CALL create_clade('Sauropoda', 'Saurischia');
CALL create_clade('Theropoda', 'Saurischia');
CALL create_clade('Pterosauria', 'Reptilia', 'Order');
CALL create_clade('Ichthyosaurua', 'Reptilia');
CALL create_clade('Mosasauria', 'Reptilia');
CALL create_clade('Plesiosauria', 'Reptilia');
CALL create_clade('Ceratopsia', 'Ornithischia');
CALL create_clade('Thyreophora', 'Ornithischia');
CALL create_clade('Ankylosauria', 'Thyreophora');
CALL create_clade('Stegosauria', 'Thyreophora');
CALL create_clade('Tyrannosauridae', 'Theropoda', 'Family');
CALL create_clade('Diplodocidae', 'Sauropoda', 'Family');
CALL create_clade('Paraves', 'Theropoda');
CALL create_clade('Ceratosauria', 'Theropoda');
CALL create_clade('Carnosauria', 'Theropoda');
CALL create_clade('Allosauria', 'Carnosauria');
CALL create_clade('Spinosauridae', 'Carnosauria', 'Family');

-- Add example dinosaurs (using original code)

CALL create_dinosaur(
    'Allosaurus', 'fragilis', 'Allosauria',
    'Marsh', 1877,
    155, 143.1,
    2400, 8.5, 'Bipedal',
    'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
    'Ankylosaurus', 'magniventis', 'Ankylosauria',
    'Brown', 1908,
    68, 66,
    8000, 8, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Apatosaurus', 'ajax', 'Diplodocidae',
    'Marsh', 1877,
    152, 151,
    22400, 23, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
	'Archaeopteryx', 'lithographica', 'Paraves',
	'Meyer', 1861,
	150.8, 148.5,
	1, 0.5, 'Bipedal',
	'Arboreal', 'Carnivore',
	'One of the first airborne non-avian dinosaurs discovered.'
);
CALL create_dinosaur(
    'Brachiosaurus', 'altithorax', 'Sauropoda',
    'Riggs', 1903,
    155, 143,
    46900, 22, 'Quadrupedal',
    'Terrestrial', 'Herbivore',
    'This dinosaur appeared in the opening of the Jurassic Park film.'
);
CALL create_dinosaur(
	'Brontosaurus', 'excelsus', 'Sauropoda',
	'Marsh', 1879,
	156.3, 146.8,
	17000, 22, 'Quadrupedal',
	'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
	'Carcharodontosaurus', 'saharicus', 'Allosauria',
	'Stromer', 1931,
	100, 94,
	7000, 12.5, 'Bipedal',
	'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
	'Carnotaurus', 'sastrei', 'Ceratosauria',
	'Bonaparte', 1985,
	72, 69,
	2100, 8, 'Bipedal',
	'Terrestrial', 'Carnivore',
	'This dinosaur''s arms are even smaller than those of T. rex, having only one claw.'
);
CALL create_dinosaur(
	'Coelophysis', 'bauri', 'Theropoda',
	'Cope', 1887,
	215, 208.5,
	20, 3, 'Bipedal',
	'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
	'Compsognathus', 'longipes', 'Theropoda',
	'Wagner', 1859,
	150.8, 145,
	3.5, 1.4, 'Bipedal',
	'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
	'Confuciusornis', 'sanctus', 'Paraves',
	'Hou et al.', 1995,
	125, 120,
	0.7, 0.2, 'Bipedal',
	'Arboreal', 'Carnivore'
);
CALL create_dinosaur(
	'Cryolophosaurus', 'ellioti', 'Theropoda',
	'Hammer & Hickerson', 1994,
	186, 182,
	465, 7, 'Bipedal',
	'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
    'Diplodocus', 'carnegii', 'Diplodocidae',
    'Hatcher', 1901,
    154, 152,
    14800, 26, 'Quadrupedal',
    'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Dilophosaurus', 'wetherilli', 'Theropoda',
    'Welles', 1954,
    195.2, 183.7,
    400, 7, 'Bipedal',
    'Terrestrial', 'Carnivore',
    'Unlike the depiction in the Jurassic Park movie, this dinosaur does not spit acid.'
);
CALL create_dinosaur(
	'Giganotosaurus', 'carolinii', 'Allosauria',
	'Coria & Salgado', 1995,
	99.6, 95,
	13800, 13, 'Bipedal',
	'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
	'Hadrosaurus', 'foulkii', 'Ornithischia',
	'Leidy', 1858,
	83.6, 77.9,
	4000, 8, 'Bipedal',
	'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
    'Ichthyosaurus', 'communis', 'Ichthyosauria',
    'De la Beche and Conybeare', 1821,
    201.3, 184.2,
    1200, 3, 'Swimming',
    'Aquatic', 'Carnivore',
    'This marine reptile lived alongside dinosaurs and gave birth to live young.'
);
CALL create_dinosaur(
	'Iguanodon', 'bernissartensis', 'Ornithischia',
	'Boulenger', 1825,
	126, 122,
	4500, 10, 'Quadrupedal',
	'Terrestrial', 'Herbivore',
	'The second dinosaur genus ever discovered.'
);
CALL create_dinosaur(
	'Kentrosaurus', 'aethiopicus', 'Stegosauria',
	'Hennig', 1915,
	152, 152,
	1600, 4.5, 'Quadrupedal',
	'Terrestrial', 'Herbivore'
);
CALL create_dinosaur(
	'Mamenchisaurus', 'constructus', 'Sauropoda',
	'Young', 1954,
	161, 114.4,
	5000, 26, 'Quadrupedal',
	'Terrestrial', 'Herbivore',
	'This dinosaur''s neck stretched for half its entire length.'
);
CALL create_dinosaur(
	'Megalosaurus', 'bucklandii', 'Carnosauria',
	'Buckland', 1824,
	166, 165,
	700, 6, 'Bipedal',
	'Terrestrial', 'Carnivore',
	'The first dinosaur fossil discovered.'
);
CALL create_dinosaur(
	'Oviraptor', 'philoceratops', 'Theropoda',
	'Osborn', 1924,
	75, 71,
	40, 2, 'Bipedal',
	'Terrestrial', 'Carnivore',
	'This dinosaur was mistakenly believed to prey on eggs after being found guarding its nest.'
);
CALL create_dinosaur(
	'Pachycephalosaurus', 'wyomingensis', 'Ornithischia',
	'Brown & Schlaikjer', 1943,
	70, 66,
	450, 4.5, 'Bipedal',
	'Terrestrial', 'Herbivore',
	'This dinosaur had a thick skull for head-butting its competition.'
);
CALL create_dinosaur(
	'Protoceratops', 'andrewsi', 'Ornithischia',
	'Granger & Gregory', 1923,
	75, 71,
	104, 2.5, 'Quadrupedal',
	'Terrestrial', 'Herbivore',
	'This dinosaur is famously preserved locked in combat with Velociraptor.'
);
CALL create_dinosaur(
    'Sinraptor', 'dongi', 'Theropoda',
    'Currie and Zhao', 1994,
    160, 160,
    1300, 7.6, 'Bipedal',
    'Terrestrial', 'Carnivore'
);
CALL create_dinosaur(
    'Spinosaurus', 'aegyptiacus', 'Spinosauridae',
    'Stromer', 1915,
    100, 94,
    7400, 14, 'Bipedal',
    'Amphibious', 'Piscivore',
    'Scientists are unsure if Spinosaurus was terrestrial or aquatic.'
);
CALL create_dinosaur(
    'Stegosaurus', 'stenops', 'Stegosauria',
    'Marsh', 1877,
    155, 145,
    3500, 6.5, 'Quadrupedal',
    'Terrestrial', 'Herbivore',
    'The set of spikes at the end of Stegosaurus''s tail is known as a ''thagomizer.'''
);
CALL create_dinosaur(
	'Suchomimus', 'tenerensis', 'Spinosauridae',
	'Sereno et al.', 1998,
	125, 112,
	3800, 11, 'Bipedal',
	'Terrestrial', 'Piscivore'
);
CALL create_dinosaur(
	'Thanos', 'simonattoi', 'Ceratosauria',
	'Delcour and Iori', 2020,
	86, 83,
	1800, 6.5, 'Bipedal',
	'Terrestrial', 'Carnivore',
	'This dinosaur was named after the Marvel Character.'
);
CALL create_dinosaur(
	'Therizinosaurus', 'cheloniformis', 'Theropoda',
	'Maleev', 1954,
	70, 70,
	5000, 10, 'Bipedal',
	'Terrestrial', 'Herbivore',
	'This dinosaur possessed three massive claws on each of its hands.'
);
CALL create_dinosaur(
    'Triceratops', 'horridus', 'Ceratosauria',
    'Marsh', 1889,
    68, 66,
    10000, 9, 'Quadrupedal',
    'Terrestrial', 'Herbivore',
    'This dinosaur is famous for having three large horns on its face.'
);
CALL create_dinosaur(
    'Tyrannosaurus', 'rex', 'Tyrannosauridae',
    'Osborn', 1905,
    72.7, 66,
    7224, 12.4, 'Bipedal',
    'Terrestrial', 'Carnivore',
    'This dinosaur is so famous that we refer to it by its genus and species—T. rex.'
);
CALL create_dinosaur(
    'Velociraptor', 'mongoliensis', 'Paraves',
    'Osborn', 1924,
    75, 71,
    19.7, 2.1, 'Bipedal',
    'Terrestrial', 'Carnivore',
    'This dinosaur is famously preserved locked in combat with Protoceratops.'
);
CALL create_dinosaur(
	'Yutyrannus', 'huali', 'Tyrannosauridae',
	'Xu et al.', 2012,
	125, 125,
	1400, 9, 'Bipedal',
	'Terrestrial', 'Carnivore'
);

-- Add example locations (using original code)
INSERT INTO Locations
    (name, country, continent, latitude, longitude) VALUES
    ('Bahariya Formation', 'Egypt', 'Africa', 28.41, 28.81),
    ('Candeleros Formation', 'Argentina', 'South America', -39.4, -69.2),
    ('Djadochta Formation', 'Mongolia', 'Asia', 44.14, 103.73),
    ('Elrhaz Formation', 'Niger', 'Africa', 16.8, 9.5),
    ('Hanson Formation', 'Ross Dependency', 'Antarctica', -84.3, 166.5),
    ('Hell Creek Formation', 'United States', 'North America', 46.9, -101.5),
    ('Kayenta Formation', 'United States', 'North America', 37.8, -110.6),
    ('Kem Kem Group', 'Morocco', 'Africa', 32.5, -4.50),
    ('La Colonia Formation', 'Argentina', 'South America', -43, -67.5),
    ('Lance Creek Formation', 'United States', 'North America', 43.05, -104.66),
    ('Lower Greensand Group', 'England', 'Europe', 51.27, 0.53),
    ('Lyme Regis', 'England', 'Europe', 50.73, -2.93),
    ('Morrison Formation', 'United States', 'North America', 39.7, -105.2),
    ('Nemegt Formation', 'Mongolia', 'Asia', 43.5, 101),
    ('Oxfordshire', 'England', 'Europe', 51.75, -1.28),
    ('São José do Rio Preto', 'Brazil', 'South America', -20.81, -49.38),
    ('Scollard Formation', 'Canada', 'North America', 51.94, -112.93),
    ('Shaximiao Formation', 'China', 'Asia', 29.2, 105.9),
    ('Shishugou Formation', 'China', 'Asia', 44.5, 90.2),
    ('Solnhofen Limestone', 'Germany', 'Europe', 48.90, 11),
    ('Tendaguru Formation', 'Tanzania', 'Africa', -9.7, 39.2),
    ('Todilto Formation', 'United States', 'North America', 35.91, -100.96),
    ('Woodbury Formation', 'United States', 'North America', 39.95, -75.05),
    ('Yixian Formation', 'China', 'Asia', 41.53, 121.24)
    ON CONFLICT DO NOTHING;

-- Add dino-location associations
CALL create_dino_location('Allosaurus', 'Morrison Formation');
CALL create_dino_location('Ankylosaurus', 'Hell Creek Formation');
CALL create_dino_location('Apatosaurus', 'Morrison Formation');
CALL create_dino_location('Archaeopteryx', 'Solnhofen Limestone');
CALL create_dino_location('Brachiosaurus', 'Morrison Formation');
CALL create_dino_location('Brontosaurus', 'Morrison Formation');
CALL create_dino_location('Carcharodontosaurus', 'Kem Kem Group');
CALL create_dino_location('Carnotaurus', 'La Colonia Formation');
CALL create_dino_location('Coelophysis', 'Todilto Formation');
CALL create_dino_location('Compsognathus', 'Solnhofen Limestone');
CALL create_dino_location('Confuciusornis', 'Yixian Formation');
CALL create_dino_location('Cryolophosaurus', 'Hanson Formation');
CALL create_dino_location('Dilophosaurus', 'Kayenta Formation');
CALL create_dino_location('Diplodocus', 'Morrison Formation');
CALL create_dino_location('Giganotosaurus', 'Candeleros Formation');
CALL create_dino_location('Hadrosaurus', 'Woodbury Formation');
CALL create_dino_location('Ichthyosaurus', 'Lyme Regis');
CALL create_dino_location('Iguanodon', 'Lower Greensand Group');
CALL create_dino_location('Kentrosaurus', 'Tendaguru Formation');
CALL create_dino_location('Mamenchisaurus', 'Shaximiao Formation');
CALL create_dino_location('Megalosaurus', 'Oxfordshire');
CALL create_dino_location('Oviraptor', 'Djadochta Formation');
CALL create_dino_location('Pachycephalosaurus', 'Hell Creek Formation');
CALL create_dino_location('Protoceratops', 'Djadochta Formation');
CALL create_dino_location('Sinraptor', 'Shishugou Formation');
CALL create_dino_location('Spinosaurus', 'Bahariya Formation');
CALL create_dino_location('Spinosaurus', 'Kem Kem Group');
CALL create_dino_location('Stegosaurus', 'Morrison Formation');
CALL create_dino_location('Suchomimus', 'Elrhaz Formation');
CALL create_dino_location('Thanos', 'São José do Rio Preto');
CALL create_dino_location('Therizinosaurus', 'Nemegt Formation');
CALL create_dino_location('Triceratops', 'Hell Creek Formation');
CALL create_dino_location('Tyrannosaurus', 'Hell Creek Formation');
CALL create_dino_location('Tyrannosaurus', 'Lance Creek Formation');
CALL create_dino_location('Tyrannosaurus', 'Scollard Formation');
CALL create_dino_location('Velociraptor', 'Djadochta Formation');
CALL create_dino_location('Velociraptor', 'Nemegt Formation');
CALL create_dino_location('Yutyrannus', 'Yixian Formation');

-- Add sample requests
INSERT INTO requests (researcher_id, last_update_timestamp, status, details) VALUES
    (1, NOW(), 'PENDING', 'Request to update the weight estimate for Tyrannosaurus rex to 9000kg based on new findings.'),
    (2, NOW(), 'APPROVED', 'Request to add a new fossil location for Velociraptor in the Nemegt Formation.'),
    (3, NOW(), 'REJECTED', 'Request to change the diet of Stegosaurus to omnivore - insufficient evidence.'),
    (4, NOW(), 'PENDING', 'Request to add newly discovered species Allosaurus jimmadseni.'),
    (5, NOW(), 'PENDING', 'Request to change method of locomotion of Spinosaurus to flying.');
