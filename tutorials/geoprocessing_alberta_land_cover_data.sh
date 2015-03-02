#!/bin/bash
# Code for geoprocessing Alberta land cover data
# Written by: mark[at]dimensionaledge[dot]com
# Licence: GNU GPL version 3.0
# Start timer
START_T1=$(date +%s)

# DB Connection Settings
dbsettings="/mnt/data/common/repos/cf_private/settings/abmi.sh"
export dbsettings
source $dbsettings

#######################################
######### DATA PREPARATION ##########
#######################################
# bash function for downloading and ingesting required data into PostgreSQL
fn_getdata() {
#http://www.abmi.ca/home/data/gis-data/land-cover-download.html
# ftp to download the data
unzip ABMIw2wLCV2010v10.zip
# Load dataset into PostgreSQL
ogr2ogr -f "PostgreSQL" PG:"dbname=$dbname user=$username password=$password" ABMIw2wLCV2010_v10.gdb
}
# end of bash function
# call the bash function or comment # to skip
#fn_getdata 

# Create PostGIS tables (with indexes) for the dumped polygons and their rings
SQL=$(cat<<EOF 	 	
-------------------------	 	 
------- SQL BLOCK -------	 	 
-------------------------	 	 
DROP TABLE IF EXISTS landcover_dumped_34;	 	 
CREATE TABLE landcover_dumped_34 (
fid serial,
ogc_fid integer,
wkb_geometry geometry(Polygon, 3400),
lc_class integer,
mod_ty text,
shape_length float8,
shape_area float8
);

INSERT INTO landcover_dumped_34
SELECT
NEXTVAL('landcover_dumped_34_fid_seq'),
ogc_fid,
(ST_Dump(wkb_geometry)).geom,
lc_class,
mod_ty,
shape_length,
shape_area
FROM lancover_polygons_2010 WHERE lc_class = 34;

DROP TABLE IF EXISTS landcover_dumped_34_rings;	 	 
CREATE TABLE landcover_dumped_34_rings (
fid serial,
ogc_fid integer,
path integer,
wkb_geometry geometry(Polygon, 3400)
);

INSERT INTO landcover_dumped_34_rings
WITH s AS (SELECT ogc_fid, (ST_DumpRings(wkb_geometry)).path as path, ST_Buffer(ST_SnapToGrid((ST_DumpRings(wkb_geometry)).geom,0.1),0) as the_geom FROM  landcover_dumped_34)  --SNAP and BUFFER TO MAKEVALID
SELECT
NEXTVAL('landcover_dumped_34_rings_fid_seq'),
ogc_fid,
path[1],
the_geom
FROM s;

CREATE INDEX landcover_dumped_34_rings_wkb_geometry_idx ON landcover_dumped_34_rings USING GIST(wkb_geometry);
ANALYZE landcover_dumped_34_rings;

-------------------------	 	 
EOF
)
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT or comment # to skip		 	 
psql -U $username -d $dbname -c "$SQL"  ### alternatively, comment out line with single '#' to skip this step

#######################################

#######################################
#########  GRID CREATION  ##########
#######################################
# bash function for creating a regular vector grid in PostGIS
fn_generategrid() {
# get sql custom functions
wget https://raw.githubusercontent.com/dimensionaledge/cf_public/master/lattices/DE_RegularGrid.sql -O DE_RegularGrid.sql
wget https://raw.githubusercontent.com/dimensionaledge/cf_public/master/shapes/DE_MakeSquare.sql -O DE_MakeSquare.sql
# load sql custom functions
for i in *.sql; do
psql -U $username -d $dbname -f $i
done

SQL=$(cat<<EOF 	 	
-------------------------	 	 
------- SQL BLOCK -------	 	 
-------------------------
DROP TABLE IF EXISTS regular_grid_2k;
CREATE TABLE regular_grid_2k AS (
WITH s AS (SELECT DE_RegularGrid(ST_Envelope(ST_Collect(wkb_geometry)),2000) as wkb_geometry FROM abmiw2wlcv_48tiles)
SELECT row_number() over() as tid, wkb_geometry::geometry(Polygon, 3400) FROM s);

-------------------------	 	 
EOF
)
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT or comment # to skip	 	
psql -U $username -d $dbname -c "$SQL"
}
# end of bash function

# call the bash function or comment # to skip
fn_generategrid 

