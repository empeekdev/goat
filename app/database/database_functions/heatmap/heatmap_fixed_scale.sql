DROP FUNCTION IF EXISTS heatmap_fixed_scale;
CREATE OR REPLACE FUNCTION public.heatmap_fixed_scale(amenities jsonb)
 RETURNS TABLE(grid_id integer, percentile_accessibility integer, accessibility_index numeric)
 LANGUAGE plpgsql
AS $function$
DECLARE
	sql_query text =  'SELECT grid_id,';
	sql_accessibility_index TEXT := ',';
	sql_single_query text;
	array_amenities text[];
	amenity text;
	column_index text;
	weight_amenity text;
	count_amenities integer;
BEGIN
	
  SELECT count(*) 
  INTO count_amenities 
  FROM (SELECT jsonb_object_keys(amenities)) x;
  For amenity IN SELECT * FROM jsonb_object_keys(amenities)
  LOOP

	  column_index = format('index_%s',(amenities -> amenity ->> 'sensitivity')::integer);
	  weight_amenity = (amenities -> amenity ->> 'weight')::integer;
	 
      sql_single_query = format('(%s*classify_index(COALESCE((%s ->> ''%s'')::numeric,0),''%s'',''%s'') +',weight_amenity,column_index,amenity,amenity,(amenities -> amenity ->> 'sensitivity'));
      sql_query = concat(sql_query,sql_single_query);
      sql_accessibility_index = sql_accessibility_index || format('%s*COALESCE((%s ->> ''%s'')::numeric,0)+',weight_amenity,column_index,amenity);  	
	  array_amenities = array_amenities || (''''||amenity||'''');
  END LOOP;
  sql_query = sql_query || format('0))/%s'||sql_accessibility_index||'0'||' FROM grid_500 WHERE %s ?| array[%s]',count_amenities,column_index,REPLACE(REPLACE(array_amenities::text,'{',''),'}',''));
  RETURN query EXECUTE sql_query;
  RETURN;
END;
$function$;


--SELECT heatmap('{"kindergarten":{"sensitivity":250000,"weight":1},"bus_stop":{"sensitivity":250000,"weight":1}}'::jsonb)
/*
SELECT g.grid_id, h.accessibility_index, COALESCE(percentile_accessibility,0)::smallint, g.percentile_population, g.geom
FROM grid_500 g
LEFT JOIN 
(
	SELECT grid_id, accessibility_index, percentile_accessibility
	FROM heatmap_fixed_scale('{"kindergarten":{"sensitivity":250000,"weight":1},"bus_stop":{"sensitivity":250000,"weight":1}}'::jsonb)
) h 
ON g.grid_id = h.grid_id;
*/