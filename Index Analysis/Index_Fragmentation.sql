-- Index Fragmentation

SELECT
 DB_NAME() AS DBName
 ,OBJECT_NAME(ps.object_id) AS TableName
 ,i.name AS IndexName
 ,ips.index_type_desc
 ,ips.avg_fragmentation_in_percent
 FROM sys.dm_db_partition_stats ps
 INNER JOIN sys.indexes i
 ON ps.object_id = i.object_id
 AND ps.index_id = i.index_id
 CROSS APPLY sys.dm_db_index_physical_stats(DB_ID(), ps.object_id, ps.index_id, null, 'LIMITED') ips
 ORDER BY ps.object_id, ps.index_id