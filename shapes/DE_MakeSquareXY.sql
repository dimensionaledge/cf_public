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
-- SELECT DE_MakeSquareXY(0,0,10000,3577);
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_MakeSquareXY(x FLOAT, y FLOAT, side FLOAT, srid INTEGER)
RETURNS GEOMETRY
AS $$
SELECT ST_SetSRID(ST_MakePolygon(ST_MakeLine(
ARRAY[
				st_makepoint(x-0.5*side, y+0.5*side),
				st_makepoint(x+0.5*side, y+0.5*side), 
				st_makepoint(x+0.5*side, y-0.5*side), 
				st_makepoint(x-0.5*side, y-0.5*side),
				st_makepoint(x-0.5*side, y+0.5*side)
				]
)),srid);
$$ LANGUAGE 'sql' IMMUTABLE STRICT;
