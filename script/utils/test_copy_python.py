# -*- coding: utf-8 -*-
"""
Created on Mon Dec 15 19:21:00 2014

@author: remi
"""

import psycopg2


conn = psycopg2.connect(  
        database='vosges'
        ,user='postgres'
        ,password='postgres'
        ,host='172.16.3.50'
        ,port='5432' ) ;  
f = open('/tmp/toto.csv', 'rw+')
cur = conn.cursor()
cur.copy_expert("COPY (SELECT generate_series(1,10)) TO STDOUT WITH CSV HEADER", f )
print f 
cur.close()
conn.close()