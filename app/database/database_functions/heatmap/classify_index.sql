CREATE OR REPLACE FUNCTION public.classify_index(accessibility_index float, amenity TEXT, sensitivity text)
RETURNS integer 
AS $function$
DECLARE 
	config jsonb := select_from_variable_container_o('heatmap_config');
	amenity_group TEXT;
	arr_borders jsonb;
	accessibility_class integer;
	arr_element float;
	cnt integer := 0;
BEGIN 
	amenity_group = config -> 'amenity_groups' ->> amenity;
	arr_borders = config -> 'classification' -> ('group_' || amenity_group) -> ('sensitivity_' || sensitivity);
	
	For arr_element IN SELECT value::float FROM jsonb_array_elements(arr_borders)
  	LOOP
  		cnt = cnt + 1;
		IF arr_element > accessibility_index THEN 
			accessibility_class = cnt;
			EXIT;
		END IF;		
  	END LOOP;
  	
	RETURN COALESCE(accessibility_class,5); 
END;
$function$ LANGUAGE plpgsql immutable;

--SELECT * FROM classify_index(0.41, 'bus_stop', '200000')