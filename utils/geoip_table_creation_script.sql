-- For import: .mode csv
-- .import ipv4-city-blocks.csv ipv4_city_blocks
-- .import ipv6-city-blocks.csv ipv6_city_blocks
-- .import city_locations-en.csv city_locations

UPDATE ipv4_city_blocks SET network_start_integer = CAST(network_start_integer AS INTEGER);
UPDATE ipv4_city_blocks SET network_last_integer = CAST(network_last_integer AS INTEGER);
UPDATE ipv4_city_blocks SET geoname_id = CAST(geoname_id AS INTEGER);
UPDATE ipv4_city_blocks SET registered_country_geoname_id = CAST(registered_country_geoname_id AS INTEGER);
UPDATE ipv4_city_blocks SET represented_country_geoname_id = CAST(represented_country_geoname_id AS INTEGER);
UPDATE ipv4_city_blocks SET is_anonymous_proxy = CAST(is_anonymous_proxy AS INTEGER);
UPDATE ipv4_city_blocks SET is_satellite_provider = CAST(is_satellite_provider AS INTEGER);
--UPDATE ipv4_city_blocks SET postal_code = CAST(postal_code AS INTEGER);
UPDATE ipv4_city_blocks SET latitude = CAST(latitude AS REAL);
UPDATE ipv4_city_blocks SET longitude = CAST(longitude AS REAL);

UPDATE ipv6_city_blocks SET network_start_integer = CAST(network_start_integer AS INTEGER);
UPDATE ipv6_city_blocks SET network_last_integer = CAST(network_last_integer AS INTEGER);
UPDATE ipv6_city_blocks SET geoname_id = CAST(geoname_id AS INTEGER);
UPDATE ipv6_city_blocks SET registered_country_geoname_id = CAST(registered_country_geoname_id AS INTEGER);
UPDATE ipv6_city_blocks SET represented_country_geoname_id = CAST(represented_country_geoname_id AS INTEGER);
UPDATE ipv6_city_blocks SET is_anonymous_proxy = CAST(is_anonymous_proxy AS INTEGER);
UPDATE ipv6_city_blocks SET is_satellite_provider = CAST(is_satellite_provider AS INTEGER);
--UPDATE ipv6_city_blocks SET postal_code = CAST(postal_code AS INTEGER);
UPDATE ipv6_city_blocks SET latitude = CAST(latitude AS REAL);
UPDATE ipv6_city_blocks SET longitude = CAST(longitude AS REAL);

UPDATE city_locations SET geoname_id = CAST(geoname_id AS INTEGER);

CREATE TABLE ipv4_city_blocks_opt(network_start_integer INTEGER,network_last_integer INTEGER,geoname_id INTEGER,registered_country_geoname_id INTEGER,represented_country_geoname_id INTEGER,is_anonymous_proxy INTEGER,is_satellite_provider INTEGER,postal_code INTEGER,latitude REAL,longitude REAL);
CREATE TABLE ipv6_city_blocks_opt(network_start_integer INTEGER,network_last_integer INTEGER,geoname_id INTEGER,registered_country_geoname_id INTEGER,represented_country_geoname_id INTEGER,is_anonymous_proxy INTEGER,is_satellite_provider INTEGER,postal_code INTEGER,latitude REAL,longitude REAL);
CREATE TABLE city_locations_opt(geoname_id INTEGER,locale_code TEXT,continent_code TEXT,continent_name TEXT,country_iso_code TEXT,country_name TEXT,subdivision_1_iso_code TEXT,subdivision_1_name TEXT,subdivision_2_iso_code TEXT,subdivision_2_name TEXT,city_name TEXT,metro_code TEXT,time_zone TEXT);

INSERT INTO ipv4_city_blocks_opt SELECT * FROM ipv4_city_blocks;
INSERT INTO ipv6_city_blocks_opt SELECT * FROM ipv6_city_blocks;
INSERT INTO city_locations_opt SELECT * FROM city_locations;

DROP TABLE city_locations; 
DROP TABLE ipv4_city_blocks; 
DROP TABLE ipv6_city_blocks;

ALTER TABLE city_locations_opt RENAME TO city_locations; 
ALTER TABLE ipv4_city_blocks_opt RENAME TO ipv4_city_blocks; 
ALTER TABLE ipv6_city_blocks_opt RENAME TO ipv6_city_blocks;

VACUUM; --get rid of old data and rebuild database

-- Initial performance testing yielded that indexes had negative effect to the query speed.
--CREATE INDEX ip_block_index ON ipv4_city_blocks (network_start_integer, network_last_integer);
--CREATE INDEX ip_block_index ON ipv6_city_blocks (network_start_integer, network_last_integer);

--VACUUM;