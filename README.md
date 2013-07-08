Pointcloud_in_db
================

This is a short project using several open source tools to store efficentlly large point clouds in a postgres data base.
We propose an efficient and parallel way to load data into base, a way to group points to limit the number of row used in base, and simple use of indexes to greatly accelerate test on pointcloud.


*__WARNING__ : This is a reseach project and it probably is not going to work out of the box, you may need tweaking, and you will have to tune it to add you own types of lidar point.*

##What is pointcloud_in_db?##
-----------------------------

We propose a mixe of different open source project to store and use efficiently very large amounts of Lidar points into a database.

* massive point clouds are loaded efficently into a postgres data base
* this point clouds are stored using the pointcloud extension by P.Ramsey, 1 table per pointcloud, several hundreds points per line.
* we use Postgis extension to build indexes for fast query of point clouds
* the point clouds can then be used and exported to a webgl viewer / another tool


	>The proposed solution has been tested on a 300Millions points cloud and is very efficient (hundreds of milliseconds to perform spatial/temporal intersection, compressed storage, 1 Billion points import in DB by hour, around 200k points/sec on output)


### Why store large Lidar data into a database? ###

The problem is as follow : with a very large number of points (several billions), how to get efficently those in a defined area?
The traditional way is to build a spatial tree in filesystem and creating hierarchy of small files.
A nex approach has been to put this point in Data Base and use advanced indexing.partitionning functionnalities.

|                              | FileSystem | Database | 
| ---------------------------- | ---------- | -------: |
|  Simplicity                  | [X]        | [ ]      |
|  Speed                       | [X]        | [ ]      |
|  Less Size on disk           | [X]        | [ ]      |
|  Security                    | [ ]        | [X]      |
|  Need server/hardware        | [ ]        | [X]      |
|  Versability                 | [ ]        | [X]      |
|  Scalability                 | [ ]        | [X]      |
|  Concurrent R/W accesses     | [ ]        | [X]      |
|  Filtering on points         | [ ]        | [X]      |
|  Out-of-memory processing    | [ ]        | [X]      |
|  Data Integrity & Management | [ ]        | [X]      |


##Summary##
-----------

1. How does it works by default (short)
2. How does it works by default (detailled)
	* Sending points to database
	* getting points into temporary tables
	* grouping temporary points into patch 
	* getting points from the patch table
3. How to install
4. How to use default
5. How to tweak to your perticular use case
6. Technical details
7. Licence summary

##How does it works (short)##
-----------------------------

__Abstract__ : 

* _Converting binary point cloud file into ASCII CSV_ :

>By default the ply files containing a binary representation of points are converted to an ascii csv representation of the points (*the separator is a whitespace, not a comma*)


* _Loading Point data into temporary table inside DB_ :
	
>This ascii points with all their attributes are then send to a psql process which fill a temporary table in database with incoming data : one row per point, one column per attributes


* _Creating points and grouping close points into patch_ :
	
>e create points from temporary table and group it (with a spatial criteria : by cubic meter) to form patches. This PCPATCH are written in the patch table where the totality of the pointcloud will be stored.
>The point must respect a user-defined schema (see table pointcloud_formats).
		
* _Working with the points_
	
>When the patch table has been populated, we create indexes to allow fast query on patches. When querying, we first find candidate patches then decompose candidate patches into points, which can be used for visualization/processing.


##How does it works (detailled)##
---------------------------------
* __How does it works precisely__
	* Sending points to database
	* Getting points into temporary tables
	* Grouping temporary points into patch
	* Using the patch table

@TODO : insert here the schema
	
### Sending points to database ###

 __|binary points|__ __--->__ __|ascii points|__ __--->__ __| to database|__ 
*Note : all the data is streamed, there is no temporary files used*

This steps are performed using a modified version of RPly and a linux fifo, creating an efficient stream
*Note : this process is suboptimale, it would be better to directly load binary points into postgres (using pg_bulkoad for instance)*
* converting from binary ply to binary ascii
	* We use a modified version of the RPly programm : it has been modified to not ouput the ply header and to increase the number of digits it outputs (as the float precision limit is system-depend).

