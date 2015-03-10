---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating quadcells recursively from a given starting geometry and intersecting reference table, to a maximum number of iteration levels or threshold value per cell 
-- Dependencies: DE_MakeSquare(), DE_MakeRegularQuadCells()
-- Developed by: mark[a]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS DE_RegularQuadGrid(geometry, text, text, integer, double precision);
CREATE OR REPLACE FUNCTION DE_RegularQuadGrid(parent_geom geometry, reference_table text, reference_geom_col text, max_depth integer, threshold_value double precision)
RETURNS TABLE (depth integer, the_geom GEOMETRY, cell_value double precision)
AS $$
DECLARE
reference_geom_type text;

BEGIN
EXECUTE 'SELECT GeometryType('|| reference_geom_col ||') FROM  '|| reference_table ||' LIMIT 1' INTO reference_geom_type ;

IF reference_geom_type NOT IN ('POINT')
THEN
RAISE EXCEPTION 'Reference table is not a valid geometry type';
ELSE
END IF;

RETURN QUERY EXECUTE
'WITH RECURSIVE quadcells (depth, the_geom, cell_value) AS (
	--SEED THE PARENT GEOMETRY AND CELL VALUE
	SELECT 1, l.the_geom, r.pcount
	FROM (SELECT ST_GeomFromEWKT(ST_AsEWKT('|| quote_literal(CAST(parent_geom as text)) ||')) as the_geom) l,
	LATERAL
	(SELECT count(*) as pcount, l.the_geom FROM '|| reference_table ||' WHERE ST_Intersects(l.the_geom,  '|| reference_geom_col ||') AND l.the_geom &&  '|| reference_geom_col ||') r
	--RECURSIVE PART
	UNION ALL
	SELECT t.depth, t.the_geom, t.pcount 
	FROM
	--TERMINAL CONDITION SUBQUERY LOOPS UNTIL THE CONDITIONS ARE NO LONGER MET - NOTE THE RECURSIVE ELEMENT CAN ONLY BE EXPLICITYLY REFERRED TO ONCE, HENCE THE USE OF CTE
		(
		WITH a AS (SELECT * FROM quadcells WHERE the_geom IS NOT NULL AND depth < '|| max_depth ||' AND cell_value > '|| threshold_value ||'),
		b AS (SELECT max(depth) as previous FROM a),
		c AS (SELECT a.* FROM a,b WHERE a.depth = b.previous),
		d AS (SELECT r.the_geom, r.pcount FROM (SELECT DE_MakeRegularQuadCells(the_geom) as the_geom FROM c) l, LATERAL (SELECT count(*) as pcount, l.the_geom FROM '|| reference_table ||' WHERE ST_Intersects(l.the_geom,  '|| reference_geom_col ||') AND l.the_geom &&  '|| reference_geom_col ||') r)
		SELECT b.previous+1 as depth, d.the_geom, d.pcount FROM b, d
		) t
	)
	SELECT depth, the_geom, cell_value::float8  FROM quadcells WHERE ST_IsEmpty(the_geom)=false AND (cell_value <= '|| threshold_value ||' OR (cell_value > '|| threshold_value ||' AND depth = '|| max_depth||'))' ;

END;
$$ LANGUAGE 'plpgsql' VOLATILE;
