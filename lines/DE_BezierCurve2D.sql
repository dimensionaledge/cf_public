---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating 2D bezier curves.
-- Dependencies: None
-- Developed by: mark[a]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS DE_BezierCurve2D(geometry, geometry, numeric, integer);
CREATE OR REPLACE FUNCTION DE_BezierCurve2D(o_geom geometry, d_geom geometry, theta numeric, num_points integer, breakval numeric)
RETURNS SETOF geometry AS
$$
DECLARE
srid INTEGER DEFAULT 4326;
endval INTEGER;
o_x float8;
o_y float8;
d_x float8;
d_y float8;
base_len float8;
hyp_len float8;
az_deg float8;
theta_adj float8;
a_geom GEOMETRY;
a_x float8;
a_y float8;

BEGIN
endval := num_points-1;

--GET COORDINATE X-Y VALUES
o_geom := ST_Transform(o_geom, srid);
d_geom := ST_Transform(d_geom, srid);
o_x := ST_X(o_geom);
o_y := ST_Y(o_geom);
d_x := ST_X(d_geom);
d_y := ST_Y(d_geom);

--TRANSLATE X-COORDINATES TO 0-360 DEGREE SCALE
o_x := CASE WHEN o_x < 0 THEN o_x + 360 ELSE o_x END;
d_x := CASE WHEN d_x < 0 THEN d_x + 360 ELSE d_x END;

--CALCULATE AZIMUTH FROM TRUE NORTH
az_deg := degrees(ST_Azimuth(ST_Point(o_x, o_y), ST_Point(d_x, d_y)));

--CALCULATE LENGTH OF TRIANGULAR BASE
base_len :=
	CASE WHEN abs(d_x - o_x) <= 180 THEN (((d_x - o_x)^2 + (d_y - o_y)^2)^0.5) * 0.5
	ELSE (((360 - (d_x - o_x))^2 + (d_y - o_y)^2)^0.5) * 0.5
	END;

--ADJUST THETA (MAXIMUM ANGLE BETWEEN ADJACENT AND HYPOTENUSE. ZERO THETA IN NORTH-SOUTH PLANE.  MAXIMUM THETA IN EAST-WEST PLANE
theta_adj :=
	CASE WHEN az_deg >= 180 THEN -1 * theta * SIN(ST_Azimuth(ST_Point(o_x, o_y), ST_Point(d_x, d_y)))
	ELSE theta * SIN(ST_Azimuth(ST_Point(o_x, o_y), ST_Point(d_x, d_y)))
	END;

--CALCULATE LENGTH OF HYPOTENUSE USING THETA ADJUSTED
hyp_len := base_len/(COS(RADIANS(theta_adj)));

--CALCULATE BEZIER APEX GEOMETRY
a_geom := ST_Translate(ST_Point(o_x, o_y), SIN(RADIANS(az_deg - theta_adj))*hyp_len, COS(RADIANS(az_deg - theta_adj))*hyp_len);
a_x := ST_X(a_geom);
a_y := ST_Y(a_geom);

--GENERATE BEZIER CURVE LINESTRING
RETURN QUERY WITH 
--generate required number of points
s1 AS (SELECT s0/endval::numeric as p_value FROM generate_series(0,endval,1) s0),
--generate the bezier curve x-y values
s2 AS (SELECT p_value,
(((1 - p_value)*(((1 - p_value)*o_x) + (p_value * a_x))) + (p_value * (((1 - p_value)*a_x) + (p_value * d_x)))) as C_x,
(((1 - p_value)*(((1 - p_value)*o_y) + (p_value * a_y))) + (p_value * (((1 - p_value)*a_y) + (p_value * d_y)))) as C_y
FROM s1),
--group points to facilitate the creation of split linestrings, plus adjust back to -180 to 180 degree x-scale
s3 AS (SELECT p_value, CASE WHEN C_x >= breakval THEN 1 ELSE 2 END as linenum, CASE WHEN C_x >= 180 THEN C_x - 360 ELSE C_x END as C_x, C_y FROM s2),
--make point geometries
s4 AS (SELECT p_value, linenum, ST_MakePoint(C_x, C_y) as wkb_geometry FROM s3),
--make individual line geometries for line numbers 1 and 2
s5 AS (SELECT 1 as foo, ST_SetSRID(ST_MakeLine(wkb_geometry ORDER BY p_value),srid) as wkb_geometry FROM s4 WHERE linenum = 1 UNION ALL SELECT 1, ST_SetSRID(ST_MakeLine(wkb_geometry ORDER BY p_value),srid) as wkb_geometry FROM s4 WHERE linenum = 2)
--Return the multilinestring
SELECT ST_Multi(ST_Union(wkb_geometry)) FROM s5 WHERE wkb_geometry IS NOT NULL GROUP BY foo;		

END;
$$ LANGUAGE plpgsql STRICT;