### Getting points into temporary tables ###

 __|input csv stream |__ __--->__ __|psql COPY process|__ __--->__ __| temporary table with one column per attribute|__ 

* getting points into temporary tables
	* The input is a stream of ascii point values separated by space and end of line. The order of the input values and of the temporary table column must exactly match.
	* We use a psql process hosting a SQL COPY statement reading from stdin and writing into the temporary table inside the database.

### Grouping temporary points into patch ###

 __|temporary table |__ __--->__ __|points |__ __--->__ __| groups of points|__ __--->__ __| patches|__ __--->__ __| patch table |__  

* grouping temporary points into patch
*Note : This si currently the most time consuming part of the process, and could without a doubt be greatly improved.* 
	* The idea is to regroup points based on how points will be used by the final users.
	* For this we use the group by function of sql to form the groups. 
		* We tried spatial grouping (0.125 cubic, meter, 1 cuvic meter), and time grouping (1millisecond, 100 millisecond, based on time of acquisition).
	* the points in a group are then merged into a patche.


### Using the patch table ###
points retrieval:
__|patch table |__ __--->__ __|filtering on patch|__ __--->__ __| patch candidates|__ __--->__ __| extraction of points from patch candidate|__ __--->__ __| filtering on points|__ __--->__ __| Point processing/ Visualization / editing ...|__    

* using the patch table
	* creating indexes
		* We create indexes based on what we want to do with data
	* querying for points :
		* a query for points is in 2 parts. The first part is to find the patches that might contains the points we are interested in. The second part is to extract points from this patches and use it



##How to install##
------------------

###How to Install summary ###

1. Dependencies
2. short description of install process
3. detailled description of install process

### Dependencies###

