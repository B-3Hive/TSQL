SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 
-- Quickly get row counts.
SELECT OBJECT_SCHEMA_NAME(p.object_id) AS [Schema]
    , OBJECT_NAME(p.object_id) AS [Table]
    , i.name AS [Index]
    , p.partition_number
    , p.rows AS [Row Count]
    , i.type_desc AS [Index Type]
FROM sys.partitions p
INNER JOIN sys.indexes i ON p.object_id = i.object_id
                         AND p.index_id = i.index_id
WHERE OBJECT_SCHEMA_NAME(p.object_id) != 'sys' and i.type_desc ='HEAP'
ORDER BY [Schema], [Table], [Index]