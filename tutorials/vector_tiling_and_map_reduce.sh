#!/bin/bash
# A tutorial that introduces the concepts of vector tiling and Map Reduce in PostGIS
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
# bash function for downloading and ingesting required data into PostgreSQL
fn_getdata() {
wget "http://www.abs.gov.au/ausstats/subscriber.nsf/log?openagent&1270055001_sa2_2011_aust_shape.zip&1270.0.55.001&Data%20Cubes&7130A5514535C5FCCA257801000D3FBD&0&July%202011&23.12.2010&Latest" -O sa211.zip
unzip sa211.zip
# Load dataset into PostgreSQL
ogr2ogr -f "PostgreSQL" PG:"host=$host user=$username password=$password dbname=$dbname" SA2_2011_AUST.shp -nln  abs_sa211_multi -s_srs EPSG:4283 -t_srs EPSG:3577 -a_srs EPSG:3577 -nlt MULTIPOLYGON -overwrite
}
# end of bash function
# call the bash function or comment # to skip
#fn_getdata 

# Create three additional PostGIS tables (with indexes) representing the union and dumped constituents of all SA2 geometries
SQL=$(cat<<EOF 	 	
-------------------------	 	 
------- SQL BLOCK -------	 	 
-------------------------	 	 
DROP TABLE IF EXISTS abs_sa211_dumped;	 	 
CREATE TABLE abs_sa211_dumped AS	 	 
SELECT row_number() over () as ogc_fid, sa2_main11::text as poly_id, (ST_Dump(wkb_geometry)).geom::geometry(Polygon, 3577) as wkb_geometry FROM abs_sa211_multi;	 	 
CREATE INDEX abs_sa211_dumped_geom_idx ON abs_sa211_dumped USING GIST(wkb_geometry);	 	 

DROP TABLE IF EXISTS abs_aus11_multi;	 	 
CREATE TABLE abs_aus11_multi AS	 	 
SELECT 1 as ogc_fid, ST_Multi(ST_Union(wkb_geometry))::geometry(Multipolygon, 3577) as wkb_geometry FROM abs_sa211;	 	 
CREATE INDEX abs_aus11_multi_geom_idx ON abs_aus11_multi USING GIST(wkb_geometry);	 	 

DROP TABLE IF EXISTS abs_aus11_dumped;	 	 
CREATE TABLE abs_aus11_dumped AS	 	 
SELECT row_number() over () as ogc_fid, (ST_Dump(wkb_geometry)).geom::geometry(Polygon, 3577) as wkb_geometry FROM abs_aus11_multi;	 	 
CREATE INDEX abs_aus11_dumped_geom_idx ON abs_aus11_dumped USING GIST(wkb_geometry);	 	 
-------------------------	 	 
EOF
)
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT or comment # to skip		 	 
#psql -U $username -d $dbname -c "$SQL"  ### alternatively, comment out line with single '#' to skip this step

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
DROP TABLE IF EXISTS regular_grid_32k;
CREATE TABLE regular_grid_32k AS (
WITH s AS (SELECT DE_RegularGrid(ST_Envelope(wkb_geometry),32000) as wkb_geometry FROM abs_aus11_multi)
SELECT row_number() over() as tid, wkb_geometry::geometry(Polygon, 3577) FROM s);
-------------------------	 	 
EOF
)
echo "$SQL"  # comment to suppress printing
# execute SQL STATEMENT or comment # to skip	 	
psql -U $username -d $dbname -c "$SQL"
}
# end of bash function

# call the bash function or comment # to skip
#fn_generategrid 

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
wkb_geometry geometry(Multipolygon, 3577),
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
fcat0 AS (
		SELECT
		tid,
		wkb_geometry as the_geom
		FROM regular_grid_32k
		WHERE tid >= $1 AND tid < $2
		),
fcat1 AS (
		SELECT
		fcat0.tid,
		CASE WHEN ST_Within(fcat0.the_geom,rt.wkb_geometry) THEN fcat0.the_geom
		ELSE ST_Intersection(fcat0.the_geom,rt.wkb_geometry) END as the_geom
		FROM fcat0, $3 as rt
		WHERE ST_Intersects(fcat0.the_geom, rt.wkb_geometry) AND fcat0.the_geom && rt.wkb_geometry
		),
fcat1u AS (
		SELECT
		tid,
		ST_Union(the_geom) as the_geom
		FROM fcat1
		GROUP BY tid
		),
fcat2 AS (
		SELECT
		fcat0.tid,
		CASE WHEN ST_IsEmpty(ST_Difference(fcat0.the_geom,fcat1u.the_geom)) THEN NULL
		ELSE ST_Difference(fcat0.the_geom,fcat1u.the_geom) END as the_geom
		FROM fcat0, fcat1u
		WHERE fcat0.tid = fcat1u.tid
		)
------------------------
---- unclipped tile ----
------------------------
SELECT
NEXTVAL('vector_tiles_fid_seq'),
tid,
ST_Multi(the_geom),
0
FROM fcat0
WHERE the_geom IS NOT NULL
-------------------------
UNION ALL
-------------------------
----  land features  ----
-------------------------
SELECT
NEXTVAL('vector_tiles_fid_seq'),
tid,
ST_Multi(the_geom),
1
FROM fcat1u
WHERE the_geom IS NOT NULL
-------------------------
UNION ALL
-------------------------
---- water features  ----
-------------------------
SELECT
NEXTVAL('vector_tiles_fid_seq'),
tid,
ST_Multi(the_geom),
2
FROM fcat2
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
-- create joblist where block size = 24321 tiles (i.e. entire table processed on 1 CPU)
COPY (SELECT i as lower, i+24321 as upper FROM generate_series(1,24321,24321) i) TO STDOUT WITH CSV;

-- create joblist where block size = 1 tile (i.e. each tile processed individually)
--COPY (SELECT i as lower, i+1 as upper FROM generate_series(1,24321,1) i) TO STDOUT WITH CSV;

-- create joblist where block size = 5 tiles (i.e. tiles processed in batches of 100)
--COPY (SELECT i as lower, i+100 as upper FROM generate_series(1,24321,100) i) TO STDOUT WITH CSV; 	 
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
cat joblist.csv | parallel --colsep ',' fn_worker {1} {2} abs_aus11_multi
wait
#######################################

# stop timer
END_T1=$(date +%s)
TOTAL_DIFF=$(( $END_T1 - $START_T1 ))
echo "TOTAL SCRIPT TIME: $TOTAL_DIFF"

# end of script
#######################################
