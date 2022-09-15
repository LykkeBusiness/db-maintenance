SELECT 
 t.NAME AS TableName,
 schema_name(t.schema_id) as SchemaName,
 i.name AS indexName,
 (SUM(a.total_pages * 8)) / 1024 AS TotalSpaceMB,
 SUM(p.rows) AS RowCounts,
 (SUM(a.used_pages) * 8) / 1024 AS UsedSpaceMB, 
 (SUM(a.data_pages) * 8) / 1024 AS DataSpaceMB
FROM 
 sys.tables t
INNER JOIN  
 sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
 sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
 sys.allocation_units a ON p.partition_id = a.container_id
WHERE 
 t.NAME NOT LIKE 'dt%' AND
 i.OBJECT_ID > 255 AND  
 i.index_id <= 1
GROUP BY 
 t.NAME, t.schema_id, i.object_id, i.index_id, i.name
HAVING
 -- only show items with size > 1 gb
 SUM(a.total_pages * 8) / 1024 > 1000
ORDER BY TotalSpaceMB desc