
#!/bin/bash

#Script by Rémi C
#Thales/IGN 20/03/2014
#Prototype for massive point cloud storage into data base

#This script kill all the parallel scripts trying to write in db
#should be used as postgres
#WARNING : will close all open PSQL process

killall parallel_import_into_db.sh;
killall sequential_import_into_db.sh;
killall one_file_import_into_db.sh;
killall RPly_convert ;
killall psql ;
exit 0;
