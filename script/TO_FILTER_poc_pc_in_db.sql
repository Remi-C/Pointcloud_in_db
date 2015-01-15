/***************************
*Rémi Cura
*11/06/2013
*Thales TTS / IGN Matis-Cogit
*Script pour la démonstration d'une preuve de concept de l'utilisation de bdd pour stocker massivement des nuages de points
*Version "à la main" Adaptée aux données de l'acquisition Terra Mobilita 01/2013
***************************/

-------------
--Ce script va importer des données laser au format csv dans une base de données postgres /postgis/pointcloud
--Necessite : Postgres 9.3 | Postgis 2.0 | Pointcloud |PointCloud_postgis |Rply
--
--Déroulement du script
--Création d'une table temp de structure correspondante au fichier csv à charger
--importation du fichier csv dans cette table
--creation du schema XML correspondant et import dans table pointcloud
--creation de la table pour les pcpatch
--conversion depuis tab kle temp vers table pcp_patch
--creation des indexes
--requetes pour test de performances
-------------

safeguard contre l execution du script dun bloc, celui ci doit etre lancé a la main bout par bout.
VACUUM ANALYZE

--▓▒░Création d'une table temp de structure correspondante au fichier csv à charger▓▒░--
--structure de l'entete : 
DROP TABLE IF EXISTS poc_pc_in_db.riegl_temp;
CREATE TABLE poc_pc_in_db.riegl_temp (
	GPS_time double precision,
	x_sensor real,
	y_sensor real,
	z_sensor real,
	x_origin_sensor real,
	y_origin_sensor real, 
	z_origin_sensor real,
	x double precision,
	y double precision,
	z real,
	x_origin double precision,
	y_origin double precision,
	z_origin real,
	echo_range real,
	theta real,
	phi real,
	num_echo bigint,
	nb_of_echo bigint,
	amplitude real,
	reflectance real,
	deviation real,
	background_radiation float);

--On analyse la table pour etre sur
SELECT *
FROM poc_pc_in_db.riegl_temp
LIMIT 100

--▓▒░importation du fichier csv dans cette table▓▒░--
--sur linux : on cree le dossier partager pour pouvoir acceder aux données :
-- sudo mount -t vboxsf PC_in_DB partage_vbox
-- il faut aussi penser a editer etc/group pour ajouter l'utilisateur au groupe sfbox

--On va importer les données dans la table temp créer en utilisant des outils externe pour acceleerer
-- On lance le script sh présent dans le repertoire de voncersion /media/sf_PC_in_DB/poc_pc_in_db/convertisseur_ply_ascii/Ubuntu
-- ce script s'execute sur le serveur et importe les données dans la table temp (note : pour pouvoir faire du parallelisme, il faudrait pouvoir choisir le nom de la table et le transmettre)


--Exemple de la requete qui est utilisée pour charger les données dans la base
/*
COPY poc_pc_in_db.riegl_temp
FROM '/home/remi/partage_vbox/poc_pc_in_db/donnees_sources/riegl/ascii/temp'
WITH CSV DELIMITER AS ' ';
*/



--on verifie le contenu
SELECT min(deviation),max(deviation)
FROM poc_pc_in_db.riegl_temp
LIMIT 100
--on met a jours les stats pour la nouvelle table
VACUUM ANALYSE poc_pc_in_db.riegl_temp

--▓▒░Creation du schema XML correspondant et ajout dans la table pointcloud▓▒░--
--On crée le schéma XML qui correspond aux données :

--On modifie d'abord la table qui contient tous les schémas pour ajouter une colonne d'identifiant : 
SELECT * FROM pointcloud_formats; --on verifie que la colonne qu'on veut ajouter n'existe pas déjà
ALTER TABLE pointcloud_formats ADD COLUMN nom_schema text; --on ajoute une colonne pour donner un nom au schéma
 
--schéma XML : on vérifie d'abord que le schéma n'existe pas déjà
DELETE FROM pointcloud_formats WHERE pcid =2 ;
INSERT INTO pointcloud_formats (pcid, srid, nom_schema,schema) VALUES (2, 0, 'Riegl_nouvelle_acquisition_TMobilita_Janvier_2013' ,
'<?xml version="1.0" encoding="UTF-8"?>
<!-- Schéma du RIEGL nouvelle acquisiiton terra mobiltia Janvier 2013, version preuve de concept-->
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
  
  <!-- point dans repere local-->
  <pc:dimension>
    <pc:position>2</pc:position>
    <pc:size>4</pc:size>
    <pc:description>x_sensor : coorodnnée du point dans le repere du laser, du genre qq metres</pc:description>
    <pc:name>x_sensor</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
  <pc:dimension>
    <pc:position>3</pc:position>
    <pc:size>4</pc:size>
    <pc:description>y_sensor : coorodnnée du point dans le repere du laser, du genre qq metres</pc:description>
    <pc:name>y_sensor</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>4</pc:position>
    <pc:size>4</pc:size>
    <pc:description>z_sensor : coorodnnée du point dans le repere du laser, du genre qq metres</pc:description>
    <pc:name>z_sensor</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>

  
  <!-- origine du senseur dans repere local-->
  <pc:dimension>
    <pc:position>5</pc:position>
    <pc:size>4</pc:size>
    <pc:description>x_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
    <pc:name>x_origin_sensor</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.00001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>6</pc:position>
    <pc:size>4</pc:size>
    <pc:description>y_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
    <pc:name>y_origin_sensor</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.00001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>7</pc:position>
    <pc:size>4</pc:size>
    <pc:description>z_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
    <pc:name>z_origin_sensor</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.00001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
 
 <!-- point dans repere Lambert 93 en metre (modulo transformation)-->
 <pc:dimension>
    <pc:position>8</pc:position>
    <pc:size>5</pc:size>
    <pc:description>Coordonnées X du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
    <pc:name>x</pc:name>
    <pc:interpretation>double</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>649000</pc:offset>
  </pc:dimension>
   <pc:dimension>
    <pc:position>9</pc:position>
    <pc:size>5</pc:size>
    <pc:description>Coordonnées Y du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
    <pc:name>y</pc:name>
    <pc:interpretation>double</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>6840000</pc:offset>
  </pc:dimension>
	<pc:dimension>
    <pc:position>10</pc:position>
    <pc:size>5</pc:size>
    <pc:description>Coordonnées Z du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
    <pc:name>z</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
 
 
 <!-- origine du senseur dans repere Lambert93 (modulo translation)-->
 <pc:dimension>
    <pc:position>11</pc:position>
    <pc:size>5</pc:size>
    <pc:description>Coordonnées X du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
    <pc:name>x_origin</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.0001</pc:scale>
	<pc:offset>649000</pc:offset>
  </pc:dimension>
<pc:dimension>
    <pc:position>12</pc:position>
    <pc:size>5</pc:size>
    <pc:description>Coordonnées Y du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
    <pc:name>y_origin</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.0001</pc:scale>
	<pc:offset>6840000</pc:offset>
  </pc:dimension>
<pc:dimension>
    <pc:position>13</pc:position>
    <pc:size>5</pc:size>
    <pc:description>Coordonnées Z du senseur dans le repere Lambert 93, en metre,</pc:description>
    <pc:name>z_origin</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.0001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
 
 
 <!-- mesure geom-->
   <pc:dimension>
    <pc:position>14</pc:position>
    <pc:size>4</pc:size>
    <pc:description>Valeur du temps de vol lors de lacquisition. de env 2.25 a + de 400, probablement en milli. Il faudrait determiner le scale proprement</pc:description>
    <pc:name>echo_range</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
  <pc:dimension>
    <pc:position>15</pc:position>
    <pc:size>4</pc:size>
    <pc:description>angle entre la direction d acquision et le plan horizontal, codeé entre -3 et +3 env. Il faudrait voir loffset</pc:description>
    <pc:name>theta</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.0001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>16</pc:position>
    <pc:size>4</pc:size>
    <pc:description>un autre angle entre la direction d acquision et ???, codé enrte -0.005 et -0.004. Il faudrait regler loffset</pc:description>
    <pc:name>phi</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.000001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
  
 
  <!-- echo multiple-->

    <pc:dimension>
    <pc:position>17</pc:position>
    <pc:size>1</pc:size>
    <pc:description>le numero du retour dont ona tiré le point (entre 1 et 4)</pc:description>
    <pc:name>num_echo</pc:name>
    <pc:interpretation>int</pc:interpretation>
    <pc:scale>1</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>18</pc:position>
    <pc:size>1</pc:size>
    <pc:description>le nombre d echos obtenu par le rayon quia  donné ce point </pc:description>
    <pc:name>nb_of_echo</pc:name>
    <pc:interpretation>int</pc:interpretation>
    <pc:scale>1</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
  
    <!-- donnees avancee-->
  <pc:dimension>
    <pc:position>19</pc:position>
    <pc:size>4</pc:size>
    <pc:description>l amplitude de l onde de retour, attention : peut etre faux lors de retour multiples</pc:description>
    <pc:name>amplitude</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.0001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
  <pc:dimension>
    <pc:position>20</pc:position>
    <pc:size>4</pc:size>
    <pc:description>l amplitude de l onde de retour corrigee de la distance, attention : peut etre faux lors de retour multiples, attention : impropre pour classification, la corriger par formule trouveepar remi cura</pc:description>
    <pc:name>reflectance</pc:name>
    <pc:interpretation>float</pc:interpretation>
    <pc:scale>0.0001</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>21</pc:position>
    <pc:size>2</pc:size>
    <pc:description>Une grandeur que je ne connais pas, entre -1 et plusieurs dizaine de milliers , par pas de 1</pc:description>
    <pc:name>deviation</pc:name>
    <pc:interpretation>int</pc:interpretation>
    <pc:scale>1</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>
    <pc:dimension>
    <pc:position>22</pc:position>
    <pc:size>1</pc:size>
    <pc:description>Une grandeur que je ne connais pas, vaut toujours nan, on la stocke comme un entier</pc:description>
    <pc:name>background_radiation</pc:name>
    <pc:interpretation>int</pc:interpretation>
    <pc:scale>1</pc:scale>
	<pc:offset>0</pc:offset>
  </pc:dimension>

  <pc:metadata>
    <Metadata name="compression">dimensional</Metadata>
  </pc:metadata>
</pc:PointCloudSchema>');




    
----
--On lit le schema pour être sur que tt vas bien
SELECT *
FROM pointcloud_formats

--On rajoute les srid et les proj de l'IGN en utilisant le script fait par Rémi Cura

--On test ce schéma en essayant de créer un point qui le respecte
WITH temp AS (
SELECT *
FROM poc_pc_in_db.riegl_temp 
LIMIT 10000)
SELECT PC_Get(PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float
] ),'y')
FROM temp




