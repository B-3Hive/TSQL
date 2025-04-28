SELECT 
SCHEMA_NAME(sys.objects.schema_id) AS [SchemaName] 
,OBJECT_NAME(sys.objects.object_id) AS [ObjectName] 
,[rows] 
,[data_compression_desc] 
,[index_id] as [IndexID_on_Table]
FROM sys.partitions 
INNER JOIN sys.objects 
ON sys.partitions.object_id = sys.objects.object_id 
WHERE data_compression > 0 
AND SCHEMA_NAME(sys.objects.schema_id) <> 'SYS' 
ORDER BY SchemaName, ObjectName
 
 
-- check for vardecimalstorage format compression run the following command:
 
SELECT OBJECTPROPERTY(OBJECT_ID('OWare_O_997Max_WIP_entity_for_Ops_Seq'),
            'TableHasVarDecimalStorageFormat') ;
GO

ALTER INDEX ALL ON JDE_Transactions_Remapped
REBUILD WITH (DATA_COMPRESSION = None)