#######################################

#######################################
#########  TILE OUTPUT TABLE  #########
#######################################
SQL=$(cat<<EOF 	 	
-------------------------	 	 
------- SQL BLOCK -------	 	 
-------------------------
DROP TABLE IF EXISTS vector_tiles;
CREATE TABLE vector_tiles (
fid serial,
tid integer,
wkb_geometry geometry(Multipolygon, 3400),
fcat integer
);
------------------------- 
EOF
)
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT or comment # to skip		  	  	
psql -U $username -d $dbname -c "$SQL"

#######################################

#######################################
#####  DEFINE WORKER FUNCTION  ######
#######################################
# define the worker function to be executed across all cores
fn_worker (){
source $dbsettings
SQL=$(cat<<EOF
-------------------------
----- SQL STATEMENT -----
-------------------------
INSERT INTO vector_tiles
WITH
f0 AS (
		SELECT
		tid,
		wkb_geometry as the_geom
		FROM regular_grid_2k
		WHERE tid >= $1 AND tid < $2
		),
f1_p0 AS (
		SELECT
		f0.tid,
		CASE WHEN ST_Within(f0.the_geom,rt.wkb_geometry) THEN f0.the_geom
		ELSE ST_Intersection(f0.the_geom,rt.wkb_geometry) END as the_geom
		FROM f0, $3 as rt
		WHERE ST_Intersects(f0.the_geom, rt.wkb_geometry) AND f0.the_geom && rt.wkb_geometry AND rt.path = 0
		),
f1_p0u AS (
		SELECT
		tid,
		ST_Union(the_geom) as the_geom
		FROM f1_p0
		GROUP BY tid
		),
f1_p1 AS (
		SELECT
		f0.tid,
		CASE WHEN ST_Within(f0.the_geom,rt.wkb_geometry) THEN f0.the_geom
		ELSE ST_Intersection(f0.the_geom,rt.wkb_geometry)
		END as the_geom
		FROM f0, $3 as rt
		WHERE ST_Intersects(f0.the_geom, rt.wkb_geometry) AND f0.the_geom && rt.wkb_geometry AND rt.path > 0
		),
f1_p1u AS (
		SELECT
		tid,
		ST_Union(the_geom) as the_geom
		FROM f1_p1
		GROUP BY tid
		),
f2 AS (
		SELECT
		f1_p0u.tid,
		CASE WHEN  f1_p1u.tid IS NULL THEN f1_p0u.the_geom
		WHEN ST_IsEmpty(ST_Difference(f1_p0u.the_geom,f1_p1u.the_geom)) THEN NULL
		ELSE ST_Difference(f1_p0u.the_geom,f1_p1u.the_geom)
		END as the_geom
		FROM f1_p0u LEFT JOIN  f1_p1u
		ON f1_p0u.tid = f1_p1u.tid
		)
------------------------
---- result ----
------------------------
SELECT
NEXTVAL('vector_tiles_fid_seq'),
tid,
ST_Multi(the_geom),
1
FROM f2
WHERE the_geom IS NOT NULL;
-------------------------
EOF
)
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT
psql -U $username -d $dbname -c "$SQL"
}
# end of worker function

# make worker function visible to GNU Parallel across all cores
export -f fn_worker

#######################################

#######################################
##########  CREATE JOB LIST  ###########
#######################################
# create job list to feed GNU Parallel.  Included in the SQL block are different ways of chunking up the work.
SQL=$(cat<<EOF 	 	
-------------------------	 	 
------- SQL BLOCK -------	 	 
-------------------------
-- create joblist where block size = 1000 tiles (i.e. tiles processed in batches of 1000)
COPY (SELECT i as lower, i+1000 as upper FROM generate_series(1,250000,1000) i) TO STDOUT WITH CSV; 	 
-------------------------
EOF
)	 	 
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT 	
psql -U $username -d $dbname -c "$SQL" > joblist.csv

#######################################

#######################################
##########  EXECUTE JOBS  ###########
#######################################
cat joblist.csv | parallel --colsep ',' fn_worker {1} {2} landcover_dumped_34_rings
wait
#######################################

# stop timer
END_T1=$(date +%s)
TOTAL_DIFF=$(( $END_T1 - $START_T1 ))
echo "TOTAL SCRIPT TIME: $TOTAL_DIFF"

# end of script
#######################################
