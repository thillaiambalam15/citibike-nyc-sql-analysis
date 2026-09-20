-- Schema & fact table 
-- NOTE: run evertyhing in the given order

-- to create a new schema called citibike_trips 
CREATE SCHEMA IF NOT EXISTS citibike_trips;
USE citibike_trips;

-- to create a table with the following cols and dtypes
CREATE TABLE trips (
    ride_id VARCHAR(20),
    rideable_type VARCHAR(20),
    started_at DATETIME(3),
    ended_at DATETIME(3),
    start_station_name VARCHAR(100),
    start_station_id VARCHAR(20),
    end_station_name VARCHAR(100),
    end_station_id VARCHAR(20),
    start_lat DOUBLE,
    start_lng DOUBLE,
    end_lat DOUBLE,
    end_lng DOUBLE,
    member_casual VARCHAR(10)
);

-- ---------- Loading the data ----------
-- Adjust the file path to wherever your csv file sits inside mysql's
-- secure_file_priv directory (check with: SHOW VARIABLES LIKE 'secure_file_priv';)
-- then move your csv file to that folder, so as the mysql server can pull off the entire file at once
-- Point the LOAD DATA INFILE to csv file sitting inside the secure_file_priv' 
-- and run the  follwoing to import the data

-- noteL you can use this method to load the data faster comapred to the import data wizaed

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/citibike_trips_202604.csv'
INTO TABLE trips
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ride_id, rideable_type, started_at, ended_at, start_station_name, @start_station_id,
 end_station_name, @end_station_id, @start_lat, @start_lng, @end_lat, @end_lng, member_casual)
SET
    start_station_id = NULLIF(@start_station_id, ''),
    end_station_id   = NULLIF(@end_station_id, ''),
    start_lat = NULLIF(@start_lat, ''),
    start_lng = NULLIF(@start_lng, ''),
    end_lat   = NULLIF(@end_lat, ''),
    end_lng   = NULLIF(@end_lng, '');

-- adding indexes, not a mandatory thing, but sincve we have ~3.8M rows, this sure will help

ALTER TABLE trips ADD PRIMARY KEY (ride_id);
ALTER TABLE trips ADD INDEX idx_start_station (start_station_id);
ALTER TABLE trips ADD INDEX idx_end_station (end_station_id);

-- adding duration column 

ALTER TABLE trips ADD duration INT;

UPDATE trips
SET duration = TIMESTAMPDIFF(MINUTE, started_at, ended_at);

-- creating the stations dimension table 
-- Built from trips itself: one row per station with averaged lat and lon

CREATE TABLE stations (
    station_id VARCHAR(20) PRIMARY KEY,
    station_name VARCHAR(100),
    lat DOUBLE,
    lng DOUBLE
);


INSERT INTO stations (station_id, station_name, lat, lng)
SELECT start_station_id, start_station_name, AVG(start_lat), AVG(start_lng)
FROM trips
WHERE start_station_id IS NOT NULL AND start_station_name IS NOT NULL
GROUP BY start_station_id, start_station_name;


INSERT INTO stations (station_id, station_name, lat, lng)
SELECT t.end_station_id, t.end_station_name, AVG(t.end_lat), AVG(t.end_lng)
FROM trips t
LEFT JOIN stations s ON t.end_station_id = s.station_id
WHERE s.station_id IS NULL
  AND t.end_station_id IS NOT NULL AND t.end_station_name IS NOT NULL
GROUP BY t.end_station_id, t.end_station_name;

-- Sanity checks
-- SELECT COUNT(*) FROM trips;     -- expect 3,860,372
-- SELECT COUNT(*) FROM stations;  -- expect ~2,437
