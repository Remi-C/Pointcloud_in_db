Pointcloud_in_db
================

This is a short project using several open source tools to store efficentlly large point clouds in a postgres data base.
We propose an efficient and parallel way to load data into base, a way to group points to limit the number of row used in base, and simple use of indexes to greatly accelerate test on pointcloud.


The proposed solution has been tested on a 300Millions points cloud and is very efficient (hundreds of milliseconds to perform spatial/temporal intersection, compressed storage, 1 Billion points import in DB by hour, around 200k points/sec on output)

WARNING : This is a reseach project and it probably is not going to work out of the box, you may need tweaking.

The solution is as follow :

_massive point clouds are loaded efficently into a postgres data base
_this point clouds are stored using the pointcloud extension by PRamsey, 1 table per pointcloud
_we use Postgis extension to build indexes for fast query of point clouds
_the point clouds can then be used and exported to a webgl viewer / another tool


We don't store one point in a line, but instead regroup points into patch, so the number of lines is greatly limited (300Millions of points is about 500k lines). Plusses are that indexes size is contained, and we can store a lot's of point in one table (as opposed to use table inheritage)




The dependancies are as follow : 
OS:
	_a computer with a linux (we used Ubuntu 12.0.4 LTS 32 and 64 bits)
	_a C compiler

Data Base: 
	_Postgresql 9.2
	_Postgis 2.0.3 extension
	_Pointcloud extension
	_Pointcloud_postgis extension
	
Software
	_(optionnal) the modified version of RPly to import ply into database




