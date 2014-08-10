/***************************
*Rémi C
*19/06/2013
*Thales TTS / IGN Matis-Cogit
*This script is a proof of concept about storing massive point cloud into postgres DB using the pointcloud extension
*This script is part of a semi automated process and cannot be executed as a whole, but command by command to check result
*This script prepare the database for the import of point cloud
***************************/

/***
*Script abstract : 
*_Install / check that necessary tools are installed
*_Creating a dedicated postgres schema
*_Creating XML schema for the point we are going to load
*_Creating patch table which will store the pointcloud at the end of the import
***/

--WARNING : this script should be executed commande by commande. Repeating commands will return errors but won't affect the state of the system.

--▓▒░Checking that necessary tools are installed▓▒░--
	----
	--Is Postgis installed ? Should return something like version > 2.0.3. If error : execute "CREATE EXTENSION postgis"
	SELECT * FROM PostGIS_Full_Version();

	--Checking that PointCloud is installed
	SELECT * FROM PC_Version();
		--First we create a dummy schema for minimal points
		INSERT INTO pointcloud_formats (pcid, srid, schema) VALUES (1, 0, 
			'<?xml version="1.0" encoding="UTF-8"?>
			<pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1" 
				xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			  <pc:dimension>
				<pc:position>1</pc:position>
				<pc:size>4</pc:size>
				<pc:description>X coordinate as a long integer. You must use the 
						scale and offset information of the header to 
						determine the double value.</pc:description>
				<pc:name>X</pc:name>
				<pc:interpretation>int32_t</pc:interpretation>
				<pc:scale>0.01</pc:scale>
			  </pc:dimension>
			  <pc:dimension>
				<pc:position>2</pc:position>
				<pc:size>4</pc:size>
				<pc:description>Y coordinate as a long integer. You must use the 
						scale and offset information of the header to 
						determine the double value.</pc:description>
				<pc:name>Y</pc:name>
				<pc:interpretation>int32_t</pc:interpretation>
				<pc:scale>0.01</pc:scale>
			  </pc:dimension>
			  <pc:dimension>
				<pc:position>3</pc:position>
				<pc:size>4</pc:size>
				<pc:description>Z coordinate as a long integer. You must use the 
						scale and offset information of the header to 
						determine the double value.</pc:description>
				<pc:name>Z</pc:name>
				<pc:interpretation>int32_t</pc:interpretation>
				<pc:scale>0.01</pc:scale>
			  </pc:dimension>
			  <pc:dimension>
				<pc:position>4</pc:position>
				<pc:size>2</pc:size>
				<pc:description>The intensity value is the integer representation 
						of the pulse return magnitude. This value is optional 
						and system specific. However, it should always be 
						included if available.</pc:description>
				<pc:name>Intensity</pc:name>
				<pc:interpretation>uint16_t</pc:interpretation>
				<pc:scale>1</pc:scale>
			  </pc:dimension>
			  <pc:metadata>
				<Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>');
		--second we try to create a point using this schema : it should return the point. If not, execute "CREATE EXTENSION pointcloud"
		SELECT PC_AsText(PC_MakePoint(1, ARRAY[-127.258, 45.258, 124.157, 4.0])); 

	--Checking that the point_cloud --> postgis module works : it should return a psotgis point in text. If not working, execute "CREATE EXTENSION pointcloud_postgis;"	
	SELECT ST_AsText(PC_MakePoint(1, ARRAY[-127.258, 45.258, 124.157, 4.0])::geometry); 

	
--▓▒░Creating a dedicated postgres schema▓▒░--
	--Deleting the schema if it already exists
	DROP SCHEMA IF EXISTS benchmark;
	--creating the schema
	CREATE SCHEMA benchmark;

	
--▓▒░Creating the XML schema corresponding to points acquired by a Riegl Laser and a Velodyn Laser▓▒░--


	----
	--Adding a text descriptor to the pointcloud_formats table to ease human interpretation
	ALTER TABLE pointcloud_formats ADD COLUMN schema_name text;
	 
	----
	--Creating the XML  schema for points acquired by a riegl laser:
			--creating an entry for this schema
			
			INSERT INTO pointcloud_formats (pcid, srid, schema_name) VALUES (2, 0,'Riegl_Benchmark_IGN');--On crée un nouveau schema
			--Filling the entry
			UPDATE public.pointcloud_formats SET schema = 
			$$
			<?xml version="1.0" encoding="UTF-8"?>	<!-- RIEGL Laser schema -->
			<!-- ply header: 
				#We are really going ot use : 
					property double GPS_time
					property float x
					property float y
					property float z
					property float x_origin
					property float y_origin
					property float z_origin
					property float reflectance
					property float range
					property float theta
					property uint id
					property uint class
					property uchar num_echo
					property uchar nb_of_echo  
			-->
			
			<pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1" 
			    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			  <pc:dimension>
			    <pc:position>1</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>le temps GPS du moement de l acquisition du points. Note : il faudrait utiliser l offset et s assurer qu il n y a pas de decallage</pc:description>
			    <pc:name>GPS_time</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.000001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			 <!-- origine du senseur dans repere Lambert93 (modulo translation)-->
			 <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Coordonnées X du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>649000</pc:offset>
			  </pc:dimension>
			<pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Coordonnées Y du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>6840000</pc:offset>
			  </pc:dimension>
			<pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Coordonnées Z du senseur dans le repere Lambert 93, en metre,</pc:description>
			    <pc:name>z</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			   <!-- origine du senseur dans repere global (lamb93 translaté)-->
			  <pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>x_origin : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>x_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>6</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>y_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>y_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>7</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>z_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>z_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  
			  <pc:dimension>
			    <pc:position>8</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>l amplitude de l onde de retour corrigee de la distance, attention : peut etre faux lors de retour multiples, attention : impropre pour classification, la corriger par formule trouveepar remi cura</pc:description>
			    <pc:name>reflectance</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			     <pc:dimension>
			    <pc:position>9</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Valeur du temps de vol lors de lacquisition. de env 2.25 a + de 400, probablement en milli. Il faudrait determiner le scale proprement</pc:description>
			    <pc:name>range</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 <pc:dimension>
			    <pc:position>10</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>angle entre la direction d acquision et le plan horizontal, codeé entre -3 et +3 env. Il faudrait voir loffset</pc:description>
			    <pc:name>theta</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 
			  
			  
			 <pc:dimension>
			    <pc:position>11</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Une grandeur que je ne connais pas, entre -1 et plusieurs dizaine de milliers , par pas de 1</pc:description>
			    <pc:name>id</pc:name>
			    <pc:interpretation>uint32_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
				</pc:dimension>
			  
			  <pc:dimension>
			    <pc:position>12</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Une grandeur que je ne connais pas, entre -1 et plusieurs dizaine de milliers , par pas de 1</pc:description>
			    <pc:name>class</pc:name>
			    <pc:interpretation>uint32_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
				</pc:dimension>
			  
			    <!-- echo multiple-->

			    <pc:dimension>
			    <pc:position>17</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>le numero du retour dont ona tiré le point (entre 1 et 4)</pc:description>
			    <pc:name>num_echo</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>18</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>le nombre d echos obtenu par le rayon quia  donné ce point </pc:description>
			    <pc:name>nb_of_echo</pc:name>
			    <pc:interpretation>uint8_t</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension> 
			  
			  
			  <pc:metadata>
			    <Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>
			$$ 
			WHERE schema_name = 'Riegl_Benchmark_IGN';



--▓▒░Creating tables which will contain patches ▓▒░--

	----
	--Creating table for riegl laser, for space partitionning
		DROP TABLE IF EXISTS benchmark.riegl_pcpatch_space;
		CREATE TABLE benchmark.riegl_pcpatch_space(
			gid SERIAL PRIMARY KEY,
			patch PCPATCH(2)
		);
	-- 
--▓▒░End of the SQL script, now we need to launch the bash script to load data into the base▓▒░--
--that is , the "parallel_import_into_db.sh"


