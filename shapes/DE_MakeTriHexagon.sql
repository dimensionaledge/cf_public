---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for producing 6 equilateral triangles from a hexagonal polygon input 
-- Dependencies: nil
-- Developed by: mark[at]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- SELECT DE_MakeTriHexagon(DE_MakeHexagon(ST_MakePoint(0,0),1));
---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION DE_MakeTriHexagon(parenthexagon GEOMETRY)
RETURNS SETOF GEOMETRY
AS $$
  WITH i AS (SELECT (ST_DumpPoints(parenthexagon)).geom as points UNION ALL SELECT ST_Centroid(parenthexagon))
  SELECT ST_SetSRID((ST_Dump(ST_DelaunayTriangles(ST_Collect(i.points), 0.000001, 0))).geom,ST_SRID(parenthexagon)) FROM i;
$$ LANGUAGE 'sql' IMMUTABLE STRICT;