--▓▒░creation de la table pour les pcpatch▓▒░--

	--on commence par créér une table de pcpoint pour le test
	DROP TABLE IF EXISTS poc_pc_in_db.riegl_pcpoint;
	CREATE TABLE poc_pc_in_db.riegl_pcpoint(
		gid SERIAL,
		point PCPOINT(2)
	);

	--On verifie le contenu de la table :
	SELECT *
	FROM poc_pc_in_db.riegl_pcpoint

	--On va peupler la table en construisant des points : pour 1.5 e6 : 9.2 secs
	INSERT INTO poc_pc_in_db.riegl_pcpoint ( point) 
		SELECT PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float
	] ) AS point
		FROM  poc_pc_in_db.riegl_temp AS pcr
		LIMIT 10
	--mise a jour des stats
	VACUUM ANALYZE poc_pc_in_db.riegl_temp
	VACUUM ANALYZE
	--On vérifie le contenu de la table
	SELECT PC_AsText(point)
	FROM poc_pc_in_db.riegl_pcpoint

	--On fait un test sur la création de patch
		SELECT Pc_AsText(PC_patch(point)) AS patch
		FROM poc_pc_in_db.riegl_pcpoint as src
		GROUP BY 0.5*ROUND(2*ST_X(point::geometry)),0.5*ROUND(2*ST_Y(point::geometry)),0.5*ROUND(2*ST_Z(point::geometry))
	--Ca a l'air de marcher.

	--On verifie que le casting auto en geometry prend bien les coordonnées x y z par défaut
	SELECT ST_AsText(point::geometry) AS geomtrie_vue_par_pcpoint, PC_Get(point, 'x') AS x_reel_pcpoint,PC_Get(point, 'y') AS y_reel_pcpoint, PC_Get(point, 'z') AS z_reel_pcpoint
	FROM poc_pc_in_db.riegl_pcpoint
	SELECT x,y,z
	FROM  poc_pc_in_db.riegl_temp AS pcr
		LIMIT 10

	--On crée la table pour les pc_patch spatiaux
	DROP TABLE IF EXISTS poc_pc_in_db.riegl_pcpatch_space;
	CREATE TABLE poc_pc_in_db.riegl_pcpatch_space(
		gid SERIAL,
		patch PCPATCH(2)
	);
	--on crée une table pour les pcpatch temporaux de 100 milli
	DROP TABLE IF EXISTS poc_pc_in_db.riegl_pcpatch_time;
	CREATE TABLE poc_pc_in_db.riegl_pcpatch_time(
		gid SERIAL,
		patch PCPATCH(2)
	);

	--on crée une table pour les pcpatch temporaux de 1 milli
	DROP TABLE IF EXISTS poc_pc_in_db.riegl_pcpatch_time_1milli;
	CREATE TABLE poc_pc_in_db.riegl_pcpatch_time_1milli(
		gid SERIAL,
		patch PCPATCH(2)
	);




--▓▒░conversion depuis table temp vers table pcp_patch▓▒░--

	--On crée l a table en partitionnement spatial de 1 mètre cube, temps pour le fichier 20 : sans passage par points (calcul direct) 126secs
	WITH to_insert AS (
		SELECT PC_patch(point) AS patch
		FROM (
			SELECT PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float] ) AS point
			FROM  poc_pc_in_db.riegl_temp AS pcr
			) table_point
		GROUP BY ROUND(PC_Get(point,'x')),ROUND(PC_Get(point,'y')),ROUND(PC_Get(point,'z'))
	)
	INSERT INTO poc_pc_in_db.riegl_pcpatch_space (patch) SELECT to_insert.patch FROM to_insert

		--vacuum analyze pour libérer l'espace en cas de créatioon mutliple de la meme table (test/debug)
		VACUUM ANALYZE poc_pc_in_db.riegl_pcpatch_space;
		--On regarde le contenu de cette table de patch
		SELECT min(PC_NumPoints(patch)),max(PC_NumPoints(patch))
		FROM poc_pc_in_db.riegl_pcpatch_space
		ORDER BY pc_numpoints DESC

		--On regarde les chalmps x y z des points dans le patch
		SELECT gid, PC_get(PC_Explode(patch),'y')
		FROM poc_pc_in_db.riegl_pcpatch_space
		LIMIT 10


	--attention : On crée la table pcpatch par regropupement temporel tt les 100 milisecondes; temps pour fichier riegl 0020 : 190sec
	WITH to_insert AS (
		SELECT PC_patch(point) AS patch
		FROM (
			SELECT PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float] ) AS point
			FROM  poc_pc_in_db.riegl_temp AS pcr
			) table_point
		GROUP BY ROUND(10*PC_Get(point,'gps_time'))
	)
	INSERT INTO poc_pc_in_db.riegl_pcpatch_time (patch) SELECT to_insert.patch FROM to_insert
		
		--vacuum analyze pour libérer l'espace en cas de créatioon mutliple de la meme table (test/debug)
		VACUUM ANALYZE poc_pc_in_db.riegl_pcpatch_time;

		--On regarde quelques stats sur les patch temporels 100 millisec
		SELECT min(PC_NumPoints(patch)) AS min_points_par_patch,max(PC_NumPoints(patch)) AS max_points_par_patch, avg(PC_NumPoints(patch)) AS moyenne_points_par_patch
		FROM poc_pc_in_db.riegl_pcpatch_time

		--On crée des aptchs temporels de 1 miliseconde : temps d'écriture : 89sec
		WITH to_insert AS (
			SELECT PC_patch(point) AS patch
			FROM (
				SELECT PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float] ) AS point
				FROM  poc_pc_in_db.riegl_temp AS pcr
				) table_point
			GROUP BY ROUND(1000*PC_Get(point,'gps_time'))
		)
		INSERT INTO poc_pc_in_db.riegl_pcpatch_time_1milli (patch) SELECT to_insert.patch FROM to_insert

			--vaccum analyze obligatoire en environnement de test
			VACUUM ANALYZE poc_pc_in_db.riegl_pcpatch_time_1milli;

			--On regarde quelques stats sur les patch temporels 1 millisec
			SELECT min(PC_NumPoints(patch)) AS min_points_par_patch,max(PC_NumPoints(patch)) AS max_points_par_patch, avg(PC_NumPoints(patch)) AS moyenne_points_par_patch
			FROM poc_pc_in_db.riegl_pcpatch_time_1milli



	--On importe la table de patch dans qgis en calculant une intersection pour limiter le champ
	-- la table intersectante est celle pc_in_db.clipping_pour_laser , qui définie une petite zone dans le riegl20
			--test dans qgis
			/*SELECT clippee.gid, clippee.patch::geometry
			FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE*/
			--test dans qgis : on veux afficher les points
			/*
			SELECT row_number() over() AS gid ,point.geom AS geom
			FROM  (	SELECT PC_Explode(clippee.patch)::geometry AS geom 
				FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
				WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE 
			) AS point
			*/
			--On ajoute aussiq a qgis les dalle temporelle en milliseconde
			/*
			SELECT gid, patch::geometry AS geom
			FROM poc_pc_in_db.riegl_pcpatch_time_1milli AS clippee
			WHERE poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(clippee.patch, 'gps_time')&& NUMRANGE(54193.5966089597,54194.1264872)
			*/
			


	--d'abord 3 tests d'intersections pour voir les perfs sans indexes (peformance : premier appel, moyenne appels suivants)

	--spatiaux 1m3 : 0.6sec/0.17sec
	SELECT 1
	FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
	WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

		--spatiaux  : combien de temps prend al deserialisation : 1 a 2 sec , 0.8sec en explain
		SELECT PC_Explode(clippee.patch)::geometry AS geom 
		FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE 
	
		--la zone interessecté correspond au moment d'acquisition entre 54193.5966089597 et 54194.1264872 pour le gps_time (obtenu par requete suivante)
		SELECT min(PC_PatchMin(clippee.patch, 'gps_time')), max(PC_PatchMax(clippee.patch, 'gps_time'))
		FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

	--temporel 100 milliseconde, par méthode du min max : 35sec/35secs
	SELECT 1
	FROM poc_pc_in_db.riegl_pcpatch_time AS clippee
	WHERE PC_PatchMin(clippee.patch, 'gps_time')>54193.5966089597 AND PC_PatchMax(clippee.patch, 'gps_time')<54194.1264872
		--temporel 100 milliseconde, par méthode de la lecture de tout : je n'arrive aps a faire marccher
		SELECT 1
		FROM poc_pc_in_db.riegl_pcpatch_time AS clippee
		HAVING 54193.5966089597 < ANY(array_agg(PC_Get(PC_Explode(clippee.patch), 'gps_time'))) >54193.5966089597 AND PC_Get(PC_Explode(clippee.patch), 'gps_time')<54194.1264872

	--temporel 1 milliseconde, par méthode du min max : 31sec
	SELECT 1
	FROM poc_pc_in_db.riegl_pcpatch_time_1milli AS clippee
	WHERE PC_PatchMin(clippee.patch, 'gps_time')>54193.5966089597 AND PC_PatchMax(clippee.patch, 'gps_time')<54194.1264872
	
	SELECT clippee.gid, clippee
	FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
	WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

--▓▒░creation des indexes▓▒░--

--NUMRANGE() : pour definir un intervale numerique entre deux temps ! 


	--On va d'abord créer l'index spatial sur la table partionné en dalle de 1m3 : 0.4sec (très peu de lignes)
	CREATE INDEX poc_pc_in_db_riegl_pcpatch_space_patch_gist_2D ON poc_pc_in_db.riegl_pcpatch_space USING GIST (CAST(patch AS geometry));
	VACUUM ANALYZE poc_pc_in_db.riegl_pcpatch_space;

		--performance : pour la meme intersection : 0.016 sec au lieu de 0.16sec
		--		pour l'affichage des points : 2sec, 0.5sec pour le explain : on a gagné le temps de recherche, le temps d'accès aux données reste important


		--evaluation du temps de deserialisaiton
			--recup des patch : execution 2 sec, explain analyse : 0.015sec
			SELECT clippee.patch AS geom 
			FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
			--recup des patch et deserialisation  : execution  2.4sec, explain analyse : 0.6sec
			SELECT PC_Explode(clippee.patch)::geometry AS geom 
			FROM poc_pc_in_db.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE 


	--On crée l'index temporel : on crée un index sur l'intervalle de temps qui est représenté par chaque dalle de temps
	--temps de création pour la table 1 milli : 50 sec, taille index : 0.9k
	CREATE INDEX poc_pc_in_db_riegl_pcpatch_time_1milli_patch_gist_range 
	ON poc_pc_in_db.riegl_pcpatch_time_1milli 
	USING GIST ( poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(patch,'gps_time')
		);
	VACUUM ANALYZE poc_pc_in_db.riegl_pcpatch_time_1milli;
		--on test ce nouvel index avec une requete qui l'utilise : temps exec : 0.015sec, a comaparer à 35secs
		SELECT 1
		FROM poc_pc_in_db.riegl_pcpatch_time_1milli AS clippee
		WHERE poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(clippee.patch, 'gps_time')&& NUMRANGE(54193.5966089597,54194.1264872)

		

	--On crée l'index temporel : on crée un index sur l'intervalle de temps qui est représenté par chaque dalle de temps
	--temps de création pour la table 100 milli : 57sec, taille index : 0
	CREATE INDEX poc_pc_in_db_riegl_pcpatch_time_patch_gist_range 
	ON poc_pc_in_db.riegl_pcpatch_time 
	USING GIST ( poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(patch,'gps_time')
		);
	VACUUM ANALYZE poc_pc_in_db.riegl_pcpatch_time;
		--on test ce nouvel index avec une requete qui l'utilise : temps exec : 0.015sec, a comaparer à 35secs
		SELECT gid, patch::geometry AS geom
		FROM poc_pc_in_db.riegl_pcpatch_space AS clippee
		WHERE poc_pc_in_db.rc_compute_range_for_a_patch(clippee.patch, 'gps_time')&& NUMRANGE(54193.5966089597,54194.1264872)




