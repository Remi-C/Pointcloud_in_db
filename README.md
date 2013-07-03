Pointcloud_in_db
================

This is a short project using several tools to store efficentlly large point clouds in a postgres data base.


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
						_ tune the parameters to allow connection trough md5
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
				

LOAD POINTCLOUD INTO DATABASE
	
	A description of how it works
	
	you have files describing lot's and lot's of points. These points have arbitrary attributs.
	Amongst one point cloud every point has the sames attributes.
	
	The script are written to work with ply files, but can be easily adapted as long you can provide an ascii representation of your points.
	
	


				
				
				
				
