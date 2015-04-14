/***************************
*Rémi C
*19/06/2013
*Thales TTS / IGN Matis-Cogit
*This script is a proof of concept about storing massive point cloud into postgres DB using the pointcloud extension
*This script is part of a semi automated process and cannot be executed as a whole, but command by command to check result
*This script prepare the database for the import of point cloud
***************************/

--WARNING : RUN command by command (sthen)
----
----

/***
*Script abstract
*_define the function used for range indexing on an atribute
*_creating spatial index
_creating time index
_.creating index on point number per patch
_(OPTIONAL) : refactor patches to merge patch with less than 5 points
***/

--▓▒░define the function used for range indexing on an atribute▓▒░--

		----
		--deelte function if it exists
		DROP FUNCTION IF EXISTS tmob_20140616.rc_compute_range_for_a_patch(PCPATCH,text);

		----
		--creating function
		CREATE OR REPLACE FUNCTION tmob_20140616.rc_compute_range_for_a_patch(patch PCPATCH, nom_grandeur_pour_interval text)
		RETURNS NUMRANGE AS $$ 
		BEGIN
		/*
		This function input is a patch. It compute the range (from min to max) of a given attribute
		*/

		RETURN NUMRANGE(PC_PatchMin(patch, nom_grandeur_pour_interval),PC_PatchMax(patch, nom_grandeur_pour_interval),'[]');
		END;
		$$ LANGUAGE 'plpgsql' IMMUTABLE;

		--example use case
		/*SELECT acquisition_tmob_012013.rc_compute_range_for_a_patch(patch,'gps_time')
		FROM acquisition_tmob_012013.velo_pcpatch_space
		LIMIT 100
		*/
		
--▓▒░creating proxy table▓▒░--
DROP TABLE IF EXISTS tmob_20140616.riegl_pcpatch_space_int_proxy ;
CREATE TABLE tmob_20140616.riegl_pcpatch_space_int_proxy 	
	(
	gid serial references tmob_20140616.riegl_pcpatch_space_int(gid)
	,file_name text
	, sub_acq_number int
	, sub_acq_order int
	,num_points int
	,avg_Z numrange
	,avg_time numrange
	,geom geometry(polygon, 931008) 
	) ;
	
--▓▒░filling proxy table▓▒░--
INSERT INTO tmob_20140616.riegl_pcpatch_space_int_proxy
SELECT gid
	, substring(file_name,'.*/Laser/(.*\.ply)')
	, substring(file_name,'.*/Laser/.*_(\d*)_.*\.ply')::int
	, substring(file_name,'.*/Laser/.*_(\d*)\.ply')::int
	,pc_numpoints(patch)
	,rc_compute_range_for_a_patch(patch, 'Z')
	,rc_compute_range_for_a_patch(patch, 'GPS_time')
	, patch::geometry(polygon, 931008)
FROM tmob_20140616.riegl_pcpatch_space_int

CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (gid);
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (file_name);
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (sub_acq_number);
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (sub_acq_order);
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (num_points);
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (avg_Z );
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy (avg_time);
CREATE INDEX ON tmob_20140616.riegl_pcpatch_space_int_proxy USING GIST(geom);

--▓▒░creating spatial index▓▒░-- 
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_space USING GIST (CAST(patch AS geometry));
--▓▒░creating time index▓▒░
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_space
		USING GIST ( tmob_20140616.rc_compute_range_for_a_patch(patch,'gps_time')); 
--▓▒░creating Z index▓▒░
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_space
		USING GIST ( tmob_20140616.rc_compute_range_for_a_patch(patch,'Z')); 
--▓▒░creating index on points number in patch▓▒░-- 
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_space
		USING BTREE (Pc_NumPoints(patch)); 

