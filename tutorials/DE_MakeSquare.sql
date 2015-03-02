---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating a square polygon of a specified size
-- Dependencies: nil
-- Developed by: mark[at]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- SELECT DE_MakeSquare(ST_MakePoint(0,0),1);
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_MakeSquare(centerpoint GEOMETRY, side FLOAT8)
RETURNS GEOMETRY
AS $$
SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(
ARRAY[
				st_makepoint(ST_X(centerpoint)-0.5*side, ST_Y(centerpoint)+0.5*side),
				st_makepoint(ST_X(centerpoint)+0.5*side, ST_Y(centerpoint)+0.5*side), 
				st_makepoint(ST_X(centerpoint)+0.5*side, ST_Y(centerpoint)-0.5*side), 
				st_makepoint(ST_X(centerpoint)-0.5*side, ST_Y(centerpoint)-0.5*side),
				st_makepoint(ST_X(centerpoint)-0.5*side, ST_Y(centerpoint)+0.5*side)
				]
)),ST_SRID(centerpoint));
$$ LANGUAGE 'sql' IMMUTABLE STRICT;
