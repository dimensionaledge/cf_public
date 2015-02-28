---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for returning K nearest neighbours (KNN) recursively - fast for finding knn where distance threshold is unknown
-- Dependencies: nil
-- Developed by: mark[a]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
-- WITH results AS (SELECT ogc_fid, DE_knn(wkb_geometry, 'prep.osm_new_roads_poa11_cleaned_full', 'wkb_geometry', 'lid', 0.0001, 10,1) as knn FROM jtw.nsw_tz_centroids)
-- SELECT ogc_fid, (knn).id as lid, (knn).distance, row_number() over (PARTITION BY ogc_fid ORDER BY 3 ASC) FROM results;
---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS DE_knn(geometry, text, text, text, float8, float8, integer);
CREATE OR REPLACE FUNCTION DE_knn(origin_geom geometry, featureset text, feat_geom_col text, feat_id_col text, dist_min float8, dist_guess float8, k integer)
RETURNS TABLE (id text, distance float8)
AS $$
DECLARE
additional_filter text := 'AND b.type NOT IN (''motorway'', ''motorway_link'', ''service'')';
--additional_filter text := '';

BEGIN
RETURN QUERY EXECUTE 'WITH RECURSIVE knn (depth, id, distance, kval) AS (	
	---------------------------------------------------------------------
	(--START OF NON RECURSIVE BLOCK
	SELECT 1,0,0,0 -- ADD GHOST FEATURE IN CASE ZERO NEAREST NEIGHBOURS RETURNED FOR INITIAL DISTANCE GUESS
	UNION ALL
	SELECT
		1 as depth,
		b.'|| quote_ident(feat_id_col)||' as id,
		ST_Distance(a.wkb_geometry, b.'|| feat_geom_col ||')::float8 as distance,
		rank() over (ORDER BY ST_Distance(a.wkb_geometry, b.'|| feat_geom_col ||') ASC)::integer as kval
	FROM
		(SELECT ST_GeomFromEWKT(ST_AsEWKT('|| quote_literal(CAST(origin_geom as text)) ||')) as wkb_geometry) a
	INNER JOIN
		'|| featureset ||' b
	ON
		ST_DWithin(a.wkb_geometry, b.'|| feat_geom_col ||', '|| dist_guess ||') AND ST_Distance(a.wkb_geometry,  b.'|| feat_geom_col ||')::float8 >= '|| dist_min ||' '|| additional_filter ||'
	ORDER BY 3 ASC
	)--END OF NON RECURSIVE BLOCK
	---------------------------------------------------------------------
	UNION ALL
	---------------------------------------------------------------------
	(--START OF RECURSIVE BLOCK
	SELECT
		t.depth,
		t.id,
		t.distance,
		t.kval
	FROM
		(
		WITH q AS (SELECT * FROM knn),
		r AS (SELECT depth, kval as kval_furthest FROM q ORDER BY distance DESC LIMIT 1),
		s AS (SELECT
			a.depth+1 as depth,
			b.'|| quote_ident(feat_id_col)||' as id,
			ST_Distance(a.wkb_geometry, b.'|| feat_geom_col||' )::float8 as distance,
			rank() over (ORDER BY ST_Distance(a.wkb_geometry, b.'|| feat_geom_col||') ASC)::integer as kval, 
			a.kval_furthest
			FROM
			(SELECT ST_GeomFromEWKT(ST_AsEWKT('|| quote_literal(CAST(origin_geom as text)) ||')) as wkb_geometry, depth, kval_furthest FROM r) a
			INNER JOIN
			 '|| featureset ||' b
			ON ST_DWithin(a.wkb_geometry,b.'|| feat_geom_col||','||dist_guess||'*2^(a.depth+1)) AND ST_Distance(a.wkb_geometry, b.'|| feat_geom_col||' )::float8 >=  '|| dist_min ||' '|| additional_filter ||'
			ORDER BY 3 ASC
			)
		SELECT * FROM s WHERE kval > kval_furthest 
		UNION ALL
		--ADD GHOST FEATURE TO FORCE ANOTHER ITERATION SHOULD ZERO NEAREST NEIGHBOURS BE RETURNED FOR CURRENT DEPTH
		SELECT depth+1,0,0,0,kval_furthest FROM r
		) t
	WHERE t.kval_furthest < '|| k ||'
	)--END OF RECURSIVE BLOCK
	---------------------------------------------------------------------
	) --RETURN CTE RESULTS WITH DISTANCE > 0 TO EXCLUDE GHOST NEIGHBOURS.
	---------------------------------------------------------------------
	SELECT id::text, distance FROM knn WHERE distance > 0 ORDER BY 2 ASC LIMIT '|| k;
 
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;