--▓▒░creating index on file_name of patch▓▒░--
	--correcting the file name : dropping the fixed path
	UPDATE tmob_20140616.riegl_pcpatch_space SET file_name = substring(file_name,'.*/otho_laser/(.*\.ply)'); 
	----
	--index for Point number in a patch for riegl
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_space  ( file_name );
--▓▒░creating index on gid▓▒░-- 
	--index for Point number in a patch for riegl
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_space  ( gid );	 

--▓▒░creating a proxy table ▓▒░--
	--▓▒░creating a proxy table ▓▒░--
	CREATE TABLE tmob_20140616.riegl_pcpatch_proxy (
		gid int  references  tmob_20140616.riegl_pcpatch_space(gid) 
		,file_name text 
		,sub_acq_number int
		,sub_acq_order int
		,num_points int
		,geom geometry(multipolygon, 932012)
		,points_per_level int[]
	) ; 
 
	INSERT INTO tmob_20140616.riegl_pcpatch_proxy  
	SELECT gid
		, file_name
		, substring(file_name, '.*_(\d+)_.*')::int
		, substring(file_name, '.*_(\d+)\.ply')::int
		, pc_numpoints(patch) 
		,ST_Multi(patch::geometry)
	FROM tmob_20140616.riegl_pcpatch_space as rps  ;

	CREATE INDEX ON tmob_20140616.riegl_pcpatch_proxy (gid) ;
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_proxy (file_name) ;
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_proxy (sub_acq_number) ;
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_proxy (sub_acq_order) ;
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_proxy (num_points) ;
	CREATE INDEX ON tmob_20140616.riegl_pcpatch_proxy USING GIST(geom) ;
 

/*
--▓▒░ (OPTIONAL) : RIEGL:  refactor patches to merge patch with less than 5 points into patch 4*4*4metersif the time of acquisition is not too different▓▒░--

	----
	--get every patch with less than 5 points
	--use the centroid of theses patches to spatially and temporaly group by 5 meters step and 30 sec step
	--merge the patches according to there group
	--write result in a temporary table
	
	--delete patches from original table with less than 5 points
	--write patches from temporary table to original table.
	--delete temp table
	--vacuum analyse
	--vacuum full

		--creating the temporary table
		DROP TABLE IF EXISTS acquisition_tmob_012013.riegl_Xm3;
		--populating it with merged patch
		CREATE TABLE acquisition_tmob_012013.riegl_Xm3 AS (--merging patch with less than 5 points with spatial and temporal criteria
			SELECT min(gid) AS gid ,PC_Union(patch) AS patch
				FROM (--patch with less than 5 points
					SELECT *
					FROM acquisition_tmob_012013.riegl_pcpatch_space
					WHERE PC_NumPoints(patch)<=5
				) as small_patches
			GROUP BY 
				ROUND(1/5*St_X(ST_Centroid(ST_MakeValid(patch::geometry)))), ROUND(1/5*St_Y(ST_Centroid(ST_MakeValid(patch::geometry)))),ROUND(1/5*St_Z(ST_Centroid(ST_MakeValid(patch::geometry))))
				--ST_SnapToGrid(ST_Centroid(ST_MakeValid(patch::geometry)),5) 
				, ROUND(1/30* ROUND(1/2*lower(acquisition_tmob_012013.rc_compute_range_for_a_patch(patch,'gps_time'))+1/2*upper(acquisition_tmob_012013.rc_compute_range_for_a_patch(patch,'gps_time'))))
		);

		--delete patches with less than 5 points from original table	
		DELETE FROM acquisition_tmob_012013.riegl_pcpatch_space
		WHERE PC_NumPoints(patch)<=5;

		--write merged patches from temporary table to original table
		INSERT INTO acquisition_tmob_012013.riegl_pcpatch_space 
			SELECT * FROM acquisition_tmob_012013.riegl_Xm3

		--drop temporary table
		DROP TABLE IF EXISTS acquisition_tmob_012013.riegl_Xm3;

		--vacuum analyze on original table
		VACUUM ANALYZE acquisition_tmob_012013.riegl_pcpatch_space
 
*/



		
