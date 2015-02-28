---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating a regular lattice structure of a given cell size. The function uses a single or collection of geometries to define the grid extents.
-- Dependencies: DE_MakeSquare()
-- Developed by: mark[at]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- DROP TABLE IF EXISTS regular_grid;
-- CREATE TABLE regular_grid AS (
-- WITH r AS (SELECT ST_MakePolygon(ST_MakeLine(ARRAY[ST_MakePoint(0,0), ST_MakePoint(0,-25), ST_MakePoint(50,-37), ST_MakePoint(35,28), ST_MakePoint(0,0)])) as extent_geom),
-- s AS (SELECT DE_RegularGrid(ST_Envelope(ST_Collect(r.extent_geom)),10) as wkb_geometry FROM r)
-- SELECT row_number() over() as gid, s.wkb_geometry FROM s);
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_RegularGrid(extent GEOMETRY, side FLOAT8)
RETURNS SETOF GEOMETRY
AS $$
DECLARE
XMIN FLOAT8;
XMAX FLOAT8;
YMIN FLOAT8;
YMAX FLOAT8;
x_value FLOAT8;
y_value FLOAT8;
x_count INTEGER;
y_count INTEGER DEFAULT 1;
srid INTEGER;
centerpoint GEOMETRY;

BEGIN
srid := ST_SRID(extent);
XMIN := ST_XMin(extent);
YMIN := ST_YMin(extent);
XMAX := ST_XMax(extent);
YMAX := ST_YMax(extent);
y_value := YMAX;

WHILE y_value  + 0.5*side > YMIN LOOP -- for each y value, reset x to XMIN and subloop through the x values
	x_count := 1;
	x_value := XMIN;
	WHILE x_value - 0.5*side < XMAX LOOP
		centerpoint := ST_SetSRID(ST_MakePoint(x_value, y_value), srid);
		x_count := x_count + 1; 
		x_value := x_value + side;
		RETURN QUERY SELECT ST_SnapToGrid(DE_MakeSquare(centerpoint, side),0.000001);
	END LOOP;  -- after exiting the subloop, increment the y count and y value
	y_count := y_count + 1;
	y_value := y_value - side;
END LOOP;
RETURN;

END
$$ LANGUAGE 'plpgsql' IMMUTABLE;
