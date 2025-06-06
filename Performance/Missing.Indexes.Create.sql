/* Identify and create runnable index creation for a specific database */


;WITH I AS ( 

SELECT user_seeks * avg_total_user_cost * 
      (	avg_user_impact * 0.01) AS [index_advantage], 
		migs.last_user_seek, 
		mid.[statement] AS [Database.Schema.Table], 
		mid.equality_columns, mid.inequality_columns, 
		mid.included_columns,migs.unique_compiles, migs.user_seeks, 
		migs.avg_total_user_cost, migs.avg_user_impact 
FROM 
	sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK) 
INNER JOIN 
	sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) 
ON 
	migs.group_handle = mig.index_group_handle 
INNER JOIN 
	sys.dm_db_missing_index_details AS mid WITH (NOLOCK) 
ON 
	mig.index_handle = mid.index_handle 
WHERE 
	mid.database_id = DB_ID() 

	/*The recommended indexes and user impact are both estimates from the cost optimizer
	 there's no guarantee that they are always correct.  Always Update Stats after changing indexes. 
   */
   AND user_seeks * avg_total_user_cost * (avg_user_impact * 0.01) > 4999 -- Set this to a value that  
		) 

SELECT 'CREATE INDEX EIX_' 
            +	SUBSTRING([Database.Schema.Table], 
				CHARINDEX('].[',[Database.Schema.Table], 
				CHARINDEX('].[',[Database.Schema.Table])+4)+3, 
				LEN([Database.Schema.Table]) -  
			    (CHARINDEX('].[',[Database.Schema.Table], 
		         CHARINDEX('].[',[Database.Schema.Table])+4)+3)) 
	        + '_' + LEFT(REPLACE(REPLACE(REPLACE(REPLACE( 
	            ISNULL(Equality_Columns,inequality_columns), 
            '[',''),']',''),' ',''),',',''),20) 
            + ' ON ' 
            + [Database.Schema.Table] 
            + '(' 
            + ISNULL(equality_columns,'') 
            + CASE WHEN equality_columns IS NOT NULL AND 
	                     inequality_columns IS NOT NULL 
                  THEN ',' 
                  ELSE '' 
              END 
            + ISNULL(inequality_columns,'') 
            + ')' 
            + CASE WHEN included_columns IS NOT NULL 
                  THEN ' INCLUDE(' + included_columns + ')' 
                  ELSE '' 
              END CreateStatement, 
            'EIX_' 
            + SUBSTRING([Database.Schema.Table], 
              CHARINDEX('].[',[Database.Schema.Table], 
              CHARINDEX('].[',[Database.Schema.Table])+4)+3, 
              LEN([Database.Schema.Table]) -  
              (CHARINDEX('].[',[Database.Schema.Table], 
              CHARINDEX('].[',[Database.Schema.Table])+4)+3)) 
            + '_' + LEFT(REPLACE(REPLACE(REPLACE(REPLACE( 
            ISNULL(Equality_Columns,inequality_columns), 
            '[',''),']',''),' ',''),',',''),20) 
        IndexName 
FROM I
