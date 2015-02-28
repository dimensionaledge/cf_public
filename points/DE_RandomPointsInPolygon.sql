---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating random points recursively within a polygon or multipolygon up to a specified target number
-- Dependencies: nil
-- Developed by: mark[a]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
---------------------  Make some polygons  -------------------
---------------------------------------------------------------------------
-- DROP TABLE IF EXISTS polygon_shapes;
-- CREATE TABLE polygon_shapes (poly_id INTEGER, wkb_geometry geometry(Polygon, 3577));
-- INSERT INTO polygon_shapes SELECT 1, ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[ST_MakePoint(0,0), ST_MakePoint (0,100), ST_MakePoint(100,100), ST_MakePoint(100,0), ST_MakePoint(0,0)])),3577);
-- INSERT INTO polygon_shapes SELECT 2, ST_SetSRID(ST_MakePolygon(ST_MakeLine(ARRAY[ST_MakePoint(-20,-20), ST_MakePoint (-40,-20), ST_MakePoint(-40,-40), ST_MakePoint(-20,-40), ST_MakePoint(-20,-20)])),3577);
---------------------------------------------------------------------------
------------  Generate 10000 random points --------------
---------------------------------------------------------------------------
-- DROP TABLE IF EXISTS polygon_points;
-- CREATE TABLE polygon_points AS (
-- WITH points AS (SELECT DE_RandomPointsInPolygon(ST_Multi(ST_Union(wkb_geometry)),10000,1) as the_geom FROM polygon_shapes)
-- SELECT row_number() over () as pid, points.the_geom FROM points);
---------------------------------------------------------------------------
-- Check random point distribution versus area 
---------------------------------------------------------------------------
-- WITH polys AS (SELECT t1.poly_id, ST_Area(t1.wkb_geometry) as area, round(ST_Area(t1.wkb_geometry)::numeric/t2.total_area::numeric,3) as area_ratio FROM polygon_shapes t1, (SELECT SUM(ST_Area(wkb_geometry)) as total_area FROM polygon_shapes) t2),
-- points AS (SELECT t1.poly_id, COUNT(t2.pid) as point_count, round(COUNT(t2.pid)::numeric/t3.total_count,3) as count_ratio FROM polygon_shapes t1, polygon_points t2, (SELECT count(*) as total_count FROM polygon_points) t3 WHERE ST_Contains(t1.wkb_geometry, t2.the_geom) GROUP BY t1.poly_id, t3.total_count)
-- SELECT polys.poly_id, polys.area_ratio, points.point_count, points.count_ratio FROM polys, points WHERE polys.poly_id = points.poly_id;
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_RandomPointsInPolygon(parent_geom geometry, target_number integer, snap_tolerance double precision)
RETURNS TABLE (the_geom GEOMETRY)
AS $$
DECLARE
srid INTEGER;
extent GEOMETRY;
XMIN FLOAT8;
XMAX FLOAT8;
YMIN FLOAT8;
YMAX FLOAT8;
XRANGE FLOAT8;
YRANGE FLOAT8;

BEGIN
srid := ST_SRID(parent_geom);
extent := ST_Envelope(parent_geom);
XMIN := ST_XMin(extent);
YMIN := ST_YMin(extent);
XMAX := ST_XMax(extent);
YMAX := ST_YMax(extent);
XRANGE := XMAX - XMIN;
YRANGE := YMAX - YMIN;

RETURN QUERY
WITH RECURSIVE randompoints (level, inside, cumulative_inside, the_geom) AS (
	--SEED VALUE (USE GEOMETRY CENTROID FOR FIRST POINT WHEN TARGET NUMBER = 1 OR SAY GREATER THAN 5)
	SELECT 1 as level,
	CASE
		WHEN target_number BETWEEN 2 AND 5 THEN 0
		WHEN ST_Contains(parent_geom, ST_Centroid(parent_geom)) THEN 1
		ELSE 0 END as inside,
	CASE
		WHEN target_number BETWEEN 2 AND 5 THEN 0
		WHEN ST_Contains(parent_geom, ST_Centroid(parent_geom)) THEN 1
		ELSE 0 END as cumulative_inside,
	ST_SnapToGrid(ST_Centroid(parent_geom), snap_tolerance) as the_geom
	UNION ALL
	--TERMINAL CONDITION SUBQUERY (LOOP UNTIL THE SUBQUERY CONDITIONS ARE NO LONGER SATISFIED)
	SELECT randompoints.level+1,
	CASE
		WHEN ST_Contains(parent_geom, i.the_geom) THEN 1
		ELSE 0 END,
	randompoints.cumulative_inside+(CASE WHEN ST_Contains(parent_geom, i.the_geom) THEN 1 ELSE 0 END),
	i.the_geom	
	FROM
	(SELECT ST_SnapToGrid(ST_SetSRID(ST_MakePoint(XMIN + random()*XRANGE, YMAX - random()*YRANGE),srid),snap_tolerance) as the_geom) i, randompoints
	WHERE randompoints.cumulative_inside < target_number)
	SELECT randompoints.the_geom FROM randompoints WHERE randompoints.inside = 1;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;
