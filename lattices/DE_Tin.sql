CREATE TABLE tutorials.tinpoints (
pid serial,
wkb_geometry geometry(Point,3577),
cat text
);

DROP VIEW IF EXISTS tutorials.tinpolys;
CREATE VIEW tutorials.tinpolys AS
(WITH a AS (SELECT (ST_Dump(ST_DelaunayTriangles(ST_Collect(wkb_geometry), 0.000001, 0))).geom::geometry(Polygon,3577) as the_geom FROM tutorials.tinpoints)
SELECT row_number() over () as poly_id, a.the_geom FROM a);

DROP VIEW IF EXISTS tutorials.tinlines;
CREATE VIEW tutorials.tinlines AS
(WITH a AS (SELECT (ST_Dump(ST_DelaunayTriangles(ST_Collect(wkb_geometry), 0.000001, 1))).geom::geometry(Linestring,3577) as the_geom FROM tutorials.tinpoints WHERE cat IN ('1','2'))
SELECT row_number() over () as line_id, a.the_geom FROM a);

DROP VIEW IF EXISTS tutorials.tinlines2;
CREATE VIEW tutorials.tinlines2 AS
(WITH a AS (SELECT (ST_Dump(ST_DelaunayTriangles(ST_Collect(wkb_geometry), 0.000001, 1))).geom::geometry(Linestring,3577) as the_geom FROM tutorials.tinpoints WHERE cat IN ('2'))
SELECT row_number() over () as line_id, a.the_geom FROM a);