--▓▒░requetes pour test de performances▓▒░--






--▓▒░ANNEXE : fonction pour calcul d'index▓▒░--

# CREATE OR REPLACE FUNCTION
get_text(key text, data json)
RETURNS text $$
  return data[key];
$$ LANGUAGE plv8 IMMUTABLE STRICT;



DROP FUNCTION IF EXISTS poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(PCPATCH,text);

CREATE OR REPLACE FUNCTION poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(patch PCPATCH, nom_grandeur_pour_interval text)
RETURNS NUMRANGE AS $$ 
BEGIN
/*
Cette fonction prend en entrée un patch et calcul l'intervalle (du min au max) pour la grandeur donnée en argument
*/

RETURN NUMRANGE(PC_PatchMin(patch, nom_grandeur_pour_interval),PC_PatchMax(patch, nom_grandeur_pour_interval));
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE;
--Un exemple d'utilisation
SELECT poc_pc_in_db.rc_compute_gpstime_range_for_a_patch(patch,'gps_time')
FROM poc_pc_in_db.riegl_pcpatch_time_1milli
LIMIT 100




--▓▒░Ajout du support du Velodyn▓▒░--

	--▓▒░creation table temp▓▒░--

		DROP TABLE IF EXISTS poc_pc_in_db.velo_temp;
		CREATE TABLE poc_pc_in_db.velo_temp (
		gps_time double precision,
		 echo_range integer,
		 intensity smallint,
		 theta integer,
		 block_id integer,
		 fiber smallint,
		 x_laser double precision,
		 y_laser double precision,
		 z_laser double precision,
		 x double precision,
		 y double precision,
		 z double precision,
		 x_centre_laser double precision,
		 y_centre_laser double precision,
		 z_centre_laser double precision
		 )

		--verif sur la table créée
		SELECT *
		FROM poc_pc_in_db.velo_temp
		LIMIT 100

	--▓▒░import des données ply dans base de donnée▓▒░--
	/*
	On lance le script 
	de la façon suivante :
		 ./chargement_data_dans_bdd_avec_arguments.sh 
			poc_pc_in_db.velo_temp
			/media/sf_PC_in_DB/poc_pc_in_db/donnees_sources/velo/ply/terMob2_LAMB93_0109.ply 
			/media/sf_PC_in_DB/poc_pc_in_db/convertisseur_ply_ascii/RPly_Ubuntu/RPly_convert
		Arguments :
			#$1 : nom de la table postgres qualifiée par schema qui doit recevoir les données (attention, la table doit être dans un format correspondant aux données)
			#$2 : nom du fichier ply binaire contenant les données (avec chemin) 
			#$3 : chemin vers l'executable de conversion de ply binaire a ply ascii (attention cette conversion ne doit pas sortir l'entete)
		*/

		--verification du contenu de la table :
			SELECT *
			FROM poc_pc_in_db.velo_temp
			LIMIT 100
		--update des stats de postgres
			VACUUM ANALYZE poc_pc_in_db.velo_temp

	--▓▒░Création du schéma XML ▓▒░--
		--doc: http://www.pointcloud.org/api/cpp/dimension.html
	--schéma XML : on vérifie d'abord que le schéma n'existe pas déjà
		SELECT * FROM pointcloud_formats
		DELETE FROM pointcloud_formats WHERE nom_schema = 'Velo_nouvelle_acquisition_TMobilita_Janvier_2013' --?on le supprime?

		INSERT INTO pointcloud_formats (pcid, srid, nom_schema) VALUES (3, 0,'Velo_nouvelle_acquisition_TMobilita_Janvier_2013');--On crée un nouveau schema
			--On va remplir ce nouveau schéma
			--On a besoin d'informations sur les données
			SELECT attname AS nom_colonne, avg_width, n_distinct, most_common_vals, most_common_freqs, histogram_bounds, correlation FROM pg_stats WHERE schemaname ILIKE 'poc_pc_in_db' AND tablename = 'velo_temp'
			SELECT min(block_id), max(block_id) FROM poc_pc_in_db.velo_temp
			SELECT * FROM poc_pc_in_db.velo_temp LIMIT 100
		UPDATE public.pointcloud_formats SET schema = 
		$$<?xml version="1.0" encoding="UTF-8"?><!-- Schéma du VELODYN nouvelle acquisiiton terra mobiltia Janvier 2013, version preuve de concept-->
			<!-- Schéma du VELODYN nouvelle acquisiiton terra mobiltia Janvier 2013, version preuve de concept
			En tête  ply  :
				property float64 GPS_time
				property uint16 range 
				property uint8 intensity 
				property uint16 theta 
				property uint16 block_id 
				property uint8 fiber 
				property float32 x_laser
				property float32 y_laser
				property float32 z_laser
				property float32 x 
				property float32 y 
				property float32 z 
				property float32 x_centre_laser
				property float32 y_centre_laser
				property float32 z_centre_laser
			-->
			<pc:PointCloudSchema xmlns:pc="http://pointcloud.org/schemas/PC/1.1" 
			    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			  <pc:dimension>
			    <pc:position>1</pc:position>
			    <pc:size>8</pc:size>
			    <pc:description>le temps GPS du moement de l acquisition du points. Note : il faudrait utiliser l offset et s assurer qu il n y a pas de decallage</pc:description>
			    <pc:name>gps_time</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.00000001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			  <!--parametres acquisition : echo_range, intensity, theta, block id , fiber-->
			  <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>2</pc:size>
			    <pc:description>echo_range : valeur de temps de vol du retour de l echo laser
						Entre 0 et 60k
				</pc:description>
			    <pc:name>echo_range</pc:name>
			    <pc:interpretation>UnsignedInteger </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>
			
			<pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>intensity : valeur de l intensite du retour laser
						Entre 0 et 255
				</pc:description>
			    <pc:name>intensity</pc:name>
			    <pc:interpretation>UnsignedInteger </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			<pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>2</pc:size>
			    <pc:description>theta : valeur de l angle entre le plan horizontale et le rayon d acquisition
						Entre 0 et 60k
				</pc:description>
			    <pc:name>theta</pc:name>
			    <pc:interpretation>UnsignedInteger </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>
			
			<pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>2</pc:size>
			    <pc:description>block_id : A quoi ça sert?? : seulement deux valeurs distinctes
				</pc:description>
			    <pc:name>vlock_id</pc:name>
			    <pc:interpretation>UnsignedInteger </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			</pc:dimension>

			<pc:dimension>
			    <pc:position>6</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>intensity : numero de la fibre qui a fait l acquisition
						Entre 0 et 64
				</pc:description>
			    <pc:name>fiber</pc:name>
			    <pc:interpretation>UnsignedInteger </pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>


			<!--les points acquis dans le repère du laser :x_laser, y_laser, z_laser -->
			<pc:dimension>
			    <pc:position>7</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Coordonnées X du point dans le repère relatif du laser, en metre</pc:description>
			    <pc:name>x_laser</pc:name>
			    <pc:interpretation>float </pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  <pc:dimension>
			    <pc:position>8</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Coordonnées Y du point dans le repère relatif du laser, en metre</pc:description>
			    <pc:name>y_laser</pc:name>
			    <pc:interpretation>float </pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  <pc:dimension>
			    <pc:position>9</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Coordonnées Z du point dans le repère relatif du laser, en metre</pc:description>
			    <pc:name>z_laser</pc:name>
			    <pc:interpretation>float </pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			  
			<!-- point acquis dans repere Lambert 93 en metre (modulo transformation) : x , y , z -->
			 <pc:dimension>
			    <pc:position>10</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées X du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>649000</pc:offset>
			  </pc:dimension>
			   <pc:dimension>
			    <pc:position>11</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Y du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>6840000</pc:offset>
			  </pc:dimension>
				<pc:dimension>
			    <pc:position>12</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Z du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>z</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			 <!-- origine acquisition dans repere Lambert 93 en metre (modulo transformation) : x_centre_laser , y_centre_laser , z_centre_laser -->
			 <pc:dimension>
			    <pc:position>13</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées X du centre du laser au moment de l acquisition,  dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x_centre_laser</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>649000</pc:offset>
			  </pc:dimension>
			   <pc:dimension>
			    <pc:position>14</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Y du centre du laser au moment de l acquisition,  dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y_centre_laser</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>6840000</pc:offset>
			  </pc:dimension>
				<pc:dimension>
			    <pc:position>15</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Z du centre du laser au moment de l acquisition,  dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>z_centre_laser</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  <pc:metadata>
			    <Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>
			$$
			WHERE nom_schema = 'Velo_nouvelle_acquisition_TMobilita_Janvier_2013';

	
			--On lit le schema pour être sur que tt vas bien
			SELECT *
			FROM pointcloud_formats

	

		--On test ce schéma en essayant de créer un point qui le respecte
			WITH temp AS (
			SELECT *
			FROM poc_pc_in_db.velo_temp 
			LIMIT 10)
			SELECT PC_AsText(PC_MakePoint(3, ARRAY[gps_time,echo_range,intensity,theta,block_id,fiber,x_laser,y_laser,z_laser,x,y,z,x_centre_laser,y_centre_laser,z_centre_laser
			] ))
			FROM temp
			
			--On vérifie que la précision est suffisante 
			WITH temp AS (
			SELECT PC_MakePoint(3, ARRAY[gps_time,echo_range,intensity,theta,block_id,fiber,x_laser,y_laser,z_laser,x,y,z,x_centre_laser,y_centre_laser,z_centre_laser
			] ) AS point
			FROM poc_pc_in_db.velo_temp 
			LIMIT 100000)
			SELECT PC_get(point,'x'),PC_get(point,'y'),PC_get(point,'z')
			FROM temp
			ORDER BY PC_get(point,'y') ASC

	--▓▒░creation de la table pour les pcpatch▓▒░--

		--On rajoute les srid et les proj de l'IGN en utilisant le script fait par Rémi Cura

		--On crée les différentes tables de pcpatch 
		--Pour rappel : on test la creation de patch temporel(1 mili) et spatiaux (1m3)
			DROP TABLE IF EXISTS poc_pc_in_db.velo_pcpatch_space;
			CREATE TABLE poc_pc_in_db.velo_pcpatch_space(
				gid SERIAL,
				patch PCPATCH(3)
			);
			--on crée une table pour les pcpatch temporaux de 1 milli
			DROP TABLE IF EXISTS poc_pc_in_db.velo_pcpatch_time_1milli;
			CREATE TABLE poc_pc_in_db.velo_pcpatch_time_1milli(
				gid SERIAL,
				patch PCPATCH(3)
			);
		--On peuple ce tables àpartir des données brutes
			
			--partition spatiale : 150 sec/170sec
			WITH to_insert AS (
			SELECT PC_patch(point) AS patch
			FROM (
				SELECT PC_MakePoint(3, ARRAY[gps_time,echo_range,intensity,theta,block_id,fiber,x_laser,y_laser,z_laser,x,y,z,x_centre_laser,y_centre_laser,z_centre_laser] ) AS point
				FROM  poc_pc_in_db.velo_temp AS pcr
				) table_point
			GROUP BY ROUND(PC_Get(point,'x')),ROUND(PC_Get(point,'y')),ROUND(PC_Get(point,'z'))
			)
			INSERT INTO poc_pc_in_db.velo_pcpatch_space (patch) SELECT to_insert.patch FROM to_insert;

				--vacuum analyze pour libérer l'espace en cas de création mutliple de la meme table (test/debug)
				VACUUM ANALYZE poc_pc_in_db.velo_pcpatch_space;
				--On regarde le contenu de cette table de patch
				SELECT min(PC_NumPoints(patch)),max(PC_NumPoints(patch)), avg(PC_NumPoints(patch))
				FROM poc_pc_in_db.velo_pcpatch_space
				--On regarde les chalmps x y z des points dans le patch
				




			--On crée des aptchs temporels de 1 miliseconde : temps d'écriture : 84sec / 100sec
			WITH to_insert AS (
				SELECT PC_patch(point) AS patch
				FROM (
					SELECT PC_MakePoint(3, ARRAY[gps_time,echo_range,intensity,theta,block_id,fiber,x_laser,y_laser,z_laser,x,y,z,x_centre_laser,y_centre_laser,z_centre_laser] ) AS point
					FROM  poc_pc_in_db.velo_temp AS pcr
					) table_point
				GROUP BY ROUND(1000*PC_Get(point,'gps_time'))
			)
			INSERT INTO poc_pc_in_db.velo_pcpatch_time_1milli (patch) SELECT to_insert.patch FROM to_insert

				--vaccum analyze obligatoire en environnement de test
				VACUUM ANALYZE poc_pc_in_db.velo_pcpatch_time_1milli;

				--On regarde quelques stats sur les patch temporels 1 millisec
				SELECT min(PC_NumPoints(patch)),max(PC_NumPoints(patch)), avg(PC_NumPoints(patch))
				FROM poc_pc_in_db.velo_pcpatch_time_1milli



	--▓▒░creation des indexes pour velo▓▒░--

	--Index spatial sur velodyn
		CREATE INDEX poc_pc_in_db_velo_pcpatch_space_patch_gist_2D ON poc_pc_in_db.velo_pcpatch_space USING GIST (CAST(patch AS geometry));
	
	--Index temporel sur velo
		CREATE INDEX poc_pc_in_db_velo_pcpatch_space_patch_gist_range_gps_time 
			ON poc_pc_in_db.velo_pcpatch_space
			USING GIST ( poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time'));


	
	--▓▒░test requetes utilisant les indexes▓▒░--

		----
		--Requetes temporels
			--intersection avec un interval de temps
			SELECT gid, patch::geometry AS geom
			FROM poc_pc_in_db.velo_pcpatch_space AS clippee
			WHERE poc_pc_in_db.rc_compute_range_for_a_patch(clippee.patch, 'gps_time')&& NUMRANGE(54193.5966089597,54194.1264872)

		----
		--Requetes spatial
			--intersection avec geometrie
			SELECT clippee.gid, PC_Explode(patch) AS geom
			FROM poc_pc_in_db.velo_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE 



		----
		--analyse des patch crée
			--riegl : nombre moyen, min, max d'éléments par patch : 1;23004;365
				SELECT min(PC_NumPoints(patch)),max(PC_NumPoints(patch)),avg(PC_NumPoints(patch))
				FROM poc_pc_in_db.riegl_pcpatch_space AS clippee

			--riegl : analyse du pourcentage du nombre de patch contenant un seul point : 5%
				SELECT 1.0 * count(*)::float / (select count(*) FROM poc_pc_in_db.riegl_pcpatch_space)
				FROM poc_pc_in_db.riegl_pcpatch_space AS clippee
				WHERE PC_NumPoints(patch)=1


			--velo : nombre moyen, min, max d'éléments par patch : 1;54939;322
				SELECT min(PC_NumPoints(patch)),max(PC_NumPoints(patch)),avg(PC_NumPoints(patch))
				FROM poc_pc_in_db.velo_pcpatch_space AS clippee 

			--velo : analyse du pourcentage du nombre de patch contenant un seul point : 10%
				SELECT 1.0 * count(*)::float / (select count(*) FROM poc_pc_in_db.velo_pcpatch_space)
				FROM poc_pc_in_db.velo_pcpatch_space AS clippee
				WHERE PC_NumPoints(patch)=1



SELECT row_number() over() AS gid ,point.geom AS geom 
FROM 
	(
	SELECT *
	FROM 
		( 	
		SELECT PC_Get(p,'x'),PC_Get(p,'y'), C_Get(p,'z')
			FROM PC_Explode(clippee.patch)  AS p
				)
			)AS geom 
		FROM poc_pc_in_db.velo_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur 
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE 
		) AS point_pcpoint
	) AS point_postgis				


