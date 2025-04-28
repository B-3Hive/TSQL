Indentifying Indexes that are not being used
Having indexes in a database that are not being used by an application is akin to having an eight bedroom house, but only using three. Having eight bedrooms might be nice if you can afford them, but are also paying and maintaining five bedrooms that are not needed.    This additional maintenance cost is money that is effectively thrown away each year.  Having extra indexes on tables that are not being used still require SQL Server to maintain them every time an update occurs, and consume additional space if never used.  So like the extra bedrooms, these extra indexes are costing slower response times for updates and longer backup times for unused index storage.  So how to identify those indexes that are not used?

Below is a T-SQL select statement that uses this DMV to identify all the indexes that have not been used for the AdventureWorks database:


SELECT o.name Object_Name,
       i.name Index_name, 
       i.Type_Desc 
 FROM sys.objects AS o
     JOIN sys.indexes AS i
 ON o.object_id = i.object_id 
  LEFT OUTER JOIN 
  sys.dm_db_index_usage_stats AS s    
 ON i.object_id = s.object_id   
  AND i.index_id = s.index_id
 WHERE  o.type = 'u'
 -- Clustered and Non-Clustered indexes
  AND i.type IN (1, 2) 
  --Indexes without stats
  AND (s.index_id IS NULL) OR
 -- Indexes that have been updated by not used
      (s.user_seeks = 0 AND s.user_scans = 0 AND s.user_lookups = 0 );

This T-SQL statement using the “user seeks”,  “user_scans” and or “user_looksups” columns in the sys.dm_index_usage_stats to identify whether or not this index has been used.  This information is joined with the sys.objects, and sys.indexes tables in the AdventureWorks database to identify index usage information for only the AdventureWorks database.  If the counters mentioned above are zero for an index in the database then this means it has not been used.  If any one of these counters have a non-zero number then this would indicate that that index has been used. 

Capturing Indexes That Have Been Used
Alternatively it is possible to to capture all the indexes that have been used on a daily bases and store them in a file.  After a few months the information collected can be analysed to determine which indexes have not been used.  Below is another code snippet that show those indexes that have been used:


SELECT o.name Object_Name,
       SCHEMA_NAME(o.schema_id) Schema_name,
       i.name Index_name, 
       i.Type_Desc, 
       s.user_seeks,
       s.user_scans, 
       s.user_lookups, 
       s.user_updates  
 FROM sys.objects AS o
     JOIN sys.indexes AS i
 ON o.object_id = i.object_id 
     JOIN
  sys.dm_db_index_usage_stats AS s    
 ON i.object_id = s.object_id   
  AND i.index_id = s.index_id
 WHERE  o.type = ‘u’
 — Clustered and Non-Clustered indexes
  AND i.type IN (1, 2) 
 — Indexes that have been updated by not used
  AND(s.user_seeks > 0 or s.user_scans > 0 or s.user_lookups > 0 );

When run on an instance of SQL Server this is an expample of the output:

Examining this output it is possible to see how each index has been used by looking at the “user_…” columns.  The “user_seeks” column identifies the number of times an index seek operation has been used to traverse this index to resolve a T-SQL statement.  The “user_scan” column identifies the number time an index scan operation has been used.  The “user_lookups” column identifies the number of times the index has been used in an index lookup operation.  The “user_update” column to identifies how many times this index has been updated due to the table in which the index is associated has been updated by an UPDATE statement.  

Other Factors to Consider
The output of this view assists in determining how valuable indexes have been in resolving queries.  Using this information decisions can be made regarding the need to modify, and/or drop some indexes.  Remember that the information in the “sys.dm_db_index_usage_stats” index only contains statistics that have been gathered since SQL Server was started, the database was opened, or when the index was created.  If the system hasn’t been up very long then potentially the stats that this DMV produces might not be very useful in representing a true picture of the index utilization.  Ensure statistics are representative of the sample of queries executed to determine what maintenance activities are required based on the output of this DMV. 

Tuning Indexes
It is important for a DBA to make sure the indexes on a database are useful.  By using the output from the “sys.dm_db_index_usage_stats” DMV a good picture of how indexes are used develops.  This information can then be utilised to better tune indexes and maximize the performance of the database by removing indexes that are producing more overhead than performance gain.