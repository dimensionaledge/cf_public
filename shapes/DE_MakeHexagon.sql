---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating a hexagonal polygon 
-- Dependencies: nil
-- Developed by: mark[at]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- SELECT DE_MakeHexagon(ST_MakePoint(0,0),1);
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_MakeHexagon(centerpoint GEOMETRY, radius FLOAT8)
RETURNS GEOMETRY
AS $$
DECLARE
x FLOAT8;
y FLOAT8;
vstep FLOAT8;
srid INTEGER;
hexagon GEOMETRY;

BEGIN
vstep := radius*SQRT(3)/2;
srid := ST_SRID(centerpoint);
x := ST_X(centerpoint);
y := ST_Y(centerpoint);

hexagon := ST_SetSRID(ST_MakePolygon(ST_MakeLine(
ARRAY[
				st_makepoint(x-radius, y),
				st_makepoint(x-0.5*radius, y+vstep), 
				st_makepoint(x+0.5*radius, y+vstep), 
				st_makepoint(x+radius, y), 
				st_makepoint(x+0.5*radius, y-vstep), 
				st_makepoint(x-0.5*radius, y-vstep), 
				st_makepoint(x-radius, y)
				]
)),srid);
RETURN hexagon;
END
$$ LANGUAGE 'plpgsql' IMMUTABLE;
