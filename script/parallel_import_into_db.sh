#!/bin/bash

#Script by Rémi C
#Thales/IGN 13/06/2013
#Prototype for massive point cloud storage into data base

#This script load all the points in ply files inside the given folder.
#depends on other script



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



#########
#NOTE : your linux sessions either need to be known by postgres (i.e you have a role with suficient permission or you need ot switch to postgres ("su postgres"))
#########

#Variables : NEED TO BE TWEAKED

	#point type : default : "Riegl_nouvelle_acquisition_TMobilita_Janvier_2013"
		declare pointschema="Riegl_Benchmark_IGN";
	#Input data folder : default : "../data/riegl"
		declare datafolder="../data/riegl";	
	#name of the table where to write patches, schema qualified. Default : "acquisition_tmob_012013.riegl_pcpatch_space"
		declare patchtable="benchmark.riegl_pcpatch_space";
	#number of parallel import: carefull, we need one cpu for parsing ply file and one cpu for psql instance, so this parameter should be at max : number_of_CPU/2
		declare -i jobnumber=1;
	#name of the script to load one file into temporary table : default : "./utils/one_file_import_into_db.sh"
		declare scriptplytotemporary="./utils/one_file_import_into_db.sh";
	#name of the programm converting binary ply to ascii csv (separator = whitespace) , default : "./RPly_Ubuntu/bin/RPly_convert"
		declare programmplytoascii="../RPly_Ubuntu/bin/RPly_convert";	
	#command to connect to the database: default "psql -d test_pointcloud -p 5432" 
		#Warning : do not ad -h, or postgres will connect using TCP (thus needing a password)
		declare psql_commande="psql -d conf_postgres -p 5433";

	
#UI
	echo "Hello, you are going to try to import all the point respecting the 
░▒▓"$pointschema"▓▒░ schema from the 
░▒▓"$datafolder"▓▒░ data folder to the  
░▒▓"$patchtable"▓▒░ patch table , using 
░▒▓"$jobnumber"▓▒░ parallel processe(s) . 
The script 
░▒▓"$scriptplytotemporary"▓▒░ will load data into temp table using the 
░▒▓"$programmplytoascii"▓▒░ programm to convert from binary ply to ascii ply without header. You will connect to the database using the command : 
░▒▓"$psql_commande"▓▒░

Note: patch will be inserted regardless of duplicate"

read -p "please type 'y' to go on, or 'n' to abort (y/n)" ans
if [ $ans = n -o $ans = N -o $ans = no -o $ans = No -o $ans = NO ]
then
echo "Exiting"
exit 0;
fi 

#loop to launch as many process as indicated by jobnumber
	for ((i = 0 ; i < $jobnumber ; i++ )); 
	do #loop on jobnumber 
		#launching import for every ply file in datafolder where file_number modulo jobnumber = i
		./utils/sequential_import_into_db.sh \
			"$pointschema" \
			"$datafolder" \
			"$patchtable" \
			"$jobnumber"_"$i" \
			"$scriptplytotemporary" \
			"$programmplytoascii" \
			"$psql_commande"
	done #end of loop on job number
exit 0;



