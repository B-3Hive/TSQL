
select DISTINCT
sc.name + '.' + t.name as tableName,
c.name as columnName,
c.is_identity as isIdentity,
ISNULL(icc.index_id, 0) as indexId,
c.column_id as columnId,
ISNULL(icc.is_unique, 0) as inUniqueIndex,
CAST(CASE WHEN icc.type = 1 then 1
	 ELSE 0 END as BIT) as isClustered,
ISNULL(icc.key_ordinal , 0) as indexPosition,
CAST(CASE WHEN t2.name IN ('text','ntext','image') THEN 0 ELSE 1 END as BIT) as isSortable
FROM sysmergearticles ma
JOIN sys.tables t ON t.object_id = ma.objid
JOIN sys.schemas sc ON sc.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types t2 ON t2.user_type_id = c.user_type_id
LEFT JOIN (SELECT ic.object_id,
ic.column_id,
ic.key_ordinal,
i.index_id,
i.is_unique,
i.type
FROM sys.index_columns ic
JOIN sys.indexes i ON i.index_id = ic.index_id
	AND i.object_id = ic.object_id) icc ON icc.object_id = c.object_id
	AND icc.column_id = c.column_id
where t.is_ms_shipped = 0
ORDER BY tableName, columnId