SETUP :
We tested this solution both on a dedicaced 64 bits Ubuntu 12.0.4 LTS and on a 32bits Ubuntu 12.0.4 LTS hosted by a virtual machine (host = windows Vista, guest = Ubuntu)


	( optionnal ) Virtual MAchine Setup : we used VirtualBox : https://www.virtualbox.org/
		Install is straightforward, you will need guest addition to allow shared folder and shared clipboard (usefull)
	Ubuntu 12.0.4 setup :
		dl the iso from the ubuntu website : http://www.ubuntu.com/download/desktop
		Use it to install from CD or directly in VirtualBox
		Update the system (sudo apt-get update)
	Postgres 9.2 setup
		the process should be like this
		
			_ getting postgres 9.2
				_ add the postgres repository (apt.postgresql.org , instructions : http://wiki.postgresql.org/wiki/Apt#PostgreSQL_packages_for_Debian_and_Ubuntu)
				_ install the 9.2 binary for your linux
				_ install the 9.2 dev packages for your linux
			_ setup of postgres
				_ set password for postgres user (sudo passwd postgres ; su - postgres ; psql -c"alter user postgres with password 'postgres';")
				_ change the kernel.shmmax of your system 
					_ edit the /etc/sysctl.conf and add line "kernel.shmmax = "XXX, you may add several other kernel.sh parameters
				_ config files : http://www.postgresql.org/docs/9.2/static/runtime-config.html , they are in /etc/postgres/9.2/main
					_ postgres.conf
						_ you have to tune at least "shared_buffers" ,  "wal_buffers" ,"work_mem" , "maintenance_work_mem" ,"checkpoint_segments" ,"effective_cache_size"
						_ you have to change the parameter listen_adresses or you won't be able to reach the server
					_pg_hba.conf
						_ tune the parameters to allow connection trough md5 from host
						_tune the paramter to allow a trust connection for postgres from local
				_restart server ( sudo /etc/init.d/postgresql restart)
				_(optionnal) redirect your server port in the virtualbox (in Settings/network/redirect ports) to access it from outside
				_create a database and test the server
			
			_getting postgis 2.0.3
				_on ubuntu LTS 12.0.4 64 bits there is no packages for postgres 9.2, so we need to build from sources
				_getting postgis dependecies
					_building is easy if we don't have to build the postgis dependency :GEOS, Proj.4, GDAL, LibXML2 and JSON-C.
					_add the repository https://launchpad.net/~ubuntugis/+archive/ppa/ and https://launchpad.net/~ubuntugis/+archive/ubuntugis-unstable
					_ get from these repository the packages of depencies
				
				_compiling postgis
					_it is very straight forward
					_ dl sources
					_ execute ./configure, you may need to install the command called by executing ./configure
					_ execute "make" and "sudo make install"
				_testing postgis
					_ in a db add postgis extension "CREATE EXTENSION Postgis", and try the function "SELECT PostGIS_full_version();"
			
			_getting pointcloud
				_getting pointcloud dependencies
					_you will need "CUnit", which you can found in repository
				_compiling pointcloud
					_ dl the sources from the git repository : https://github.com/pramsey/pointcloud
					_ run ./autogen.sh , then ./configure, then make, then sudo make install
				_testing pointcloud
					_ in a database, CREATE EXTENSION pointcloud,pointcloud-postgis
					_add the dummy point schema ("simple 4-dimensional schema ")
					_execute "SELECT PC_AsTExt(PC_MakePoint(1, ARRAY[-127, 45, 124.0, 4.0]));" to test pointcloud
					_execute "SELECT PC_MakePoint(1, ARRAY[-127, 45, 124.0, 4.0])::geometry" to test pointcloud-postgis
			
			_getting the scipts to make it works
				_you will need SQL script and sh script, they are in the folder "script"
				_sql script ought to be executed command by command using pgadmin, so as to control results
				_sh scripts requires parameter and should be launched approprietly
				_you have manually launch script in the right order
			
			_(optionnal) getting the modified version of RPly
				_ I modified RPly so as to use it to send pointcloud data directly into postgres
				_ the source code is in RPly_Ubuntu folder
				_to compile it : make
				_NOTE : warning : this code may cause troubles on windows
				

## HOWTO LOAD POINT CLOUD INTO DATABASE ##
	
###What you need :###
	
-	You have files describing lot's and lot's of points. These points have arbitrary attributs.
-	Amongst one point cloud every point has the sames attributes.
-	You have a database and permission to create table and so.
-	You have all the scripts and the RPly_convert programm
-	Note : 
	The scripts are written to work with ply files, but can be easily adapted as long you can provide an ascii representation of your table points.
	
	
				
###Abstract of the loading process step by step###
- enable your data base
- execute first sql script "1_Preparing_DB_before_load.sql"
- execute bash script to import data into database "parallel_import_into_db.sh"
- execute second sql script "3_tuning_table_after_load.sql"
		

		
		_first you have to prepare everything in base and out base.
			_in base : you have to create the 
	


	
	
	
	
	How does it works?
	Abstract : 
		The ply files containing a binary representation of points are converted to an ascii representation of the points, very close to the csv format (the separator is a whitespace, not a comma)
		This ascii points with all their attributes are then send to a psql process which fill a table in database with incoming data
		Then this temporary table containing one row per point and one column per attribute is used to group points by cubic meter. The points grouped are then fused to a PCPATCH and written in the table where the totality of the pointcloud will be stored.
		The point must respect a schema (see table pointcloud_formats).
		
		When data loading is finished, you have a very big pointcloud in a table with few row, but very large row. It is then efficient to use indexes ont this table.
	
	How does it works precisely
		_Sending points to database
		_getting points into temporary tables
		_grouping temporary points into patch 
		_using the patch table
		
		_Sending points to database
			the data flow is :
			binary points --> ascii points --> remove last space in every line --> to database
			This steps are performed using a modified version of RPly, the sed utility, and fifo and pipe. All the process is streamed (no temporary files)
			NOTE : this process is suboptimale, it would be better to directly load binary points into postgres (using pg_bulkoad for instance)
			_ converting from binary ply to binary ascii
				We use a modified version of RPLY : it has been modified to not ouput the ply header and to increase the number of digits it outputs. One probleme is that during ascii conversion it adds a whitespace at the end of lines. It must be removed.
			_removing the extra whitespace at the end of line
				We use the "sed" command line utility, in streaming mode, do detect end of line and remove the whitespace before.
				
		_getting points into temporary tables
			The input is a stream of ascii point values. The order of the input values and of the temporary table column must exactly match.
			We use a psql process hosting a SQL COPY statement reading from stdin and writing into the temporary table inside the database.
		
		_grouping temporary points into patch
			This si currently the msot time consuming part of the process, and could without a doubt be greatly improved. The idea is to use the group by function of sql to form groups of points close enough spatially. We also tried grouping the points by time of acquisition. Then we create a patch with this points and insert it into the table which will host the pointcloud
		
		_using the patch table
			_ creating indexes
				We create indexes based on what we want to do with data
			_querying for points :
				a query for points is in 2 parts. The first part is to find the patches that might contains the points we are interested in. The second part is to extract points from this patches and use it.
				
			
			

				
				
				
				
