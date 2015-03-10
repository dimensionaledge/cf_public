---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for subdividing a square polygon into four child polygons
-- Dependencies: DE_MakeSquare()
-- Developed by: mark[at]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- SELECT DE_MakeRegularQuadCells(DE_MakeSquare(ST_MakePoint(0,0),1));
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_MakeRegularQuadCells(parent GEOMETRY)
RETURNS SETOF GEOMETRY
AS $$
DECLARE
halfside float8;
i INTEGER DEFAULT 1;
srid INTEGER;
centerpoint GEOMETRY;
centersquare GEOMETRY;
quadcell GEOMETRY;

BEGIN
srid := ST_SRID(parent);
centerpoint := ST_Centroid(parent);
halfside := abs(ST_Xmax(parent) - ST_Xmin(parent))/2;
centersquare := ST_ExteriorRing(DE_MakeSquare(centerpoint, halfside));

WHILE i < 5 LOOP
quadcell := DE_MakeSquare(ST_PointN(centersquare, i), halfside);
RETURN NEXT quadcell;
i := i + 1;
END LOOP; 

RETURN;
END
$$ LANGUAGE 'plpgsql' IMMUTABLE;