* OS:
	* a computer with a linux (we used [Ubuntu 12.0.4 LTS 32 and 64 bits](http://www.ubuntu.com/download/desktop))
	* bash and a C compiler
	* admin rights

* Data Base: 
	* [Postgresql 9.2](http://www.postgresql.org/) 
	* [Postgis 2.0.3 extension](http://postgis.net/) 
	* [Pointcloud extension and Pointcloud_postgis extension](https://github.com/pramsey/pointcloud/)
	
* Software
	* (optionnal) the modified version of [Diego Nehab's RPly](http://w3.impa.br/~diego/software/rply/) to import points in ply format into database


###Install process (short)###

 *Note : We tested this solution both on a dedicaced 64 bits Ubuntu 12.0.4 LTS and on a 32bits Ubuntu 12.0.4 LTS hosted by a virtual machine (host = windows Vista, guest = Ubuntu)* 

* Abstract of the install process
	*Install OS
	* Install and configure postgres/postgres-dev
	* Install and configure Postgres extension : Postgis, pointcloud, pointcloud_postgis
	* (semi_optionnal) Compile RPly_convert
	* Get the scripts to make it works
	* Prepare a data base

###Install process (long)###


* Install process
* Installing the OS
	* ( optionnal ) Virtual Machine Setup : we used [VirtualBox](https://www.virtualbox.org/)  
		* Install is straightforward, you will need guest addition to allow shared folder and shared clipboard (usefull)
	* Ubuntu 12.0.4 setup :
		* dl the iso from the ubuntu website : http://www.ubuntu.com/download/desktop
		Use it to install from CD or directly in VirtualBox
		Update the system (`sudo apt-get update`)
*Install and configure Postgres 9.2
	* Postgres 9.2 setup
		* the process should be like this	
			* getting postgres 9.2
				* add the postgres repository (apt.postgresql.org , [instructions here](http://wiki.postgresql.org/wiki/Apt#PostgreSQL_packages_for_Debian_and_Ubuntu) )
				* install the 9.2 binary for your linux
				* install the 9.2 dev packages for your linux
			* setup of postgres
				* set password for postgres user (`sudo passwd postgres` ; `su - postgres` ; `psql -c"alter user postgres with password 'postgres';"`)
				* change the `kernel.shmmax` of your system 
					* edit the `/etc/sysctl.conf` and add line `"kernel.shmmax = "XXX`, you may add several other kernel.sh parameters
				* config files :  , Config files are in '/etc/postgres/9.2/main' , refere to [postgres manual](http://www.postgresql.org/docs/9.2/static/runtime-config.html)
					* postgres.conf
						* you have to tune at least `"shared_buffers"` ,  `"wal_buffers"` ,`"work_mem"` , `"maintenance_work_mem"` ,`"checkpoint_segments"` ,`"effective_cache_size"`
						* you have to change the parameter `listen_adresses` or you won't be able to reach the server
					* pg_hba.conf
						* tune the parameters to allow connection trough `md5` from host
						* tune the parameter to allow a `trust` connection for postgres from local
				* restart server ( `sudo /etc/init.d/postgresql restart`)
				* (optionnal) redirect your server port in the virtualbox (in Settings/network/redirect ports) to access it from outside
				* create a database and test the server
		* Getting Postgres extension : postgis, pointcloud, pointcloud_postgis
			* getting postgis 2.0.3
				* on ubuntu LTS 12.0.4 64 bits there is no packages for postgres 9.2, so we need to build from sources
				* getting postgis dependecies
					* building is easy if we don't have to build the postgis dependency :GEOS, Proj.4, GDAL, LibXML2 and JSON-C.
					* add the repository https://launchpad.net/~ubuntugis/+archive/ppa/ and https://launchpad.net/~ubuntugis/+archive/ubuntugis-unstable
					* get from these repository the packages of depencies
				* compiling postgis
					* it is very straight forward
					* dl sources
					* execute `./configure`, you may need to install the command called by executing `./configure`
					* execute `"make` and `sudo make install`
				* testing postgis
					* in a db add postgis extension `CREATE EXTENSION Postgis`, and try the function `SELECT PostGIS_full_version();`
			* getting pointcloud
				* getting pointcloud dependencies
					* you will need "CUnit", which you can found in repository
				* compiling pointcloud
					* dl the sources from the [git repository](https://github.com/pramsey/pointcloud)
					* run `./autogen.sh` , then `./configure`, then `make`, then `sudo make install`
				* testing pointcloud
					* in a database, `CREATE EXTENSION pointcloud,pointcloud-postgis`
					* add the dummy point schema ("simple 4-dimensional schema ")
					* execute `SELECT PC_AsTExt(PC_MakePoint(1, ARRAY[-127, 45, 124.0, 4.0]));` to test pointcloud
					* execute `SELECT PC_MakePoint(1, ARRAY[-127, 45, 124.0, 4.0])::geometry;` to test pointcloud-postgis
		* (semi_optionnal) Compile RPly_convert
			* (optionnal) getting the modified version of RPly
				* I modified RPly so as to use it to send pointcloud data directly into postgres
				* the source code is in RPly_Ubuntu folder
				* to compile it : `make`
				* *NOTE : warning : this code may cause troubles on windows*
		* Get the scripts to make it works
			* you will need SQL scripts and sh scripts, they are in the folder "script"
			* __sql scripts ought to be executed command by command using pgadmin, so as to control results__
			* sh scripts requires parameter and should be launched approprietly
			* see the following for use-instruction 


##How to use default##
----------------------

### How to use default : Short ###

A demo is included in this project :
* Download the Git sources
* unzip it
* Follow the install process to install every necessary tools
* Follow demo instructions


####__Before going on, all the necessary tools should work__ ####

* 
 	* Postgres : you should be able to create database, schema, and have plsql
 	* postgres user local permission : 
 		* try to run a psql command while connected as postgres to see if all the permissions are right (``su postgres`, `psql -d  your_database -p 5432 -c "SELECT Version();"`) 
	* postgis : you should have postgis installed
		* Try to run the following command : `psql -d  your_database -p 5432 -c "SELECT PostGIS_full_version();"`
	* pointcloud : (test after)
	* pointcloud_postgis (test after)
	* the RPly_convert programm 
		* try to run the programm on sample data : `cd Pointcloud_in_db;` `su postgres` `./RPly_Ubuntu/bin/RPly_convert  -a_nh ./data/riegl/sample_riegl_18_01.ply ./data/riegl/test_output_rplyconvert.asc`
 `more ./data/riegl/test_output_rplyconvert.asc` 

### How to use default : detailled ###

* Demo Instructions
	* Create a postgres database and ad postgis, pointcloud, pointcloud_postgis extensions
	* Execute all the sql command __one by one__ from the `1_Preparing_DB_before_load.sql` script
		* *TIP : with PGADMIN query editor, highlight one query and hit F5 to execute only this query*
		* You can execut command several time : it is not going to do anything (error), but your database will be in the right state for going on with the demo
	* Go in the `./Pointcloud_in_db folder/script` and open `parallel_import_into_db.sh`
		* check all parameters (at least the number of thread you wan to use)
			* There are only 5 sample riegl files for test purpose in ./data/riegl,
		* go into `./Pointcloud_in_db folder/script`, switch to postgres user : `su postgres` and launch the script : `parallel_import_into_db.sh` 
			* Data should be loading from the sample riegl file (5), it should be over in few seconds
		* Now the table "acquisition_tmob_012013.riegl_pcpatch_space" should have some patches
			* check content of fex patches with the sql command : 
			* `SELECT gid, PC_AsText(patch)
				FROM acquisition_tmob_012013.riegl_pcpatch_space
				LIMIT 10` Warning : pgadmin doesn't print to big string, copy past it to a text editor to see it.
	* Execute all the sql command __one by one__ from the `3_tuning_table_after_load.sql` script
		* *TIP : with PGADMIN query editor, highlight one query and hit F5 to execute only this query*
	* Now you have several indexes to quicken some queries
	* (optionnal) you can visualyze the patches with the [Quantum GIS software](http://hub.qgis.org/projects/quantum-gis/wiki/Download)
		* Assuming you have Qgis and the right python library ([Psycopg](http://wiki.postgresql.org/wiki/Psycopg))
		* Create a new qgis project and save it! (or QGis will crash latter)
		* In the `Layer/New Postgis Layer`, create a new connection to your database and save it (host is usually localhost, port should be 5432)
		* Now open the DBManager and clic on Postgis/ConnectionToYourDatabase
		* Adding patches
			* Open an SQL windows
			* type in the command : `SELECT rps.gid as gid, rps.patch::geometry AS geom
					FROM acquisition_tmob_012013.riegl_pcpatch_space as rps
					LIMIT 1000` and execute it
			* Select `load as a new layer` and choose column `gid` and `geom`
			* Name the layer and click to load it into QGIS 
			* Select the IGNF:LAMB93 spatial referential
			* you should see the patches geometry, ie the bounding box of points inside the patch
		* Adding points
			* Now open the DBManager and clic on Postgis/ConnectionToYourDatabase
			* Open an SQL windows
			* type in the command : 
 	 	`SELECT row_number() over() AS gid ,point_postgis.point AS geom 
		FROM( 	
			SELECT PC_Explode(patch)::geometry AS point
			FROM acquisition_tmob_012013.riegl_pcpatch_space AS rps 
		) AS point_postgis; `
			* Select `load as a new layer` and choose column `gid` and `geom`
			* Name the layer and click to load it into QGIS 
			* Select the IGNF:LAMB93 spatial referential
			* you should see the points
			* *Please note that QGis is very slow to print many points, if you have over few 100k points it may crash*

Of course there is no interest to use a database to store the few sample points provided with the demo.
You may fill the data base with several millions (billions) of points to see the power of this solution.
One key SQL tool is to be able to do spatial filtering/ temporal filtering on the patches
Here are 2 examples that you could also visualize in QGIS
	
	--spatial filtering with the demo set
	SELECT row_number() OVER () AS gid, points.geom as geom
		FROM (
			SELECT PC_Explode(patch)::geometry as geom
			FROM acquisition_tmob_012013.riegl_pcpatch_space as rps
			WHERE ST_Intersects(rps.patch::geometry, ST_Buffer(ST_MakePoint(2066.35643460795,20690.4825030569),5))=TRUE
		) as points
	
	--temporal filtering with the demo set
	SELECT row_number() OVER () AS gid, points.point::geometry as geom 
	FROM (
		SELECT PC_Explode(patch) AS point
		FROM acquisition_tmob_012013.riegl_pcpatch_space as rps
		WHERE acquisition_tmob_012013.rc_compute_range_for_a_patch(patch,'gps_time') && NUMRANGE(54160.6,54160.7)
		) as points
	WHERE PC_Get(points.point,'gps_time') <@ NUMRANGE(54160.6,54160.7)
	

##How to tweak to your perticular use case##
----------------------				

### Working with your own point attributes ###

@TODO
To load and use your own point type (meaning a lidar point with any attributes) you need to tweak several parts
* scripts : 
	* `1_Preparing_DB_before_load.sql`
		* Add an entry to the `pointcloud_formats` table with your own data schema
		* Create a patch table using right patch definition (PCPATCH(N), where N is the pcid of your schema)
	* `parallel_import_into_db.sh`
		* Change at least the data folder to match the data where your data is
		* change the `pointschema` to your custom schema
	* `sequential_import_into_db.sh`
		* Change the definition of temporary table (sql CREATE TABLE), the columns must match exactly you point attributes
		* Change the way the patches are created, as there is a hardcoded list of attributes here, and the pcid is also hardcoded
		* 
	* `3_tuning_table_after_load.sql`
		* You may want custom indexes about some of your attributes.
	

### Loading from other file type than binary ply ###

*The solution can be easily adapted to work with point data other than binary ply.*
Supposing that you have a programm converting you point into a stream of ascii values,
you just have to echange the parameter `programmplytoascii` in the `parallel_import_into_db.sh` to give your programm.
This project assume you have several points files so to be able to load theim in parallel. If you have one big file you can use the `man split` commande to split it into several files.

If you want to change more deeply the way data is loaded you need to edit the script `one_file_import_into_db.sh`. This way you can for example load binary data with [pg_bulkload](http://pgbulkload.projects.pgfoundry.org/)

_TIP : if you point are already in csv format, you can use a linux command to stream it to the psql COPY process (like `cat` or `sed`)._
If you use the .las format, there is a las2txt utility, you will need to remove the header
You could also use the [PDAL project](http://www.pointcloud.org/), alltought still in alpha release


### Using different kind of partitions for your patches ###

The demo use a partition by cubic meter
Here are some tips to use other
*   
	* partition by 0.5*0.5*0.5 cubic meter
	`GROUP BY 0.5*ROUND(2*ST_X(point::geometry)),0.5*ROUND(2*ST_Y(point::geometry)),0.5*ROUND(2*ST_Z(point::geometry))`
	>Or 
		* `GROUP BY 0.5*ROUND(2*PC_Get(point,'x')),0.5*ROUND(2*PC_Get(point,'y')),0.5*ROUND(2*PC_Get(point,'z'))`
	* partition using an irregular grid (Postgis)
		* `GROUP BY ST_SnapToGrid(point::geometry,5,4)`
	* partition by 100 Millisecond on acquisition time
		* `GROUP BY ROUND(1000*PC_Get(point,'gps_time')/100)`
	* multi scale partition :
		- first partition by cubic meter, then partition by 5*5*5 cubic meter the patches containing less than 5 points
		
@TODO		

##Technical details##
-------------------

About performances:
	* Loading
		* if you have binary data use pg_bulkload to accelerate things
		* The query to make patch will be much faster with fewer points , so it may be interessting to split your points into small files.
	* querying 
	* Server

* Details on architecture choices
		* We assumed that querying a database table can be fast, if _there are indexes_ and _the table is not too big_.
			* the cost of building/storing/maintaining indexes strongly depends on the number of rows in a table, therefore we cannot store billions of points as billions of lines. This lead to the idea that we have to regoup points.
			* The way we regroup points is directly linked to the way we would like to get points. If we intend to find points near something or in a certain area, we should group points _spatially_. If we intend to get all points that have been acquired between Time T and T+X, we should group points _temporally_. If we intend to get points sharing a common property (like intensity), we could group by _attributes_ . To a certain extend it can be efficient to query points using several criterias.
			* For the use case we tested, the time of acquisition is somewhat linked to the position, as points acquired around the same time tend to be relatively close together. Therefore it can be efficient to filter by time of acquisition on small spattialy grouped points.

* Why the number of row should be kept low ?
	* The way postgres works it is more efficient that when querying a table, this table index fit into the server memory. If the table fit also into memory it is even better
	* We have to take into concern update/insert/delete (cost, lock).

* The alternatives
	* The problem of having lots of data and querying efficiently in postgres can be reduced to "not having one table with too many rows". So either we split the table into several smaller table, or we regroup row to lessen the count.
		* The classical solution is [table partitionning](http://www.postgresql.org/docs/9.2/static/ddl-partitioning.html), that is split the table to several smaller table, while using the postgres inheritance feature. This mean that all the tables are children to one master table, representing all the data.  This is used with great success, but has several cons. __In short, a lot of work is rejected upon the user__ 
			* First, when querying the master table, in order for the server to not look into every inherited tables (which would not scale, and would keep from getting indexes into memory), we need to define constraint so the query planner can skip whole table. The power of table partitionning therefore relies in the constraints we define on inherited table. For instances, We could decide that table 1 correspond to one area, table 2 to another area, and so on.
			* So to make it works, we have to manually taking car of constraints for every table, meaning enforcing it and updating it. This may be a lot of work, and slow operations
			* Currently, postgres can't handle insert or update in the master table, meaning it's up to the user to deal with it. SO if we want to change a point attribute, we have to programmaticaly find in which table it is, then adapt the query to update it in this table. This can be done using rewritting rules, but is again a lot's of work.
			* Lastly, __we are generally not interested in one point!__ , so why bother creating and maintaining a complexe system to get point by point when we generaly want to work with hundreds thousands?
		* The other solution is to regroup rows so to have fewer rows which will be larger. Using this solution we have to deal with the maximum row size issue.
			* The maximum row size is user defined and is around 8kByte, that means between 100 and 300 points. Therefore a multi-billion points acquisition would take several tens of millions rows, which is too much.
			* Therefore to be able to scall, we have to use an internal feature of postgres which is the TOAST table. When storing more than the maximum size allowed per row, postgres will store the object in a toast table, which can be seen as a shadow table, as it is totally transparent to the user.
			* With previous version of postgres it could have been a problem as when filtering a row, the row was read. This could have been very performance-consuming with large rows. This is why we chose the 9.2 postgres version, where index only scan where introduced. In short : postgres tries not to read the row when it doesn't need it. This guarantees good performances.
 

* Balance between row size/patch size/table size/data compression
	* It may be interesting to try to keep row size under the max row size limit, so as to avoid to use toast table. In the same way the max row size could be increased.
	* the distribution of the number of points in patch could be studied, as having almost emptu patches is not efficient for querying (increase the number of rows) and for compression (points in patch are compressed)
	* the toast table is compressed by postgres, it could be intersting to turn this off. In our experiment it was not worth it as the time gained on compressing/uncompressing is less than the additionnal time to read/write bigger data.
	* the patches are compressed, we didn't notice faster processing while storing it uncompressed. This may be however very implementation dependant.



##Licence summary##
-------------------
This project is licensed under the [LGPL license](http://en.wikipedia.org/wiki/GNU_Lesser_General_Public_License)


|                              | licence                                   | 
| ---------------------------- | ----------------------------------------: |
|  this project                | LGPL                                      |
|  Postgres                    | [Postgres licence](http://www.postgresql.org/about/licence/) (BSD-like)               |
|  Postgis                     | GPL                                       |
|  Pointcloud                  | BSD                                       |
|  RPly                        | MIT licence                               |


				
				
				
				
