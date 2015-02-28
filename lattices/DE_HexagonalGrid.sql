---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating a hexagonal lattice structure of a given cell radius. The function uses a single or collection of geometries to define the grid extents.
-- Dependencies: DE_MakeHexagon()
-- Developed by: mark[a]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- DROP TABLE IF EXISTS hexagonal_grid;
-- CREATE TABLE hexagonal_grid AS (
-- WITH r AS (SELECT ST_MakePolygon(ST_MakeLine(ARRAY[ST_MakePoint(0,0), ST_MakePoint(0,-25), ST_MakePoint(50,-37), ST_MakePoint(35,28), ST_MakePoint(0,0)])) as extent_geom),
-- s AS (SELECT DE_HexagonalGrid(ST_Envelope(ST_Collect(r.extent_geom)),10) as wkb_geometry FROM r)
-- SELECT row_number() over() as gid, s.wkb_geometry FROM s);
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_HexagonalGrid(envelope GEOMETRY, radius FLOAT8)
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
y_offset FLOAT8;
y_value_adj FLOAT8 DEFAULT 0;
vstep FLOAT8;
hstep FLOAT8;
srid INTEGER;
centerpoint GEOMETRY;

BEGIN
srid := ST_SRID(envelope);
XMIN := ST_XMin(envelope);
YMIN := ST_YMin(envelope);
XMAX := ST_XMax(envelope);
YMAX := ST_YMax(envelope);
y_value := YMAX;
vstep := radius*SQRT(3)/2;
hstep := radius*1.5;

WHILE y_value  + 2*vstep > YMIN LOOP  -- for each y value, reset x to XMIN and subloop through the x values
	x_count := 1;
	x_value := XMIN;
	WHILE x_value - radius < XMAX LOOP
		y_offset := (x_count::numeric % 2)*vstep;
		y_value_adj := y_value + y_offset;  -- add the offset to the y_value
		centerpoint := ST_SetSRID(ST_MakePoint(x_value, y_value_adj), srid);
		x_count := x_count + 1; 
		x_value := x_value + hstep;
		RETURN QUERY SELECT ST_SnapToGrid(DE_MakeHexagon(centerpoint, radius),0.000001);
	END LOOP;  -- after exiting the subloop, increment the y count and y value
	y_count := y_count + 1;
	y_value := y_value - 2*vstep;
END LOOP;
RETURN;

END
$$ LANGUAGE 'plpgsql' IMMUTABLE;
