------------------------------
--Remi-C. 11/2014
--Thales IGN
-----------------------------
-- Ply File As A service
-----------------------------
--
--This project aims to offer ply files export a a service from the database
--  
---------------------------------------------------



DROP FUNCTION IF EXISTS   rc_exportPlyFile_with_where( patch_table_name regclass ,  attributes_types_and_name TEXT,where_patch_text text,u_range_chosen int, where_point_text text ,output_file_path TEXT, output_as_binary BOOLEAN, export_precision_digits  INT , max_points_per_patch integer , voxel_grid_size FLOAT,only_output_query BOOLEAN ); 
CREATE OR REPLACE FUNCTION  rc_exportPlyFile_with_where(patch_table_name regclass,  attributes_types_and_name TEXT,where_patch_text text DEFAULT 'gid=1', u_range_chosen int DEFAULT -1,where_point_text text DEFAULT NULL, output_file_path TEXT DEFAULT '/tmp/rc_exportPlyFile_with_where.ply', output_as_binary BOOLEAN DEFAULT TRUE, export_precision_digits INT DEFAULT 4, max_points_per_patch integer DEFAULT 30000, voxel_grid_size FLOAT DEFAULT 0.01,only_output_query BOOLEAN DEFAULT FALSE, OUT num_points_written BIGINT, OUT query_text TEXT)
AS
$BODY$
		--@brief : this function writes to disk the original ply file with asked attributes asked WARNING : not safe against SQL injection
		--@param : patch_table_name : name of the table where the patches are, must be  
		--@param : attributes_types_and_name:  following ply standard, type and name of each attributes, separated by comma. Order matters ! note : echo_range and gps_time are automatically cast to range and time
		--@param : output_file_path : write the ply file to this place
		--@param : export_precision_digits : all float are going to be rounded to this precision. Int/char are unchanged 
		--@param : max_point_per_patch : negative or 0 : desactivate. wont write more than this number of points per patch. If there are more points in a patch, take max 1 point per voxel on a grid of size voxel_grid_size meter cell .
		--@param : voxel_grid_size : if more than max_point_per_patch in a 1m3 patch, create voxels of size voxel_grid_size and take at most 1 point per voxel
		DECLARE      
			num_points int :=0  ;
			ply_header text;
			query text; 
			r record ;
			header_fixed_line_number INT := 9 ; 
			tolerancy_on_range float := 1 ;
			--u_range_chosen int :=1; 
			initial_output_file_path TEXT = output_file_path ; 
		BEGIN 	 
		
		IF output_as_binary = TRUE THEN --saving the original output file path, will be used for the binary
			output_file_path = output_file_path || 'temp_ascii' ; 
		END IF ; 

		IF where_patch_text IS NOT NULL THEN
			where_patch_text := replace(where_patch_text ,  '''range''','''echo_range'''); 
			where_patch_text := replace(where_patch_text ,  '''time''','''gps_time''');  
			where_patch_text := format(' (%s)=TRUE ',where_patch_text); 
		ELSE 
			where_patch_text := ' TRUE ' ; 
		END IF;

		IF where_point_text IS NOT NULL THEN
			where_point_text := replace(where_point_text ,  '''range''','''echo_range''');
			where_point_text := replace(where_point_text ,  '''time','gps_time''');
			where_point_text := format(' (%s)=TRUE ',where_point_text); 
		ELSE 
			where_point_text := '  TRUE ';
		END IF;
		
	
	query :=  '					
		COPY  (  
	WITH patchs AS (
		SELECT patch ' ; 
	if u_range_chosen > 0 THEN 
		query := query ||' , rc_compute_range_for_a_patch(patch  , ''gps_time'') as trange'  ; 
	END IF ; 

	query := query ||format('
		FROM %s as patchs 
			WHERE %s
	) ',patch_table_name,where_patch_text);
	if u_range_chosen > 0 THEN 
	query := query || 
	format('
	, u_ranges AS (
		SELECT rc_numrange_disj_union(numrange(lower(trange)-%s,  upper(trange)+%s) ORDER BY  trange ASC)  AS u_ranges
		FROM patchs
	)
	,u_range AS (
		SELECT row_number() over(ORDER BY u_range ASC) AS u_id, u_range
		FROM u_ranges, unnest(u_ranges) as u_range
		ORDER BY u_range ASC
	)',tolerancy_on_range,tolerancy_on_range) ;
	END IF;

	query := query ||'
	,points AS (
		SELECT pt
		FROM patchs ' ;

	if u_range_chosen > 0 THEN 
	query := query || 
		format(' LEFT OUTER JOIN u_range ON (u_range.u_id = %s)' ,u_range_chosen);
	END IF;

	query := query ||	format('
			,rc_exploden_grid(patch,%s,%s) as pt 
		WHERE  ' , max_points_per_patch   , voxel_grid_size); 
		 
	if u_range_chosen > 0 THEN 
		query := query || 	'  	patchs.trange && u_range.u_range '; 
		query := query ||	format(' AND  %s ',where_point_text);  
	ELSE 
		query := query ||	format(' %s ',where_point_text);  
	END IF;
	
	
	query := query || 	'  
	) 
( 
SELECT regexp_split_to_table( 
''ply
format ascii 1.0
comment IGN time vertex porperty gives seconds within the day in UTC time system
comment IGN offset Time 0.000000
' ;
IF patch_table_name::text ILIKE '%acquisition_tmob_012013%' THEN 
query := query || 	'comment IGN offset Pos 649000.000000 6840000.000000 0.000000';
ELSE 
query := query || 	'comment IGN offset Pos 650000.00000 6860000.000000 0.000000';
END IF ; 
query := query || 	
'
comment IGN BBox X=0  Y=0  Z=0
element vertex '' ||COALESCE(  (SELECT count(*) FROM points  ) ,0)|| ''
comment property are generated on the fly
' ;

	FOR r in (
		SELECT gid,  split[1] as att_type, CASE WHEN split[2] = 'gps_time' THEN 'time' WHEN split[2] = 'echo_range' THEN 'range' ELSE split[2]  END AS att_name
		FROM ( SELECT row_number() over() as gid, property FROM regexp_split_to_table(attributes_types_and_name , ',') as property  ) AS p 
			, regexp_split_to_array(property, E'\\s') as split 
		ORDER BY gid ASC
	)
	LOOP 
		query:=query|| 'property '|| r.att_type || ' ' || r.att_name||'
' ;  
	END LOOP;
	query := query ||'end_header '' , E''\\n'')  )'; 
	query := query || ' UNION ALL (SELECT ' ;

	--for each attribute, getting it from point
	FOR r in (
		SELECT gid,  split[1] as att_type, CASE WHEN split[2] = 'time' THEN 'gps_time' WHEN split[2] = 'range' THEN 'echo_range' ELSE split[2]  END AS att_name
		FROM ( SELECT row_number() over() as gid, property FROM regexp_split_to_table(attributes_types_and_name , ',') as property  ) AS p 
			, regexp_split_to_array(property, E'\\s') as split 
		ORDER BY gid ASC
	)
	LOOP   
		IF r.gid =1 THEN --taking care of extra white space at the end
			query := query ||' coalesce(' ;
		ELSE 
			query := query || ' ||'' '' || coalesce('  ;
		END IF ;

		--no need to round if it is int or char
		IF r.att_type ILIKE '%int%' OR r.att_type ILIKE '%char%'  THEN 
			query:=query || format('PC_Get(pt,%L)::text,''NULL'')::int',r.att_name);
		ELSE 
			query:=query || format('round(PC_Get(pt,%L),%s)::text,''NULL'')',r.att_name,export_precision_digits) ;
		END IF; 
	END LOOP;
	query := query ||' FROM  points ' ;
 
	IF (attributes_types_and_name ILIKE '%time%') THEN --adding the ordering by time if necessary 
		query := query || 
		' ORDER BY PC_Get(pt,''gps_time'') ASC ' ;
	END IF ;  
	
	IF output_file_path ILIKE 'STDOUT%' THEN  --if writting to stdout, we need to remove quotes
		query:=query ||  ' ) ) TO STDOUT  ;' ;
	ELSE 
		query:=query || format(' ) ) TO %L  ;',output_file_path ); 
	END IF ;

	--raise notice '%',query;  
	IF only_output_query = FALSE THEN
		EXECUTE query ;
		GET DIAGNOSTICS num_points = ROW_COUNT ;	 

		IF output_as_binary = TRUE THEN 
		--converting ascii ply to binary if necessary
			query :=   format('SELECT rc_AsciiPlyToBinaryPly(
					ascii_file :=''%s''
					, binary_file := ''%s'') ;',output_file_path,initial_output_file_path);  
			EXECUTE query ; 
		END IF ; 
	END IF ;
	--returnging the num of points, we have to remove from the count the number of line of headers.
	--return num_points -header_fixed_line_number -(SELECT array_length(regexp_split_to_array(attributes_types_and_name , ','),1 ) ); 
	num_points_written :=  num_points -header_fixed_line_number -(SELECT array_length(regexp_split_to_array(attributes_types_and_name , ','),1 ) ); 
	query_text := query; 
	RETURN ; 
	 END ; 
	$BODY$
  LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT  ;

 
 
SELECT   rc_exportPlyFile_with_where(
		patch_table_name:='acquisition_tmob_012013.riegl_pcpatch_space'  -- 'tmob_20140616.riegl_pcpatch_space'
		,attributes_types_and_name  := 'float32 x,float32 y,float32 z,float32 reflectance'
		,where_patch_text:='file_name = ''130116terMob2_2_LAMB93_000008.ply''   '  
		,u_range_chosen:=-1
		,where_point_text:= 'pc_get(pt,''range'')< 50 AND (abs(pc_get(pt,''z_origin'') - pc_get(pt,''z''))<10 ) AND pc_get(pt,''num_echo'')=1 '  
		, output_file_path :=  '/tmp/rc_exportPlyFile_with_where.ply' 
		,output_as_binary := TRUE  
		, export_precision_digits:= 3
		, max_points_per_patch :=800
		, voxel_grid_size:=0.05);

		SELECT   *
		FROM rc_exportPlyFile_with_where(
		patch_table_name:='acquisition_tmob_012013.riegl_pcpatch_space'  -- 'tmob_20140616.riegl_pcpatch_space'
		,attributes_types_and_name  := 'float32 x,float32 y,float32 z,float32 reflectance'
		,where_patch_text:=' EXISTS (
							SELECT 1 
							FROM  trajectory.traj_paris_extractParis140616 AS traj 
							WHERE traj.gid = 1  AND ST_Within( patch::geometry  ,ST_Transform( traj_surface ,932012) ) = TRUE
							AND  tmob_20140616.rc_compute_range_for_a_patch(patch,''gps_time''::text) <@ numrange((start_time-1)::numeric,(end_time+1)::numeric) ) '  
		,u_range_chosen:=-1
		,where_point_text:= 'pc_get(pt,''range'')< 50 AND (abs(pc_get(pt,''z_origin'') - pc_get(pt,''z''))<10 ) AND pc_get(pt,''num_echo'')=1 '  
		, output_file_path :=  'STDOUT' 
		,output_as_binary := TRUE  
		, export_precision_digits:= 3
		, max_points_per_patch :=10
		, voxel_grid_size:=0.05
		,only_output_query:= true);
 
 

		
DROP FUNCTION IF EXISTS   rc_exportPlyFile_filename( patch_table_name regclass ,  attributes_types_and_name TEXT,file_name text, where_point_text text , output_file_path TEXT,output_as_binary BOOLEAN , export_precision_digits  INT , max_points_per_patch integer , voxel_grid_size FLOAT); 
CREATE OR REPLACE FUNCTION  rc_exportPlyFile_filename(patch_table_name regclass,  attributes_types_and_name TEXT,file_name text, where_point_text text DEFAULT NULL, output_file_path TEXT DEFAULT '/tmp/rc_exportPlyFile_with_where.ply' ,output_as_binary BOOLEAN DEFAULT TRUE, export_precision_digits INT DEFAULT 4, max_points_per_patch integer DEFAULT 30000, voxel_grid_size FLOAT DEFAULT 0.01)
  RETURNS bigint AS
$BODY$
		--@brief : this function writes to disk the original ply file with asked attributes asked WARNING : not safe against SQL injection
		--@param : patch_table_name : name of the table where the patches are, must be  
		--@param : attributes_types_and_name:  following ply standard, type and name of each attributes, separated by comma. Order matters ! note : echo_range and gps_time are automatically cast to range and time
		--@param : output_file_path : write the ply file to this place
		--@param : export_precision_digits : all float are going to be rounded to this precision. Int/char are unchanged 
		--@param : max_point_per_patch : negative or 0 : desactivate. wont write more than this number of points per patch. If there are more points in a patch, take max 1 point per voxel on a grid of size voxel_grid_size meter cell .
		--@param : voxel_grid_size : if more than max_point_per_patch in a 1m3 patch, create voxels of size voxel_grid_size and take at most 1 point per voxel
		DECLARE  
		numpoints int;    
		BEGIN 	
		 
		 SELECT  rc_exportPlyFile_with_where(
			patch_table_name 
			,attributes_types_and_name  
			, format('file_name = ''%s''  ',  file_name)
			,-1 --u_range_chosen int : we don't want to filter on number of passages 
			, where_point_text 
			, output_file_path  
			,output_as_binary 
			, export_precision_digits 
			, max_points_per_patch 
			, voxel_grid_size ) 
				into numpoints;

				return numpoints ; 
		END ; 
	$BODY$
  LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT   ;
		

SELECT rc_exportPlyFile_filename( 
		patch_table_name:='acquisition_tmob_012013.riegl_pcpatch_space'  -- 'tmob_20140616.riegl_pcpatch_space'
		,attributes_types_and_name  := 'float32 x,float32 y,float32 z,float32 reflectance'
		,file_name:='130116terMob2_2_LAMB93_000008.ply'
		,where_point_text:=  ' pc_get(pt,''range'')< 50 AND (abs(pc_get(pt,''z_origin'') - pc_get(pt,''z''))<10 ) AND pc_get(pt,''num_echo'')=1 '  
		, output_file_path :=  '/tmp/test_with_where.ply' 
		,output_as_binary 
		, export_precision_digits:= 3
		, max_points_per_patch :=800
		, voxel_grid_size:=0.05);

 

DROP FUNCTION IF EXISTS   rc_exportPlyFile_area( patch_table_name regclass ,  attributes_types_and_name TEXT,area_geom_l93_wkt TEXT, where_patch_text TEXT, u_range_chosen int, where_point_text text , output_file_path TEXT,output_as_binary BOOLEAN , export_precision_digits  INT , max_points_per_patch integer , voxel_grid_size FLOAT); 
CREATE OR REPLACE FUNCTION  rc_exportPlyFile_area(patch_table_name regclass,  attributes_types_and_name TEXT,area_geom_l93_wkt TEXT, where_patch_text TEXT , u_range_chosen int DEFAULT -1, where_point_text text DEFAULT NULL, output_file_path TEXT DEFAULT '/tmp/rc_exportPlyFile_with_where.ply',output_as_binary BOOLEAN DEFAULT TRUE, export_precision_digits INT DEFAULT 4, max_points_per_patch integer DEFAULT 30000, voxel_grid_size FLOAT DEFAULT 0.01)
  RETURNS bigint AS
$BODY$
		--@brief : this function writes to disk the original ply file with asked attributes asked WARNING : not safe against SQL injection
		--@param : patch_table_name : name of the table where the patches are, must be  
		--@param : attributes_types_and_name:  following ply standard, type and name of each attributes, separated by comma. Order matters ! note : echo_range and gps_time are automatically cast to range and time
		--@param : output_file_path : write the ply file to this place
		--@param : export_precision_digits : all float are going to be rounded to this precision. Int/char are unchanged 
		--@param : max_point_per_patch : negative or 0 : desactivate. wont write more than this number of points per patch. If there are more points in a patch, take max 1 point per voxel on a grid of size voxel_grid_size meter cell .
		--@param : voxel_grid_size : if more than max_point_per_patch in a 1m3 patch, create voxels of size voxel_grid_size and take at most 1 point per voxel
		DECLARE  
		numpoints int;    
		patch_srid int ; 
		query TEXT ; 
		BEGIN 	 
			--find the srid of a patch
			query := format('
			WITH point_as_text AS (
				SELECT pc_astext(pt) as t
				FROM %s, rc_ExplodeN(patch,1) as pt
				LIMIT 1 )
			,target_pcid AS (
				SELECT substring(t FROM E''{"pcid":(\\d*),.*'')::int AS pcid
				FROM point_as_text
				LIMIT 1 
			)
			SELECT srid 
			FROM target_pcid NATURAL JOIN pointcloud_formats ;', patch_table_name) ;
			EXECUTE query INTO patch_srid ; 

		query := format('ST_Intersects(patchs.patch::geometry, ST_Transform(ST_GeomFromText(%L,931008),%s  ))=TRUE   ', area_geom_l93_wkt ,patch_srid);
		IF where_patch_text IS NOT NULL THEN
		query := query || ' AND '  || where_patch_text ||' ';
		END IF ;  
		--RAISE NOTICE '%',patch_srid ; 
		 SELECT  rc_exportPlyFile_with_where(
			patch_table_name 
			,attributes_types_and_name  
			, query 
			, u_range_chosen  
			, where_point_text 
			, output_file_path  
			,output_as_binary 
			, export_precision_digits 
			, max_points_per_patch 
			, voxel_grid_size ) 
				into numpoints; 
				return numpoints ; 
		END ; 
	$BODY$
  LANGUAGE plpgsql VOLATILE CALLED ON NULL INPUT   ;


SELECT rc_exportPlyFile_area( 
		patch_table_name:='acquisition_tmob_012013.riegl_pcpatch_space'  -- 'tmob_20140616.riegl_pcpatch_space' --'acquisition_tmob_012013.riegl_pcpatch_space'
		,attributes_types_and_name  := 'float32 x,float32 y,float32 z,float32 reflectance'
		,area_geom_l93_wkt:='POLYGON((651473 6861179,651465 6861181,651463 6861189,651465 6861197,651473 6861199,651480 6861197,651483 6861189,651480 6861181,651473 6861179))'
		,where_patch_text := NULL
		,u_range_chosen:=2
		,where_point_text:= NULL
		, output_file_path :=  '/ExportPointCloud/tata.ply' 
		,output_as_binary := TRUE
		, export_precision_digits:= 4
		, max_points_per_patch :=800
		, voxel_grid_size:=0.05);

SELECT pc_get(pt,'x'), pc_get(pt,'y'), pc_get(pt,'z')
FROM tmob_20140616.riegl_pcpatch_space  , pc_explodes(patch)
LIMIT 100


		
		
CREATE EXTENSION IF NOT EXISTS  plpythonu ; 

CREATE OR REPLACE FUNCTION rc_AsciiPlyToBinaryPly(ascii_file text, binary_file text)
 RETURNS boolean
AS $$
  # PL/Python function body
import os ;
sys_arg = "/usr/bin/RPly_convert -l "+ascii_file+" "+binary_file+"; rm "+ ascii_file+";"; 
os_return = os.system(sys_arg) ;
plpy.notice(os_return);
return sys_arg;
$$ 
LANGUAGE plpythonu;


SELECT rc_AsciiPlyToBinaryPly(
	ascii_file :='/ExportPointCloud/Demo_Export_Ascii_Ply.ply'
	, binary_file := '/ExportPointCloud/Demo_Export_Binary_Ply.ply') ;