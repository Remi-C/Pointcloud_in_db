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
_...
***/

--▓▒░define the function used for range indexing on an atribute▓▒░--

		----
		--deelte function if it exists
		DROP FUNCTION IF EXISTS vosges_2011.rc_compute_range_for_a_patch(PCPATCH,text);

		----
		--creating function
		CREATE OR REPLACE FUNCTION vosges_2011.rc_compute_range_for_a_patch(patch PCPATCH, nom_grandeur_pour_interval text)
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

--▓▒░creating spatial index▓▒░--
	----
	--On riegl
		CREATE INDEX vosges_2011_las_vosges_gist_2D ON vosges_2011.las_vosges USING GIST (CAST(patch AS geometry));

	
--▓▒░creating time index▓▒░--

	----
	--time index on riegl
		CREATE INDEX vosges_2011_las_vosges_gist_range_gps_time
			ON vosges_2011.las_vosges
			USING GIST ( vosges_2011.rc_compute_range_for_a_patch(patch,'gps_time'));
	

--▓▒░creating index on num points in patch▓▒░--

	--num points per patch on riegl
		CREATE INDEXvosges_2011_las_vosges_num_points_perpatch
			ON vosges_2011.las_vosges (PC_NumPoints(patch));
	

			
