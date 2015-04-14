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
	DROP SCHEMA IF EXISTS vosges_2011;
	--creating the schema
	CREATE SCHEMA vosges_2011;

	
--▓▒░Creating the XML schema corresponding to points acquired by a Riegl Laser and a Velodyn Laser▓▒░--


	----
	--Adding a text descriptor to the pointcloud_formats table to ease human interpretation
	ALTER TABLE pointcloud_formats ADD COLUMN nom_schema text;
	--truncate pointcloud_formats
	
	----
	--Creating a XML schema for the Velodyn Laser 
		INSERT INTO pointcloud_formats (pcid, srid, nom_schema) VALUES (2, 931008,'lidar_airborn_vosges_2011');--On crée un nouveau schema
		--On va remplir ce nouveau schéma
		UPDATE public.pointcloud_formats SET schema = 
		$$<?xml version="1.0" encoding="UTF-8"?><!-- lidar_airborn_vosges_2011_with_correct_scaling -->
			<!--  header  :  
				 las2txt -parse xyzticrn -sep space -i 000001.las -o 000001.txt
				x,y,z : lamb93 coordinate of the point
				t -time of acquisition
				i - intensity,
				c - classification
				r - number of this return 
				n - number of returns for given pulse 
				p - point source ID
			-->
			<pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1" 
			    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			  <pc:dimension>
			    <pc:position>1</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description> The X coordinate in Lambert 93 French referential</pc:description>
			    <pc:name>x</pc:name>
			    <pc:interpretation>int32_t</pc:interpretation>
			    <pc:scale>0.01</pc:scale>
				<pc:offset>1010000</pc:offset>
			  </pc:dimension>

			  <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description> The Y coordinate in Lambert 93 French referetnial</pc:description>
			    <pc:name>y</pc:name>
			    <pc:interpretation>int32_t</pc:interpretation>
			    <pc:scale>0.01</pc:scale>
				<pc:offset>6790000</pc:offset>
			  </pc:dimension>

			  <pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description> The Z coordinate in Lambert 93 French referetnial</pc:description>
			    <pc:name>z</pc:name>
			    <pc:interpretation>int32_t</pc:interpretation>
			    <pc:scale>0.01</pc:scale>
				<pc:offset>400</pc:offset>
			  </pc:dimension> 
			  
			 
			  <pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description> The gps_time at the precise moement of point acquisition</pc:description>
			    <pc:name>gps_time</pc:name>
			    <pc:interpretation>uint64_t</pc:interpretation>
			    <pc:scale>0.000001</pc:scale>
				<pc:offset>100000</pc:offset>
			  </pc:dimension>

				
			  <pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>2</pc:size>
			    <pc:description> intensity of the return wave
				</pc:description>
			    <pc:name>intensity</pc:name>
			    <pc:interpretation>uint16_t </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			  <pc:dimension>
			    <pc:position>6</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>classification of the point
				</pc:description>
			    <pc:name>classification</pc:name>
			    <pc:interpretation>uint8_t </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>

			<pc:dimension>
			    <pc:position>7</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description> number of this return 
				</pc:description>
			    <pc:name>return_number</pc:name>
			    <pc:interpretation>uint8_t </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>

			<pc:dimension>
			    <pc:position>8</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description> total number of return for this ray
				</pc:description>
			    <pc:name>tot_return_number</pc:name>
			    <pc:interpretation>uint8_t </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>

			<pc:dimension>
			    <pc:position>9</pc:position>
			    <pc:size>2</pc:size>
			    <pc:description>  point source ID
				</pc:description>
			    <pc:name>pt_src_id</pc:name>
			    <pc:interpretation>uint16_t </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>
			  <pc:metadata>
			    <Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>
			$$
			WHERE nom_schema = 'lidar_airborn_vosges_2011';



--▓▒░Creating tables which will contain patches ▓▒░--

	----
	--Creating table for riegl laser, for space partitionning
		DROP TABLE IF EXISTS vosges_2011.las_vosges_int;
		CREATE TABLE vosges_2011.las_vosges_int(
			gid SERIAL PRIMARY KEY,
			file_name text,
			patch PCPATCH(3)
		);
		ALTER TABLE vosges_2011.las_vosges_int SET TABLESPACE big_dd;
	
--▓▒░End of the SQL script, now we need to launch the bash script to load data into the base▓▒░--
--taht is , the "parallel_import_into_db.sh"


