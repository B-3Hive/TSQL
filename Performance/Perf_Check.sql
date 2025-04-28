WITH Waits AS
(SELECT wait_type, wait_time_ms / 1000. AS wait_time_s,
100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct,
ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK'
,'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR', 'LOGMGR_QUEUE','CHECKPOINT_QUEUE'
,'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH','BROKER_TASK_STOP','CLR_MANUAL_EVENT'
,'CLR_AUTO_EVENT','DISPATCHER_QUEUE_SEMAPHORE', 'FT_IFTS_SCHEDULER_IDLE_WAIT'
,'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP'))
SELECT W1.wait_type,
CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s,
CAST(W1.pct AS DECIMAL(12, 2)) AS pct,
CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct
FROM Waits AS W1
INNER JOIN Waits AS W2
ON W2.rn <= W1.rn
GROUP BY W1.rn, W1.wait_type, W1.wait_time_s, W1.pct
HAVING SUM(W2.pct) - W1.pct < 99 OPTION (RECOMPILE); -- percentage threshold
GO



SELECT top 10 (total_logical_reads/execution_count),
  (total_logical_writes/execution_count),
  (total_physical_reads/execution_count),
  Execution_count, sql_handle, plan_handle
FROM sys.dm_exec_query_stats  
ORDER BY (total_logical_reads + total_logical_writes) Desc 
--To get the text of the query, run the following DMV query.


SELECT s2.dbid, 
    s1.sql_handle,  
    (SELECT TOP 1 SUBSTRING(s2.text,statement_start_offset / 2+1 , 
      ( (CASE WHEN statement_end_offset = -1 
         THEN (LEN(CONVERT(nvarchar(max),s2.text)) * 2) 
         ELSE statement_end_offset END)  - statement_start_offset) / 2+1))  AS sql_statement,
    execution_count, 
    plan_generation_num, 
    last_execution_time,   
    total_worker_time, 
    last_worker_time, 
    min_worker_time, 
    max_worker_time,
    total_physical_reads, 
    last_physical_reads, 
    min_physical_reads,  
    max_physical_reads,  
    total_logical_writes, 
    last_logical_writes, 
    min_logical_writes, 
    max_logical_writes  
FROM sys.dm_exec_query_stats AS s1 
CROSS APPLY sys.dm_exec_sql_text(sql_handle) AS s2  
WHERE s2.objectid is null 
ORDER BY execution_count DESC,  total_worker_time DESC,  s1.sql_handle, s1.statement_start_offset, s1.statement_end_offset;