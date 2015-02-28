---------------------------------------------------------------------------
-- Code Desciption:
---------------------------------------------------------------------------
-- PostgreSQL/PostGIS custom function for generating timeseries
-- Dependencies: nil
-- Developed by: mark[a]dimensionaledge[dot]com
-- Licence: GNU GPL version 3.0
---------------------------------------------------------------------------
-- Usage Example:
---------------------------------------------------------------------------
---------------------  Make a timeseries  -------------------
---------------------------------------------------------------------------
--SELECT * FROM DE_GenerateTimeSeries('01/01/2014', '31/12/2014', 'DD/MM/YYYY', '1 day');
--SELECT TO_CHAR(timevalue, 'DD-Mon-YYYY') FROM DE_GenerateTimeSeries('01/01/2014', '31/12/2014', 'DD/MM/YYYY', '1 day');
---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS DE_GenerateTimeSeries(text,text,text,text);
CREATE OR REPLACE FUNCTION DE_GenerateTimeSeries(startvalue text, endvalue text, dateformat text, intervalspan text)
RETURNS TABLE (binid integer, timevalue date)
AS $$
WITH RECURSIVE timeseries (counter, timeval) AS (
--SEED VALUE (THE STARTING VALUE)
SELECT 1 as counter, to_date(startvalue, dateformat) as timevalue
UNION ALL
SELECT t.counter, t.timeval FROM
--TERMINAL CONDITION
(SELECT timeseries.counter+1 as counter, (timeseries.timeval+intervalspan::INTERVAL)::date as timeval FROM timeseries WHERE timeseries.timeval < to_date(endvalue, dateformat)) t)
SELECT counter, timeval FROM timeseries;
$$ LANGUAGE sql IMMUTABLE STRICT;
