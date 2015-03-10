#!/bin/bash
# Bezier Curve Flight Paths Tutorial
# Written by: mark[at]dimensionaledge[dot]com
# Licence: GNU GPL version 3.0
# Start timer
START_T1=$(date +%s)
# DB Connection Settings
dbsettings="/mnt/data/common/repos/cf_private/settings/current.sh"
export dbsettings
source $dbsettings

#######################################
######### DATA PREPARATION ##########
#######################################
# bash function for downloading and ingesting tutorial data into PostgreSQL
fn_getdata() {
wget "http://www.mappinghacks.com/data/TM_WORLD_BORDERS_SIMPL-0.2.zip"
unzip TM_WORLD_BORDERS_SIMPL-0.2.zip
ogr2ogr -f "PostgreSQL" PG:"host=$host user=$username password=$password dbname=$dbname" $i -nln world_borders -s_srs EPSG:4326 -t_srs EPSG:4326 -a_srs EPSG:4326 -nlt MULTIPOLYGON
}
# end of bash function
# call the bash function or comment # to skip
fn_getdata 

# get sql custom functions
wget https://raw.githubusercontent.com/dimensionaledge/cf_public/master/lines/DE_BezierCurve2D.sql -O DE_BezierCurve2D.sql
# load sql custom functions
for i in *.sql; do
psql -U $username -d $dbname -f $i
done

# Create PostGIS tables
SQL=$(cat<<EOF
-------------------------
------- SQL BLOCK -------
------------------------- 
DROP TABLE IF EXISTS world_cities;
CREATE TABLE world_cities (
ogc_fid serial,
wkb_geometry geometry(Point,4326),
name character varying
);

INSERT INTO world_cities SELECT NEXTVAL('world_cities_ogc_fid_seq'), ST_SetSRID(ST_MakePoint(-118.408530, 33.941625),4326), 'Los Angeles';
INSERT INTO world_cities SELECT NEXTVAL('world_cities_ogc_fid_seq'), ST_SetSRID(ST_MakePoint(151.175276, -33.939878),4326), 'Sydney';
INSERT INTO world_cities SELECT NEXTVAL('world_cities_ogc_fid_seq'), ST_SetSRID(ST_MakePoint(140.392882, 35.771978),4326), 'Tokyo';

-------------------------
EOF
)
echo "$SQL" # comment to suppress printing
# execute SQL STATEMENT or comment # to skip
psql -U $username -d $dbname -c "$SQL" ### alternatively, comment out line with single '#' to skip this step

#######################################

#######################################
######### MAKE FLIGHT PATHS #########
#######################################
SQL=$(cat<<EOF
-------------------------
------- SQL BLOCK -------
------------------------- 
DROP TABLE IF EXISTS flight_paths;
CREATE TABLE flight_paths (
ogc_fid serial,
origin text,
destination text,
wkb_geometry geometry(MultiLinestring, 4326)
);

WITH
o AS (SELECT name, wkb_geometry FROM world_cities),
d AS (SELECT name, wkb_geometry FROM world_cities),
p AS (SELECT o.name as origin, d.name as destination, o.wkb_geometry as o_geom, d.wkb_geometry as d_geom FROM o,d WHERE o.name <> d.name)
INSERT INTO flight_paths SELECT NEXTVAL('flight_paths_ogc_fid_seq'), p.origin, p.destination, DE_BezierCurve2D(p.o_geom, p.d_geom, 25, 1000, 30) FROM p;

-------------------------
EOF
)
echo "$SQL" # comment to suppress printing
# execute SQL STATEMENT or comment # to skip
psql -U $username -d $dbname -c "$SQL" ### alternatively, comment out line with single '#' to skip this step

#######################################
#########   Visualisation in QGIS  #########
#######################################
# Refer to this link for description of how to centre map in the Pacific.
# http://gis.stackexchange.com/questions/70411/qgis-display-world-country-shape-files-centered-on-pacific-ocean-using-robinson
#  In QGIS, you need to add a custom CRS entry. The following proj string centres the map in the Pacific ocean, specifically at 150 degrees west of the prime meridian.  This corresponds to a breakval of 30 degrees in the bezier curve function
#  +proj=mill +lat_0=0 +lon_0=-150 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs
# In QGIS you need to set the Project CRS to your custom projection, making sure to enable 'on-the-fly' reprojection.

SQL=$(cat<<EOF
-------------------------
------- SQL BLOCK -------
------------------------- 
DROP TABLE IF EXISTS world_borders_split;
CREATE TABLE world_borders_split (
fid integer,
ogc_fid integer,
name text,
geometry geometry(Multipolygon, 4326)
);

INSERT INTO world_borders_split
WITH r AS (SELECT 30 as val),
s AS (SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[ST_MakePoint(val-0.0000001,90), ST_MakePoint(val+0.0000001,90), ST_MakePoint(val+0.0000001,-90), ST_MakePoint(val-0.0000001,-90), ST_MakePoint(val-0.0000001,90)])),4326) as split_geom FROM r)
SELECT row_number() over(), t1.ogc_fid, t1.name, ST_Multi(ST_Difference(t1.wkb_geometry, s.split_geom)) FROM world_borders t1, s;

-------------------------
EOF
)
echo "$SQL" # comment to suppress printing
# execute SQL STATEMENT or comment # to skip
psql -U $username -d $dbname -c "$SQL" ### alternatively, comment out line with single '#' to skip this step

# Now you should be able to open up world borders split (centred on the Pacific Ocean), and the flight paths we generated above.

# stop timer
END_T1=$(date +%s)
TOTAL_DIFF=$(( $END_T1 - $START_T1 ))
echo "TOTAL SCRIPT TIME: $TOTAL_DIFF"
# end of script
#######################################

