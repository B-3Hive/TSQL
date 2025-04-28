SELECT 

  migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure, --This is a unitless numberand has meaning only relative the same number for other indexes
  
  CASE WHEN mid.included_columns is null then 
				'CREATE INDEX EIX_' +  LEFT(PARSENAME(mid.statement, 1), 32)
				 + ' ON ' + mid.statement 
			  + ' (' + ISNULL (mid.equality_columns,'') 
				+ CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END 
				+ ISNULL (mid.inequality_columns, '')
			  + ')' 
			  + ISNULL (' INCLUDE (' + mid.included_columns + ')', '')  
			    
  ELSE
			'CREATE INDEX EIX_' +  LEFT(PARSENAME(mid.statement, 1), 32) + '_' +   REPLACE(REPLACE(mid.included_columns,'[','') ,']','')  
			+ ' ON ' + mid.statement 
		  + ' (' + ISNULL (mid.equality_columns,'') 
			+ CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END 
			+ ISNULL (mid.inequality_columns, '')
		  + ')' 
		  + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') 
 END  create_index_statement,
  migs.*, mid.database_id, mid.[object_id]

 
FROM 
	sys.dm_db_missing_index_groups mig

INNER JOIN 
	sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle

INNER JOIN 
	sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle

WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10
and mid.database_id = 6
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC

--Select * from sys.dm_db_missing_index_group_stats order by unique_compiles desc
--Select * from sys.dm_db_missing_index_details
--Select * from sys.dm_db_missing_index_groups
--SELECT *FROM SYS.DATABASES


--group_handle
--int
--Identifies a group of missing indexes. This identifier is unique across the server.
--The other columns provide information about all queries for which the index in the group is considered missing.
--An index group contains only one index.

--unique_compiles
--bigint
--Number of compilations and recompilations that would benefit from this missing index group. Compilations and recompilations of many different queries can contribute to this column value.

--user_seeks
--bigint
--Number of seeks caused by user queries that the recommended index in the group could have been used for.

--user_scans
--bigint
--Number of scans caused by user queries that the recommended index in the group could have been used for.

--last_user_seek
--datetime
--Date and time of last seek caused by user queries that the recommended index in the group could have been used for.

--last_user_scan
--datetime
--Date and time of last scan caused by user queries that the recommended index in the group could have been used for.

--avg_total_user_cost
--float
--Average cost of the user queries that could be reduced by the index in the group.

--avg_user_impact
--float
--Average percentage benefit that user queries could experience if this missing index group was implemented. The value means that the query cost would on average drop by this percentage if this missing index group was implemented.

--system_seeks
--bigint
--Number of seeks caused by system queries, such as auto stats queries, that the recommended index in the group could have been used for. For more information, see Auto Stats Event Class.

--system_scans
--bigint
--Number of scans caused by system queries that the recommended index in the group could have been used for.

--last_system_seek
--datetime
--Date and time of last system seek caused by system queries that the recommended index in the group could have been used for.

--last_system_scan
--datetime
--Date and time of last system scan caused by system queries that the recommended index in the group could have been used for.

--avg_total_system_cost
--float
--Average cost of the system queries that could be reduced by the index in the group.

--avg_system_impact
--float
--Average percentage benefit that system queries could experience if this missing index group was implemented. The value means that the query cost would on average drop by this percentage if this missing index group was implemented.