SELECT PC_get(point,'x') AS x, PC_get(point,'y') AS y, PC_get(point,'z') AS z
		FROM(
		SELECT PC_Explode(patch) AS point
		FROM poc_pc_in_db.velo_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur 
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE 
		) AS point_pcpoint





SELECT 	p.x, p.y,p.z, PC_get(point,'x') AS x_pcpoint,PC_get(point,'y') AS y_pcpoint,PC_get(point,'z') AS z_pcpoint
	FROM
	(SELECT t.x as x,t.y as y,t.z as z,PC_MakePoint(3, ARRAY[gps_time,echo_range,intensity,theta,block_id,fiber,x_laser,y_laser,z_laser,x,y,z,x_centre_laser,y_centre_laser,z_centre_laser] ) AS point
	FROM	(
		SELECT *
		FROM poc_pc_in_db.riegl_pcpatch AS clippee, pc_in_db.clipping_pour_laser AS clippeur
		WHERE ST_Intersects(ST_MakePoint(x,y,z),clippeur.geom)=TRUE
		ORDER BY y ASC
		) AS t
	) AS p




------------
--------
----temp

--requetes pour créer les index temp et spatiaux sur velo et riegl spatiaux


	----
	--Sur riegl
		CREATE INDEX poc_pc_in_db_riegl_pcpatch_space_patch_gist_2D ON poc_pc_in_db.riegl_pcpatch_space USING GIST (CAST(patch AS geometry));
	----
	--Sur velodyn
		CREATE INDEX poc_pc_in_db_velo_pcpatch_space_patch_gist_2D ON poc_pc_in_db.velo_pcpatch_space USING GIST (CAST(patch AS geometry));
	--Index temporel sur riegl
		CREATE INDEX poc_pc_in_db_riegl_pcpatch_space_patch_gist_range_gps_time
			ON poc_pc_in_db.riegl_pcpatch_space
			USING GIST ( poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time'));
	--Index temporel sur velo
		CREATE INDEX poc_pc_in_db_velo_pcpatch_space_patch_gist_range_gps_time 
			ON poc_pc_in_db.velo_pcpatch_space
			USING GIST ( poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time'));









-----------------
--------
--Travail sur le même schéma qu'a l'IGN
--On cherche à comprendre les raisons de la différence de perfs
----
	--On verifie le contenu de la table qui contient 50 fichiers riegl
		--nombre de points total dans la base, min, max, avg point par patch
		SELECT sum(PC_NumPoints(patch)), min(PC_NumPoints(patch)), max(PC_NumPoints(patch))
		FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

		--quelques infos sur les patchs : 156 000 000 / 1 / 399 895 : en 253 sec, nombre de ligne de la table : 740k
		SELECT sum(PC_NumPoints(patch)), min(PC_NumPoints(patch)), max(PC_NumPoints(patch)), avg(PC_NumPoints(patch))
		FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee

		--peuplement de la colonne geom : 
			--On enleve le Z : 
			ALTER TABLE acquisition_tmob_012013.riegl_pcpatch_space ALTER COLUMN geom TYPE geometry(Polygon)
			--on ajoute la boite englobante 2D de chaque patch : temps : 660 sec (en comptant l update de l'index)/ poids approx en plus sur disque : 1 Go
			UPDATE acquisition_tmob_012013.riegl_pcpatch_space SET geom = ST_Force_3DZ(patch::geometry)
		
			
		SELECT sum(clippee.gid)
		FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, pc_in_db.clipping_pour_laser AS clippeur
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

	--On crée un index pour les patchs et un index pour leur représentation géométrique stockée en dur
		--pour les patchs : 274 sec
		CREATE INDEX acquisition_tmob_012013_riegl_pcpatch_space_patch_gist_2D ON acquisition_tmob_012013.riegl_pcpatch_space USING GIST (CAST(patch AS geometry));
		--pour leur env géométrique stockée en dur : 22sec
		CREATE INDEX acquisition_tmob_012013_riegl_pcpatch_space_geom_gist_2D ON acquisition_tmob_012013.riegl_pcpatch_space USING GIST (geom);

	--netttoyage après chargement des 50 riegl (table 7 Go) : 10 min , apres construction index : 64 sec
		VACUUM ANALYZE

	--test intersection sur une zone réduite de la taille d'un zigzag bus sur une largeur de rue :
		--d'abord des infos sur les patchs de cette zone : 1 033 302 / 1 / 2907 : en 4.6sec puis en 0.17sec
		SELECT sum(PC_NumPoints(patch)), min(PC_NumPoints(patch)), max(PC_NumPoints(patch))
		FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

		--On fait un test d'intersection et on écrit le résultat sur le disque 12sec , 8.5sec , taille du fichier : 90 Mo
		COPY (
			SELECT clippee.*
			FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
		) 
		TO '/tmp/output.sql.bin'
		--On fait le meme test mais avec intersection sur geom ecrite en dur ,et on écrit le résultat sur le disque , taille du fichier : 90 Mo
		COPY (
			SELECT clippee.*
			FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
			WHERE ST_Intersects(clippee.geom,clippeur.geom)=TRUE
		) 
		TO '/tmp/output.sql.bin'




--------
------
(----Piste pour amélioration : augmenter la couverture des indexes
	--on se crée une table d'intersection : 
	CREATE TABLE  acquisition_tmob_012013.zone_pour_intersection AS 
	(SELECT * 
	FROM pc_in_db.clipping_pour_laser)
	

	--verif table et zone de test : 
		SELECT count(*)
		FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
		WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
		LIMIT 100

	--Au début de l'experience : l'utilisation de l'un ou de l'autre index prend presque le même temps (facteur 2) :
		/* version avec index sur patch :
			"Nested Loop  (cost=0.00..35.54 rows=2 width=204) (actual time=1.490..226.745 rows=2590 loops=1)"
			"  Output: clippee.gid, clippee.geom, clippee.patch"
			"  ->  Seq Scan on pc_in_db.clipping_pour_laser clippeur  (cost=0.00..1.01 rows=1 width=120) (actual time=0.009..0.015 rows=1 loops=1)"
			"        Output: clippeur.gid, clippeur.id, clippeur.geom"
			"  ->  Index Scan using acquisition_tmob_012013_riegl_pcpatch_space_patch_gist_2d on acquisition_tmob_012013.riegl_pcpatch_space clippee  (cost=0.00..34.51 rows=2 width=204) (actual time=1.462..192.538 rows=2590 loops=1)"
			"        Output: clippee.gid, clippee.geom, clippee.patch"
			"        Index Cond: (st_geomfromewkb(pc_envelope(clippee.patch)) && clippeur.geom)"
			"        Filter: _st_intersects(st_geomfromewkb(pc_envelope(clippee.patch)), clippeur.geom)"
			"        Rows Removed by Filter: 606"
			"Total runtime: 239.791 ms"
		*/
		/*version avec index sur geom :
			"Nested Loop  (cost=0.00..35.43 rows=4348 width=204) (actual time=0.161..81.327 rows=2590 loops=1)"
			"  Output: clippee.gid, clippee.geom, clippee.patch"
			"  ->  Seq Scan on pc_in_db.clipping_pour_laser clippeur  (cost=0.00..1.01 rows=1 width=120) (actual time=0.007..0.012 rows=1 loops=1)"
			"        Output: clippeur.gid, clippeur.id, clippeur.geom"
			"  ->  Index Scan using acquisition_tmob_012013_riegl_pcpatch_space_geom_gist_2d on acquisition_tmob_012013.riegl_pcpatch_space clippee  (cost=0.00..34.40 rows=2 width=204) (actual time=0.135..55.082 rows=2590 loops=1)"
			"        Output: clippee.gid, clippee.geom, clippee.patch"
			"        Index Cond: (clippee.geom && clippeur.geom)"
			"        Filter: _st_intersects(clippee.geom, clippeur.geom)"
			"        Rows Removed by Filter: 606"
			"Total runtime: 93.980 ms"

		*/

		--On change le fill factor des indexes
		--on recupere le fimll factor actuel
		--IDEE ABANDONNEE : PAS DE GAIN DE PERFORMANCE A PREVOIR DANS NOTRE CAS
		--FILLFACTOR

)		
(----Piste pour amélioration : supprimer la compression dans les patch
	--on crée un nouveau schéma pour le riegl, non compressé
	--
				INSERT INTO pointcloud_formats (pcid, srid, nom_schema,schema) VALUES (4, 0, 'Riegl_nouvelle_acquisition_TMobilita_Janvier_2013_sans_compression' ,
			'<?xml version="1.0" encoding="UTF-8"?>
			<!-- Schéma du RIEGL nouvelle acquisiiton terra mobiltia Janvier 2013, version preuve de concept-->
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
			  
			  <!-- point dans repere local-->
			  <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>x_sensor : coorodnnée du point dans le repere du laser, du genre qq metres</pc:description>
			    <pc:name>x_sensor</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  <pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>y_sensor : coorodnnée du point dans le repere du laser, du genre qq metres</pc:description>
			    <pc:name>y_sensor</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>z_sensor : coorodnnée du point dans le repere du laser, du genre qq metres</pc:description>
			    <pc:name>z_sensor</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			  
			  <!-- origine du senseur dans repere local-->
			  <pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>x_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>x_origin_sensor</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>6</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>y_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>y_origin_sensor</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>7</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>z_origin_sensor : coorodnnée de la position du laser au moment de l acquisition dans le  point dans le repere du laser, du genre qq centimetre : decrit une hellicoide</pc:description>
			    <pc:name>z_origin_sensor</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.00001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 <!-- point dans repere Lambert 93 en metre (modulo transformation)-->
			 <pc:dimension>
			    <pc:position>8</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées X du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>649000</pc:offset>
			  </pc:dimension>
			   <pc:dimension>
			    <pc:position>9</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Y du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>6840000</pc:offset>
			  </pc:dimension>
				<pc:dimension>
			    <pc:position>10</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Z du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>z</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 
			 <!-- origine du senseur dans repere Lambert93 (modulo translation)-->
			 <pc:dimension>
			    <pc:position>11</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées X du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>649000</pc:offset>
			  </pc:dimension>
			<pc:dimension>
			    <pc:position>12</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Y du senseur dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>6840000</pc:offset>
			  </pc:dimension>
			<pc:dimension>
			    <pc:position>13</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Z du senseur dans le repere Lambert 93, en metre,</pc:description>
			    <pc:name>z_origin</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 
			 <!-- mesure geom-->
			   <pc:dimension>
			    <pc:position>14</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>Valeur du temps de vol lors de lacquisition. de env 2.25 a + de 400, probablement en milli. Il faudrait determiner le scale proprement</pc:description>
			    <pc:name>echo_range</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  <pc:dimension>
			    <pc:position>15</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>angle entre la direction d acquision et le plan horizontal, codeé entre -3 et +3 env. Il faudrait voir loffset</pc:description>
			    <pc:name>theta</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>16</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>un autre angle entre la direction d acquision et ???, codé enrte -0.005 et -0.004. Il faudrait regler loffset</pc:description>
			    <pc:name>phi</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.000001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			 
			  <!-- echo multiple-->

			    <pc:dimension>
			    <pc:position>17</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>le numero du retour dont ona tiré le point (entre 1 et 4)</pc:description>
			    <pc:name>num_echo</pc:name>
			    <pc:interpretation>int</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>18</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>le nombre d echos obtenu par le rayon quia  donné ce point </pc:description>
			    <pc:name>nb_of_echo</pc:name>
			    <pc:interpretation>int</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  
			    <!-- donnees avancee-->
			  <pc:dimension>
			    <pc:position>19</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>l amplitude de l onde de retour, attention : peut etre faux lors de retour multiples</pc:description>
			    <pc:name>amplitude</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			  <pc:dimension>
			    <pc:position>20</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>l amplitude de l onde de retour corrigee de la distance, attention : peut etre faux lors de retour multiples, attention : impropre pour classification, la corriger par formule trouveepar remi cura</pc:description>
			    <pc:name>reflectance</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>21</pc:position>
			    <pc:size>2</pc:size>
			    <pc:description>Une grandeur que je ne connais pas, entre -1 et plusieurs dizaine de milliers , par pas de 1</pc:description>
			    <pc:name>deviation</pc:name>
			    <pc:interpretation>int</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			    <pc:dimension>
			    <pc:position>22</pc:position>
			    <pc:size>1</pc:size>
			    <pc:description>Une grandeur que je ne connais pas, vaut toujours nan, on la stocke comme un entier</pc:description>
			    <pc:name>background_radiation</pc:name>
			    <pc:interpretation>int</pc:interpretation>
			    <pc:scale>1</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			  <pc:metadata>
			    <Metadata name="compression">none</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>');


			--On crée maintenant une table de test avec la compression desactivée
				--compression activée
				DROP TABLE IF EXISTS acquisition_tmob_012013.sous_ensemble_1m;
				CREATE TABLE acquisition_tmob_012013.sous_ensemble_1m AS ( 
					SELECT clippee.gid AS gid, clippee.patch AS patch
					FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
					WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
					)
				--compression desactivée
					DROP TABLE IF EXISTS acquisition_tmob_012013.sous_ensemble_1m_decompresse;
					CREATE TABLE acquisition_tmob_012013.sous_ensemble_1m_decompresse (
						gid SERIAL,
						patch PCPATCH(4)
					);
					--85 sec pour de la serialisation/deseralisation/reserailisation
					WITH to_insert AS (
						SELECT old_gid,PC_patch(point) AS patch
						FROM 
						(
							SELECT old_gid, PC_MakePoint(4, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float] ) AS point
							FROM  
							(
								SELECT old_gid, PC_get(point,'gps_time') AS gps_time,PC_get(point,'x_sensor')AS x_sensor,PC_get(point,'y_sensor') AS y_sensor,PC_get(point,'z_sensor') AS z_sensor,PC_get(point,'x_origin_sensor') AS x_origin_sensor,PC_get(point,'y_origin_sensor') AS y_origin_sensor,PC_get(point,'z_origin_sensor') AS z_origin_sensor,PC_get(point,'x') AS x,PC_get(point,'y') AS y,PC_get(point,'z') AS z,PC_get(point,'x_origin') AS x_origin,PC_get(point,'y_origin') AS y_origin,PC_get(point,'z_origin') AS z_origin,PC_get(point,'echo_range') AS echo_range,PC_get(point,'theta') AS theta,PC_get(point,'phi') AS phi,PC_get(point,'num_echo') AS num_echo,PC_get(point,'nb_of_echo') AS nb_of_echo,PC_get(point,'amplitude') AS amplitude,PC_get(point,'reflectance') AS reflectance,PC_get(point,'deviation') AS deviation,PC_get(point,'background_radiation') AS background_radiation
								FROM
								(
									SELECT old_gid, PC_Explode(patch) AS point
									 FROM 
									 (
										SELECT clippee.gid AS old_gid ,clippee.patch AS patch
										FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
										WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
									) AS toto
								) as tata
							)  AS table_point
						)AS toto
						GROUP BY old_gid
					)
					INSERT INTO acquisition_tmob_012013.sous_ensemble_1m_decompresse (gid,patch) SELECT to_insert.old_gid,to_insert.patch FROM to_insert;

				--difference de poid entre la version compressée/decompréssée :10+42 Mo / 9+58 Mo : +30%
				--

						
				--on test maintenant la vitesse des getX, getY, getZ, get Reflectance pour la version compressée et decompressée
				--temps pour ecrire X,Y,Z,reflectance sur disque : 14sec | 16sec, pour explain analyse : 34 sec | 35sec
					--test pour la version decrompressée : 13 sec
						COPY (
							SELECT PC_Get(point,'x') AS x,PC_Get(point,'y') AS y,PC_Get(point,'z') AS z,PC_Get(point,'reflectance') AS reflectance 
							FROM
							(
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m_decompresse
							) as tata
						) 
						TO '/tmp/output.sql.bin'

						--pour la version compresséee : 16 sec
						COPY (
							SELECT PC_Get(point,'x') AS x,PC_Get(point,'y') AS y,PC_Get(point,'z') AS z,PC_Get(point,'reflectance') AS reflectance 
							FROM
							(
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m
							) as tata
						) 
						TO '/tmp/output.sql.bin'


					--temps pour disque juste patch 21sec 210Mo | 9sec 95 Mo : explain analyse juste patch : 0.1sec | 0.1sec  
						COPY (
						SELECT patch
						FROM
							(
								SELECT patch AS patch
								 FROM acquisition_tmob_012013.sous_ensemble_1m_decompresse
							) as tata
						) 
						TO '/tmp/output.sql.bin'

						--pour la version compresséee : 16 sec
						COPY (
						SELECT patch
						FROM
						(
							SELECT patch AS patch
							 FROM acquisition_tmob_012013.sous_ensemble_1m
						) as tata
						) 
						TO '/tmp/output.sql.bin'

						
)
				/* Test for PRamsey :
				_find which patchs are overlapping (5k over 700k) : 0.2 ms
				
				_write patches to disk : sec , Mo
					COPY (
							SELECT patch AS patch
							 FROM acquisition_tmob_012013.sous_ensemble_1m

						) 
					TO '/tmp/output.sql.bin'
				_use PC_Explode and Explain analyse / write points to disk : sec / sec Mo 
					COPY (
							SELECT point 
							FROM
							(
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m
							) as tata
						) 
						TO '/tmp/output.sql.bin'
						COPY (

	
							WITH tata AS (
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m
							)
							SELECT point::geometry, PC_Get(point,'reflectance')
							FROM tata
							) 
						TO '/tmp/output.sql.bin'
				_use PC_Get(x,y,z,intensity) and Explain Analyze / write to disk : sec, sec  Mo



				On uncompressed patches
				_same
				_write patches to disk : 9 sec , 95 Mo
					COPY (
							SELECT patch AS patch
							 FROM acquisition_tmob_012013.sous_ensemble_1m_decompresse

						) 
					TO '/tmp/output.sql.bin'
				_use PC_Explode and Explain analyse / write points to disk : 14 sec / 27 sec 220 Mo 
					COPY (
							SELECT point 
							FROM
							(
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m_decompresse
							) as tata
						) 
						TO '/tmp/output.sql.bin'
				_use PC_Explode and PC_Get(x,y,z,intensity) and Explain Analyze / write to disk : 37 sec, 16 sec 66 Mo
					COPY (
							SELECT PC_get(point,'x'), pc_get(point,'y'),PC_get(point,'z'),pc_get(point,'reflectance' )
							FROM
							(
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m_decompresse
							) as tata
						) 
						TO '/tmp/output.sql.bin'
				
				_use PC_Explode and point::geometry+Pc_Get(intensity) and Explain Analyze / write to disk : 32 sec, 13.4 sec 77 Mo
					COPY (
							SELECT point::geometry, PC_Get(point,'reflectance')
							FROM
							(
								SELECT PC_Explode(patch) AS point
								 FROM acquisition_tmob_012013.sous_ensemble_1m_decompresse
							) as tata
						) 
						TO '/tmp/output.sql.bin'
				*/
			

)
(--Piste pour amélioration : suppression compression dans table toast
	--On crée une table avec la meme architecture que la table principale, mais on change la propriété des toast pour qu'ils ne soient pas compressées
		--suppresion/creation de la table
		DROP TABLE IF EXISTS acquisition_tmob_012013.sous_ensemble_1m_decomptoast;
		CREATE TABLE acquisition_tmob_012013.sous_ensemble_1m_decomptoast AS ( 
			SELECT clippee.gid AS gid, clippee.patch AS patch
			FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
			)
		--changement de la tehcnique de stockage pour ne plus compresser les toast
		ALTER TABLE acquisition_tmob_012013.sous_ensemble_1m_decomptoast ALTER COLUMN patch SET STORAGE EXTERNAL;
		VACUUM FULL acquisition_tmob_012013.sous_ensemble_1m_decomptoast;
		VACUUM ANALYZE acquisition_tmob_012013.sous_ensemble_1m_decomptoast;
	--différence de la taille de la table : normal : 10+42Mo // decompresse : 2+50 Mo
	--différence du temps d'accès pour ecriture sur le disque
		--on ecrit la table normal sur le disque : 9 sec , 
			COPY (
				SELECT patch
				FROM acquisition_tmob_012013.sous_ensemble_1m
			) 
			TO '/tmp/output.sql.bin'
		--on écrit la table sans compression toast sur le disque : 9sec
			COPY (
				SELECT patch
				FROM acquisition_tmob_012013.sous_ensemble_1m_decomptoast
			) 
			TO '/tmp/output.sql.bin'
	--différence du temps pour utiliser PC_Explode dessus
		--normal : 11sec
		COPY (
			SELECT point::geometry, PC_Get(point,'reflectance')
			FROM
			(
				SELECT PC_Explode(patch) AS point
				 FROM acquisition_tmob_012013.sous_ensemble_1m
			) as tata
		) 
		TO '/tmp/output.sql.bin'
		--toast decompresse : pareil
		COPY (
			SELECT point::geometry, PC_Get(point,'reflectance')
			FROM
			(
				SELECT PC_Explode(patch) AS point
				 FROM acquisition_tmob_012013.sous_ensemble_1m_decomptoast
			) as tata
		) 
		TO '/tmp/output.sql.bin'
	----
	--Conclusion : 
	--desactiver la compression toast ne parait pas accelerer les choses
	----
	
(--piste pour amélioration : ne pas (trop) utiliser les tables toasts
	--créer une table avec les patch pour un millions de points regroupées par paquets spatiaux de 0.5m*0.5m*0.5m
		--suppression/creation_de_la_table
		DROP TABLE IF EXISTS acquisition_tmob_012013.sous_ensemble_1m_fewtoast;
		CREATE TABLE acquisition_tmob_012013.sous_ensemble_1m_fewtoast ( 
			gid bigint,
			patch PCPATCH(2));
		--remplissage
		WITH to_insert AS (
			SELECT PC_patch(point) AS patch
			FROM 
			(
				SELECT old_gid, PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float] ) AS point
				FROM  
				(
					SELECT old_gid, PC_get(point,'gps_time') AS gps_time,PC_get(point,'x_sensor')AS x_sensor,PC_get(point,'y_sensor') AS y_sensor,PC_get(point,'z_sensor') AS z_sensor,PC_get(point,'x_origin_sensor') AS x_origin_sensor,PC_get(point,'y_origin_sensor') AS y_origin_sensor,PC_get(point,'z_origin_sensor') AS z_origin_sensor,PC_get(point,'x') AS x,PC_get(point,'y') AS y,PC_get(point,'z') AS z,PC_get(point,'x_origin') AS x_origin,PC_get(point,'y_origin') AS y_origin,PC_get(point,'z_origin') AS z_origin,PC_get(point,'echo_range') AS echo_range,PC_get(point,'theta') AS theta,PC_get(point,'phi') AS phi,PC_get(point,'num_echo') AS num_echo,PC_get(point,'nb_of_echo') AS nb_of_echo,PC_get(point,'amplitude') AS amplitude,PC_get(point,'reflectance') AS reflectance,PC_get(point,'deviation') AS deviation,PC_get(point,'background_radiation') AS background_radiation
					FROM
					(
						SELECT old_gid, PC_Explode(patch) AS point
						 FROM 
						 (
							SELECT clippee.gid AS old_gid ,clippee.patch AS patch
							FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
							WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
						) AS toto
					) as tata
				)  AS table_point
			)AS toto
			GROUP BY 0.5*ROUND(2*ST_X(point::geometry)),0.5*ROUND(2*ST_Y(point::geometry)),0.5*ROUND(2*ST_Z(point::geometry))
		)
		INSERT INTO acquisition_tmob_012013.sous_ensemble_1m_fewtoast (patch) SELECT to_insert.patch FROM to_insert;
	--stats : 19970  1090498  1  54.6068102153229845  937
		SELECT count(*),sum(PC_Numpoints(patch)) as points_total ,min(PC_Numpoints(patch)) as min, avg(PC_Numpoints(patch)) as avg, max(PC_Numpoints(patch)) as max
		FROM acquisition_tmob_012013.sous_ensemble_1m_fewtoast
	--poid table TOAST : normal : 10+42Mo, avec patchs plus petits : 30+27Mo

	-- test d'ecriture normal : 9sec 95 MO, test d ecriture fewtoast : 10.4sec , 107Mo
			COPY (
				SELECT patch
				FROM acquisition_tmob_012013.sous_ensemble_1m_fewtoast
			) 
			TO '/tmp/output.sql.bin' 
		
	-- test avec pc explode : normal : 10.5 sc , 58 Mo  , avec peu de toast : 17.9sec, 58sec
		DROP TABLE IF EXISTS temp;
		CREATE TABLE temp AS (
			SELECT point::geometry, PC_Get(point,'reflectance')
			FROM
			(
				SELECT PC_Explode(patch) AS point
				 FROM acquisition_tmob_012013.sous_ensemble_1m_fewtoast
			) as tata
		) 
		TO '/tmp/output.sql.bin' WITH BINARY

-----
--CONCLUSIONS
--ça n'émaliore rien du tout, c'est même plutôt plus long à écrire.
-----
)

(--piste pour amélioration : ne pas utiliser (du tout) les tables toasts
	--créer une table avec les patch pour un millions de points regroupées par paquets spatiaux de 0.5m*0.5m*0.5m
		--suppression/creation_de_la_table
		DROP TABLE IF EXISTS acquisition_tmob_012013.sous_ensemble_1m_notoast;
		CREATE TABLE acquisition_tmob_012013.sous_ensemble_1m_notoast ( 
			gid bigint,
			patch PCPATCH(2));
		--remplissage
		WITH to_insert AS (

			SELECT PC_Patch(point) AS patch
			FROM
			(	
				SELECT point AS point, row_number(*) OVER ( ORDER BY gps_time) num_row
				FROM 
				(
					SELECT old_gid, gps_time as gps_time, PC_MakePoint(2, ARRAY[gps_time,x_sensor,y_sensor,z_sensor,x_origin_sensor,y_origin_sensor,z_origin_sensor,x,y,z,x_origin,y_origin,z_origin,echo_range,theta,phi,num_echo,nb_of_echo,amplitude,reflectance,deviation,background_radiation::float] ) AS point
					FROM  
					(
						SELECT old_gid, PC_get(point,'gps_time') AS gps_time,PC_get(point,'x_sensor')AS x_sensor,PC_get(point,'y_sensor') AS y_sensor,PC_get(point,'z_sensor') AS z_sensor,PC_get(point,'x_origin_sensor') AS x_origin_sensor,PC_get(point,'y_origin_sensor') AS y_origin_sensor,PC_get(point,'z_origin_sensor') AS z_origin_sensor,PC_get(point,'x') AS x,PC_get(point,'y') AS y,PC_get(point,'z') AS z,PC_get(point,'x_origin') AS x_origin,PC_get(point,'y_origin') AS y_origin,PC_get(point,'z_origin') AS z_origin,PC_get(point,'echo_range') AS echo_range,PC_get(point,'theta') AS theta,PC_get(point,'phi') AS phi,PC_get(point,'num_echo') AS num_echo,PC_get(point,'nb_of_echo') AS nb_of_echo,PC_get(point,'amplitude') AS amplitude,PC_get(point,'reflectance') AS reflectance,PC_get(point,'deviation') AS deviation,PC_get(point,'background_radiation') AS background_radiation
						FROM
						(
							SELECT old_gid, PC_Explode(patch) AS point
							 FROM 
							 (
								SELECT clippee.gid AS old_gid ,clippee.patch AS patch
								FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
								WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
							) AS toto
						) as tata
					)  AS table_point
				)AS toto
			) as titi
			GROUP BY ROUND(num_row/100)
		)
		INSERT INTO acquisition_tmob_012013.sous_ensemble_1m_notoast (patch) SELECT to_insert.patch FROM to_insert;

		

		
	--stats : 10905  1090498   99   99.9998165978908757   100
		SELECT count(*),sum(PC_Numpoints(patch)) as points_total ,min(PC_Numpoints(patch)) as min, avg(PC_Numpoints(patch)) as avg, max(PC_Numpoints(patch)) as max
		FROM acquisition_tmob_012013.sous_ensemble_1m_notoast
	--poid table TOAST : normal : 10+42Mo, avec patchs plus petits : 84 + 8Mo

	-- test d'ecriture normal : 9sec 95 MO, test d ecriture fewtoast : 10.4sec , 103Mo
			COPY (
				SELECT patch
				FROM acquisition_tmob_012013.sous_ensemble_1m_notoast
			) 
			TO '/tmp/output.sql.bin' 
		
	-- test avec pc explode : normal : 10.5 sc , 58 Mo  , sans toast : 14.4.9sec, 58Mo
	-- avec table : normal :  12.8sec , no toast ; 14.5sec, 
		DROP TABLE IF EXISTS temp;
		CREATE TABLE temp AS (
			SELECT point::geometry, PC_Get(point,'reflectance')
			FROM
			(
				SELECT PC_Explode(patch) AS point
				 FROM acquisition_tmob_012013.sous_ensemble_1m
			) as tata
		) 
		TO '/tmp/output.sql.bin' WITH BINARY


		COPY (
		SELECT point::geometry, PC_Get(point,'reflectance')
			FROM
			(
				SELECT PC_Explode(patch) AS point
				 FROM acquisition_tmob_012013.sous_ensemble_1m_notoast
			) as tata
		) 
		TO '/tmp/output.sql.bin' WITH BINARY
-----
--CONCLUSIONS
--avoir plus de ligne vs voir des toast, ils vaut mieux avoir des toasts !
-----
)


(--piste pour amélioration : sortir seulement un point par patch

	SELECT DISTINCT ON (customer)
j       id, customer, total
	FROM   purchases
	ORDER  BY customer, total DESC, id

	SELECT * FROM table_name WHERE MOD(some_id,5) = 0 ORDER BY some_id LIMIT 25;
	--requete pour récupérer un seul point par patch
	SELECT DISTINCT ON (gid) 
	PC_Explode(patch) 
	FROM 	(
		SELECT *
		FROM acquisition_tmob_012013.sous_ensemble_1m
		) as the_patches
 
		
)

(--piste pour amélioration : curseur SQL pour limiter l'utilisation mémoire et récupérer les requetes avant la fin

	--note : lancer avec F6
	BEGIN TRANSACTION; --obligé de faire une transaction car le curseur n'a pas été déclaré comme constant
	--curseur pour tous les points
	DECLARE name_of_cursor NO SCROLL CURSOR FOR
	 (
		SELECT point::geometry, PC_Get(point,'reflectance')
			FROM
			(
				SELECT PC_Explode(patch) AS point
				 FROM acquisition_tmob_012013.sous_ensemble_1m
			) as tata
	 );

	--on recupere 10 points tous les 20 points avec fetch
	DECLARE @I,@T;
	SET @T = 0 ;
	WHILE ( 1 )
	BEGIN
		SET @T = @T + 1;
		SET @I = FETCH RELATIVE 10000 name_of_cursor;
		--PRINT @T;
		--PRINT @I;
		IF NOT(@I)
			BREAK;
	END
	
	 --fermeture du cursor
	 CLOSE name_of_cursor;
	 --fin de la transaction 
	 END TRANSACTION;


DECLARE @I, @T; -- Variable names begin with a @
SET @I = 0; -- @I is an integer
WHILE @I &lt; 20
BEGIN
   SET @T = 'table' + CAST (@I AS STRING); -- Casts @I
   PRINT @T;
   SET @I = @I + 1;
END

----
--CONCLUSION
--il est possible de récupérere un point sur N mais ce n'est pas efficace car on parcours tous les points.
--mieux vaudrait créer un point à partir de la géométrie de la boite englobante par ex.
----
)

(--Piste pour amélioration : diminuer le nombre de transaction : patch simplifiés

	--creer un schema simplifie
		INSERT INTO pointcloud_formats (pcid, srid, nom_schema,schema) VALUES (5, 0, 'Riegl_nouvelle_acquisition_TMobilita_Janvier_2013_simplifie' ,
			'<?xml version="1.0" encoding="UTF-8"?>
			<!-- Schéma du RIEGL nouvelle acquisiiton terra mobiltia Janvier 2013, version preuve de concept-->
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
			  
			 
			 <!-- point dans repere Lambert 93 en metre (modulo transformation)-->
			 <pc:dimension>
			    <pc:position>2</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées X du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>x</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>649000</pc:offset>
			  </pc:dimension>
			   <pc:dimension>
			    <pc:position>3</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Y du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>y</pc:name>
			    <pc:interpretation>double</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>6840000</pc:offset>
			  </pc:dimension>
				<pc:dimension>
			    <pc:position>4</pc:position>
			    <pc:size>5</pc:size>
			    <pc:description>Coordonnées Z du point dans le repere Lambert 93, en metre, attention a l offset</pc:description>
			    <pc:name>z</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>
			 
			 
			  <pc:dimension>
			    <pc:position>5</pc:position>
			    <pc:size>4</pc:size>
			    <pc:description>l amplitude de l onde de retour corrigee de la distance, attention : peut etre faux lors de retour multiples, attention : impropre pour classification, la corriger par formule trouveepar remi cura</pc:description>
			    <pc:name>reflectance</pc:name>
			    <pc:interpretation>float</pc:interpretation>
			    <pc:scale>0.0001</pc:scale>
				<pc:offset>0</pc:offset>
			  </pc:dimension>

			  <pc:metadata>
			    <Metadata name="compression">dimensional</Metadata>
			  </pc:metadata>
			</pc:PointCloudSchema>');

	--créer une table avec schéma simplifié
			DROP TABLE IF EXISTS acquisition_tmob_012013.sous_ensemble_1m_simplifie;
			CREATE TABLE  acquisition_tmob_012013.sous_ensemble_1m_simplifie (
				gid SERIAL,
				patch PCPATCH(5)
			);
	
	(--remplir cette table
			WITH to_insert AS (
				SELECT old_gid,PC_patch(point) AS patch
				FROM 
				(
					SELECT old_gid, PC_MakePoint(5, ARRAY[gps_time,x,y,z,reflectance] ) AS point
					FROM  
					(
						SELECT old_gid, PC_get(point,'gps_time') AS gps_time,PC_get(point,'x') AS x,PC_get(point,'y') AS y,PC_get(point,'z') AS z,PC_get(point,'reflectance') AS reflectance
						FROM
						(
							SELECT old_gid, PC_Explode(patch) AS point
							 FROM 
							 (
								SELECT clippee.gid AS old_gid ,clippee.patch AS patch
								FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
								WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
							) AS toto
						) as tata
					)  AS table_point
				)AS toto
				GROUP BY old_gid
			)
			INSERT INTO acquisition_tmob_012013.sous_ensemble_1m_simplifie (gid,patch) SELECT to_insert.old_gid,to_insert.patch FROM to_insert;
			)

			
	--différence de poids : table simplifié : 7+9.5 Mo , table normal 10+42 Mo, table normal sans compression dans schema : 9+58 Mo
	--temps d'ecriture sur disque et taille du patch simplifié
		--ecriture du patch normal : 9 sec, 95 Mo
		COPY (
				SELECT patch AS patch
				 FROM acquisition_tmob_012013.sous_ensemble_1m
			) 
		TO '/tmp/output.sql.bin'
		--ecriture du patch simplifié 3 sec, 30 Mo
		COPY (
				SELECT PC_Uncompress(patch) AS patch
				 FROM acquisition_tmob_012013.sous_ensemble_1m_simplifie
			) 
		TO '/tmp/output.sql.bin'
	----
	--Conclusion
	--c'est bcp plus petit à transmettre (30 Mo)
	--actuellemment c'est très long à calculer car le passage patch->patch se fait par passage par les points : une catastrophe
	--il faudrait une fonction patch_to_patch qui garde les variables communes et mets des zeros ailleurs
	--ça ne risque pas de voir le jour
	----
	
)
(--Piste amélioration : index temporel

		CREATE INDEX acquisition_tmob_012013_riegl_pcpatch_space_patch_gist_range_gps_time
			ON acquisition_tmob_012013.riegl_pcpatch_space
			USING GIST ( poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time'));
)
(--piste amélioration : multipoints / float[]

		--On crée une table de multipoint a la place des patch, avec un tableau de float pour la reflectance
		DROP TABLE IF EXISTS acquisition_tmob_012013.riegl_multipoint 
		CREATE TABLE acquisition_tmob_012013.riegl_multipoint AS 
		(
		SELECT gid, ST_Collect(point::geometry) AS geom, array_agg(PC_Get(point,'reflectance')) as reflectances
			FROM 
			(	SELECT clippee.gid, PC_Explode(clippee.patch) AS point
				FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
				WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE
			) as toto
			GROUP BY gid
		)
		
		--On ecrit ces multipoints  sur le disque
			COPY (
				SELECT (point).geom, reflectance 
				FROM
				(
					SELECT ST_Dump(geom) AS point, unnest(reflectances) as reflectance
					 FROM acquisition_tmob_012013.riegl_multipoint
				) as tata
			) 
			TO '/tmp/output.sql.bin'
)	
(--piste pour amélioration : geometrie des patch dans une table séparée

(--piste pour amélioration : on diminue le nombre de patch avec un seul point en les regroupant par patch de 5m3
	--On fait le constat que plus de 100k patches ne contiennent qu'un seul point (sur 700k)
	--On essaye d'améliorer ceci en regroupant les patch par 5m3
	-- ou  : on regroupe les patches les plus petits aux plus gros plus proches

	--Requete pour regrouper les patchs par X m3  : temps de création : 384 secs pour 10 m3,  378 sec pour 5m3
		DROP TABLE IF EXISTS acquisition_tmob_012013.riegl_Xm3;
		CREATE TABLE acquisition_tmob_012013.riegl_Xm3 AS (
			SELECT min(gid) AS gid ,PC_Union(patch) AS patch
				FROM (
					SELECT *
					FROM acquisition_tmob_012013.riegl_pcpatch_space
					WHERE PC_NumPoints(patch)<=2
				) as patchs_petits
			GROUP BY ST_SnapToGrid(ST_Centroid(ST_MakeValid(patch::geometry)),5)
		);
	--On regarde la tete de cette table
		--a quoi ca ressemble
		SELECT * 
		FROM acquisition_tmob_012013.riegl_Xm3
		LIMIT 100

		--quelques stats : pour cube de 10 metres, on passe de 115k patches de 1 points à 4k patches, dont 1.8% de 1 points
		--stats : pour un cube de 5 m3 : on passes de 115k patches avec 1 points à 9.5k patches , dont 2.5% de patches à 1 points  :::: 9688  1  108  8.23
		--on essaye des cube de 5m3 mais on ne prend plus que les  patchs avec un seul points, on prend aussi les patch avec plus de points 10637;1;331;19.3680549026981292
		SELECT count(*) AS nbre_patch_apres, min(PC_NumPoints(patch)) AS min_points_par_patch,max(PC_NumPoints(patch)) AS max_points_par_patch, avg(PC_NumPoints(patch)) AS moyenne_points_par_patch
		FROM acquisition_tmob_012013.riegl_Xm3 as Xm3

		SELECT 1000*2425/9600

		SELECT count(*) 
		FROM acquisition_tmob_012013.riegl_Xm3 as Xm3
		WHERE PC_NumPoints(patch)<=1
		
		SELECT count(*) AS nombre_ancien_patch_1_points
		FROM acquisition_tmob_012013.riegl_only_geom_pcpatch_space AS rps
		WHERE time_range = 'empty'

		--En fait il serait intéressant d'analyser la distribution du nombre de points par patch :
		--une estimation théorique donne un maximum de 20k points par m3, au pire,
			--on crée un index pour accélerer les requetes sur le nombre de points : 430 sec
			CREATE INDEX acquisition_tmob_012013_riegl_pcpatch_space_patch_gist_numpoints
			ON acquisition_tmob_012013.riegl_pcpatch_space
			USING BTREE ( PC_NumPoints(patch));
			VACUUM ANALYZE acquisition_tmob_012013.riegl_pcpatch_space;

			--On regarde le nombre de patch qui ont moins de 1 , 2 ,5 ,10 ,15, 50 100 pts, et ceux qui ont plus de 20k points
			--resultats : 1/patch : 80k, 2/patch : 140k , 5 : 240k

			SELECT count(*)
			FROM acquisition_tmob_012013.riegl_pcpatch_space
			WHERE PC_NumPoints(patch) >=3000
)

	--On crée une table avec la géométrie séparée
		CREATE TABLE acquisition_tmob_012013.riegl_only_geom_pcpatch_space 
		AS (
			SELECT gid, patch::geometry AS geom, poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time') AS time_range
			FROM acquisition_tmob_012013.riegl_pcpatch_space
		) LIMIT 1
		
		INSERT INTO acquisition_tmob_012013.riegl_only_geom_pcpatch_space 
			SELECT clippee.gid, patch::geometry AS geom, poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time') AS time_range
			FROM acquisition_tmob_012013.riegl_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
			WHERE ST_Intersects(clippee.patch::geometry,clippeur.geom)=TRUE

			SELECT ST_AsText(geom)
			FROM acquisition_tmob_012013.riegl_only_geom_pcpatch_space
			LIMIT 100

	--on crée un index spatial
		CREATE INDEX acquisition_tmob_012013_riegl_only_geom_pcpatch_space_geom_gist_2D ON acquisition_tmob_012013.riegl_only_geom_pcpatch_space USING GIST (geom);
	--on effectue la meme requete d intersection qu'avec la table avec les vrai patch
)













(--piste d'amélioration : test sur une table contenant les boites englobantes et l'intervale de temps

	--création de la table :
		DROP TABLE IF EXISTS acquisition_tmob_012013.riegl_only_geom_pcpatch_space ;
		CREATE TABLE acquisition_tmob_012013.riegl_only_geom_pcpatch_space 
			AS (
				SELECT gid, patch::geometry AS geom, poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time') AS time_range
				FROM acquisition_tmob_012013.riegl_pcpatch_space
			) LIMIT 0;
	--nbr de lignes de la table :
		SELECT count(*)
		FROM acquisition_tmob_012013.riegl_only_geom_pcpatch_space
	

	-- remplissage de la table :
		INSERT INTO acquisition_tmob_012013.riegl_only_geom_pcpatch_space 
			SELECT gid, patch::geometry AS geom, poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time') AS time_range
			FROM acquisition_tmob_012013.riegl_pcpatch_space;

	--analyse de la table
		VACUUM ANALYZE acquisition_tmob_012013.riegl_only_geom_pcpatch_space 

	--test d'intersection spatial : equivlaence en temporel: 
		SELECT NUMRANGE(min(lower(clippee.time_range)),max(upper((clippee.time_range))))
		FROM acquisition_tmob_012013.riegl_only_geom_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
		WHERE ST_Intersects(clippee.geom,clippeur.geom)=TRUE
		LIMIT 1
	--test d'intersection temporel
		SELECT count(*)
		FROM acquisition_tmob_012013.riegl_only_geom_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
		WHERE clippee.time_range <@ NUMRANGE(54176.0754521,54182.0878481088) AND clippee.time_range != 'empty'
		SELECT clippee.gid, time_range
		FROM acquisition_tmob_012013.riegl_only_geom_pcpatch_space AS clippee, acquisition_tmob_012013.zone_pour_intersection AS clippeur
		WHERE ST_Intersects(clippee.geom,clippeur.geom)=TRUE
		ORDER BY time_range

	--probleme : un tas de patch avec un seul point dedans, ce qui fausse le filtrage sur time_range
		--il faut rajouter une clause pour ne pas prendre les patchs avec un seul point
			--On mesure le nombre de patches avec un seul point
			SELECT count(*)
			FROM  acquisition_tmob_012013.riegl_pcpatch_space as source 
			WHERE PC_NumPoints(source.patch) = 1
			--on va créer à postriori des patch de 5m3 pour les points qui sont seuls dans des patchs de 1m3
			--Ou : on ajoute les points seuls aux patch le plus proche
			--idée d'algo : prendre l'ensemble des patchs avec 1 points, ppour chacun le fusionner avec le patch le plus proche
			--itérer tant qu'il n'y a pas au moins 10 points par patch
		--en effet lors de la création on a oublié de spécifié l'option pour inclure les deux extremité : ce qui crée des segments vide : on corrige la fonction, et on met à jour la table
		--on reecrit les range pour quand il n'y a qu'un point
		UPDATE acquisition_tmob_012013.riegl_only_geom_pcpatch_space as cible SET time_range = poc_pc_in_db.rc_compute_range_for_a_patch(source.patch,'gps_time')
			FROM  acquisition_tmob_012013.riegl_pcpatch_space as source 
			WHERE PC_NumPoints(source.patch) = 1
		--On met à jour les autres en incluant la borne sup
		UPDATE acquisition_tmob_012013.riegl_only_geom_pcpatch_space as cible SET time_range = NUMRANGE(time_range,'[]')
			WHERE PC_NumPoints(source.patch) != 1
		
		--test sur les points solitaire dans les patches
		
		--On pourrait fusionner les patchs qui sont proches spatiallement et qui ont moins de 10 points par ex.
		--Prendre un point et trouver son plus proche voisin: 
		--on peut aussi les virer, ou les regrouper spatialement par 10m3
		
	--creation d'indexes
	
		--requetes a lancer avant de partir
		--Créer une table avec la géometrie des bbox des points et le time range pour test indépendant de table toast:
		INSERT INTO acquisition_tmob_012013.riegl_only_geom_pcpatch_space 
			SELECT gid, patch::geometry AS geom, poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time') AS time_range
			FROM acquisition_tmob_012013.riegl_pcpatch_space;
			 
		--creation d'un index temporel sur la table principale
		CREATE INDEX acquisition_tmob_012013_riegl_pcpatch_space_patch_gist_range_gps_time
			ON acquisition_tmob_012013.riegl_pcpatch_space
			USING GIST ( poc_pc_in_db.rc_compute_range_for_a_patch(patch,'gps_time'));

		--création d'un index spatial et temporel sur la table avec juste la géométrie proxy
		CREATE INDEX acquisition_tmob_012013_riegl_only_geom_pcpatch_space_geom_gist_2D ON acquisition_tmob_012013.riegl_only_geom_pcpatch_space USING GIST (geom);
		CREATE INDEX acquisition_tmob_012013_riegl_only_geom_pcpatch_space_gist_time_range
			ON acquisition_tmob_012013.riegl_only_geom_pcpatch_space
			USING GIST ( time_range);	
			