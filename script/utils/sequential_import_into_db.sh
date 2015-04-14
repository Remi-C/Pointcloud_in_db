#!/bin/bash

#Rémi-C Thales/IGn 17/06/2013
#Prototype about loading pointcloud data into a database
#This script load data into a database (single thread)
#It should be called by the "parallel_import_into_db.sh" script



#	Copyright 2013 Rémi C, IGN THALES 
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU Lesser General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU Lesser General Public License for more details.
#	You should have received a copy of the GNU Lesser General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.



usage="
############################
#INPUTS
############################
#1 : kind of point schema, currently only 'Riegl_nouvelle_acquisition_TMobilita_Janvier_2013' and 'Velo_nouvelle_acquisition_TMobilita_Janvier_2013' are authorized.
#2 : Name of the .ply data folder
#3 : name of the patch table where the final patch are going to be stored
#4 : N_M : this script load the file number f if  f%N =M  (% is modulo)
#5 : Name of the script loading one ply file into database
#6 : Name of the programm converting binary ply to ascii ply (without header)
#7 : The command to connect to postgres via psql, it should be quoted
############################
";
#echo "inputs: "
#echo "1st arg : kind of point schema:  $1
#	currently only 'Riegl_nouvelle_acquisition_TMobilita_Janvier_2013' and 'Velo_nouvelle_acquisition_TMobilita_Janvier_2013' are authorized.
#echo "2nd arg : Name of the .ply data folder:  $2";
#echo "3d arg : name of the patch table where the final patch are going to be stored : $3";
#echo "4th arg : N_M : this script load the file number f if  f%N =M  (% is modulo):  $4";
#echo "5th arg : Name of the script loading one ply file into database : $5";
#echo "6th arg : Name of the programm converting binary ply to ascii ply (without header) : $6";
#echo "7th arg : The command to connect to postgres via psql, it should be quoted : $7";



##Abstract of the script actions
#Check number of inputs
#Work on every 1 *.ply file every N in the data folder
#For each *.ply file
#	delete then create temp table
#	import points into temp table
#	create patch from temp table and insert theim into patch table
######################

##
#Input check
if [ $# -lt 7 ] ; #check if arg number is right, else print help about input
then
	echo -e "wrong number of arguments, use :  \n \n $usage \n\n" 
	exit 0;
fi

  
##
#Splitting the 4th arguments to 2 usable integers
declare -i unsurN=$(echo "$4" | cut -f1 -d_)
declare -i valeurModulo=$(echo "$4" | cut -f2 -d_)


##
#loop on every file in folder
##
	#Looking for every *.las in the folder and getting one on N
	declare -i boucle=0; #loop variable
	shopt -s nullglob;  #Safeguard to do nothing if the data folder is empty
	for f in $2/*_*.las
	do
		echo `date +"%T"` >> ./log_timings
		echo "boucle : $boucle";
		if (($boucle%$unsurN==$valeurModulo))
		then
		#case where we load the file
		echo "Loading $f in $3"; 
			
			if  [ "$1" = "lidar_airborn_vosges_2011" ] 
			then #the point is of type las
			#echo "point type las";
			
			
			##
			#Sdeleting then creating temporary table
				commande_sql="DROP TABLE IF EXISTS temp_las_$4_$boucle;
				CREATE TABLE temp_las_$4_$boucle (
				x double precision,
				y double precision,
				z double precision,
				gps_time double precision,
				intensity float,
				classification int,
				return_number int,
				tot_return_number int,
				pt_src_id int
				);";
				#echo "Deleting/creating temporary point table temp_las_$4_$boucle";
				$7 -c "$commande_sql";
			##	
			#importing points into temporary table
				#Using script to load points into temp table
				echo "Importing points from $f file into temporary table temp_las_$4_$boucle using script $5";

				$5 temp_las_$4_$boucle $f $6 "$7" ;
				
			
			##
			#Creating patches
				##Creating riegl patches
				echo "filling patch table $3 with spatial patch created from points from temp_las_$4_$boucle";
				commande_sql="
				WITH to_insert AS (
				SELECT PC_patch(point ORDER BY gps_time ASC) AS patch
				FROM (
					SELECT x,y,gps_time,
						PC_MakePoint(3,   
						ARRAY[ X,Y,Z,gps_time,intensity,  classification,return_number, tot_return_number,pt_src_id]) AS point
					FROM  temp_las_$4_$boucle AS pcr
					) table_point
				GROUP BY ROUND(x/50.0+0.5),ROUND(y/50.0+0.5)
				)
				INSERT INTO $3 (file_name,patch) SELECT '"$f"',to_insert.patch FROM to_insert;";
				
				$7 -c "$commande_sql";
				
				
			##
			#delete temporary table

				commande_sql="DROP TABLE IF EXISTS temp_las_$4_$boucle;"
				echo "the patch table $3 has been filled with patch based on points from $f, deleting the useless temp temp_"$1"_$4_$boucle  table";
				$7 -c "$commande_sql";
				
			else 
				echo "Not doing anything : you have to specify correctly the parameter 1 : "$1"";
			fi 	
		else
			#Not processing the file because of it's number 
			#echo "Not processing the $f file because of it's number ";
			echo "";
		fi 
		boucle=$boucle+1;
		echo `date +"%T"` >> ./log_timings
		
	done
exit 0








