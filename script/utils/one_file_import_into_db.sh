#!/bin/bash

#Rémi C Thales/IGN 13/06/2013
#Protoype to load pointclouds into a database


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
#1st : name of the postgres (schema_qualified) temporary table which will receive the points: Carefull : table columns must match point attributes
#2nd : Name of the ply binary file containing points
#3dd : Programm to convert from binary ply to ascii ply (wihtout header)
#4th : psql command to connect to the database
############################"


#
#echo "1st arg : name of the postgres (schema_qualified) temporary table which will receive the points: Carefull : table columns must match point attributes :  $1";
#echo "2nd arg : Name of the ply binary file containing points :  $2";
#echo "3dd arg : Programm to convert from binary ply to ascii ply (wihtout header) :  $3";
#echo "4th arg : psql command to connect to the database : $4";


##
#INPUT CHECK

if [ $# -lt 4 ] ; #check if arg number is right, else print help about input
then
	echo -e "wrong number of arguments, use :  \n \n $usage \n\n" 
	exit 0;
fi
  
##
#UI

echo "loading data from "$2" into temp table "$1" ";
#echo -e "will try to load data from \n "$2" into the table \n "$1" using the programm \"$3" and connecting to \n the DB with \n "$4" "

#Input : 

#Data flow :
# Binary_ply file ---RPly_convert---> ascii ply without header (fifo) -----psql-----> point table in postgres


##
#Data Processing

#Deleting/Creating fifo
rm /tmp/pipe_ply_binaire_vers_ply_ascii_"$1";
mkfifo --mode=0666 /tmp/pipe_ply_binaire_vers_ply_ascii_"$1";

#attempting to copy from file into table : careful , file column must match table column
$3 -a_nh $2 /tmp/pipe_ply_binaire_vers_ply_ascii_"$1" & 
$4 -c "COPY $1 FROM '/tmp/pipe_ply_binaire_vers_ply_ascii_"$1"' WITH CSV DELIMITER AS ' ';";

#deleting fifo 
rm /tmp/pipe_ply_binaire_vers_ply_ascii_"$1";
exit 0;



