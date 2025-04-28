SELECT 
	s2.dbid, 
   	(SELECT TOP 1 SUBSTRING(s2.text,statement_start_offset / 2+1 , 
      ( (CASE WHEN statement_end_offset = -1 
         THEN (LEN(CONVERT(nvarchar(max),s2.text)) * 2) 
         ELSE statement_end_offset END)  - statement_start_offset) / 2+1))  AS sql_statement,
	s1.sql_handle,
	s1.plan_handle,
    s1.execution_count, 
	S3.query_plan,
    s1.plan_generation_num, 
    s1.last_execution_time,   
    s1.total_worker_time, 
    s1.last_worker_time, 
    s1.min_worker_time, 
    s1.max_worker_time,
    s1.total_physical_reads, 
    s1.last_physical_reads, 
    s1.min_physical_reads,  
    s1.max_physical_reads,  
    s1.total_logical_writes, 
    s1.last_logical_writes, 
    s1.min_logical_writes, 
    s1.max_logical_writes  
FROM sys.dm_exec_query_stats AS s1 
CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS s2  
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS S3
WHERE s2.objectid is null   
--and
--s2.text like '%Select%'
ORDER BY s1.sql_handle, s1.statement_start_offset, s1.statement_end_offset;