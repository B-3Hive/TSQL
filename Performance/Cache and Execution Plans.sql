
/* Worst Performing Queries by execution count */
select top 20 
                stat.execution_count as execution_count,
                stat.total_logical_reads as total_logical_read,
                stat.total_worker_time as total_CPU,
                cache.objtype,
                req.text,
                '1 Execution count' as typeOf,
                row_number() OVER (ORDER BY stat.execution_count desc) as rownum
from sys.dm_exec_query_stats AS stat
CROSS APPLY sys.dm_exec_sql_text(stat.sql_handle) as req
CROSS APPLY    sys.dm_exec_query_plan(stat.plan_handle)    AS pl
left join sys.dm_exec_cached_plans as cache on cache.plan_handle = stat.plan_handle
order by execution_count desc

/* To get the worst performing queries order by CPU time execute following SQL query (Select Top 20 worst performing queries. */

select top 20 
                stat.execution_count as execution_count,
                stat.total_logical_reads as total_logical_read,
                stat.total_worker_time as total_cpu,
                cache.objtype,
                req.text,
                '2 CPU' as typeOf,
                row_number() OVER (ORDER BY stat.total_worker_time desc) as rownum
from sys.dm_exec_query_stats AS stat
CROSS APPLY sys.dm_exec_sql_text(stat.sql_handle) as req
CROSS APPLY    sys.dm_exec_query_plan(stat.plan_handle)    AS pl
left join sys.dm_exec_cached_plans as cache on cache.plan_handle = stat.plan_handle
order by total_cpu desc


/*  To get the worst performing queries order by logical reads execute following SQL query (Select Top 20 worst performing queries.  */
	select top 20 
               		stat.execution_count as execution_count,
               		stat.total_logical_reads as total_logical_read,
               		stat.total_worker_time as total_cpu,
               		cache.objtype,
               		req.text,
               		'3 Logical Read' as typeOf,
               		row_number() OVER (ORDER BY stat.total_logical_reads desc) as rownum
	from sys.dm_exec_query_stats AS stat
	CROSS APPLY sys.dm_exec_sql_text(stat.sql_handle) as req
	CROSS APPLY    sys.dm_exec_query_plan(stat.plan_handle)    AS pl
	left join sys.dm_exec_cached_plans as cache on cache.plan_handle = stat.plan_handle
	order by total_logical_read desc





select * from
-- CPU cache SQL-Server
(select top 20 
                stat.execution_count as execution_count,
                stat.total_logical_reads as total_logical_read,
                stat.total_worker_time as total_cpu,
                cache.objtype,
                req.text,
                '2 CPU' as typeOf,
                row_number() OVER (ORDER BY stat.total_worker_time desc) as rownum
from sys.dm_exec_query_stats AS stat
CROSS APPLY sys.dm_exec_sql_text(stat.sql_handle) as req
CROSS APPLY    sys.dm_exec_query_plan(stat.plan_handle)    AS pl
left join sys.dm_exec_cached_plans as cache on cache.plan_handle = stat.plan_handle
order by total_cpu desc
union
select top 20 
                stat.execution_count as execution_count,
                stat.total_logical_reads as total_logical_read,
                stat.total_worker_time as total_cpu,
                cache.objtype,
                req.text,
                '3 Logical Read' as typeOf,
                row_number() OVER (ORDER BY stat.total_logical_reads desc) as rownum
from sys.dm_exec_query_stats AS stat
CROSS APPLY sys.dm_exec_sql_text(stat.sql_handle) as req
CROSS APPLY    sys.dm_exec_query_plan(stat.plan_handle)    AS pl
left join sys.dm_exec_cached_plans as cache on cache.plan_handle = stat.plan_handle
order by total_logical_read desc
union
select top 20 
                stat.execution_count as execution_count,
                stat.total_logical_reads as total_logical_read,
                stat.total_worker_time as total_cpu,
                cache.objtype,
                req.text,
                '1 Execution count' as typeOf,
                row_number() OVER (ORDER BY stat.execution_count desc) as rownum
from sys.dm_exec_query_stats AS stat
CROSS APPLY sys.dm_exec_sql_text(stat.sql_handle) as req
CROSS APPLY    sys.dm_exec_query_plan(stat.plan_handle)    AS pl
left join sys.dm_exec_cached_plans as cache on cache.plan_handle = stat.plan_handle
order by execution_count desc)
as stat
order by typeof, rownum


/* ================================================== */


SELECT TOP 100
    query_hash, query_plan_hash,
    execution_count, 
    total_cpu_time_ms, total_elapsed_time_ms, 
    total_logical_reads, total_logical_writes, total_physical_reads, 
    sample_database_name, sample_object_name, 
    sample_statement_text
FROM 
(
    SELECT 
        query_hash, query_plan_hash,  
        COUNT (*) AS cached_plan_object_count, 
        MAX (plan_handle) AS sample_plan_handle, 
        SUM (execution_count) AS execution_count, 
        SUM (total_worker_time)/1000 AS total_cpu_time_ms, 
        SUM (total_elapsed_time)/1000 AS total_elapsed_time_ms, 
        SUM (total_logical_reads) AS total_logical_reads, 
        SUM (total_logical_writes) AS total_logical_writes, 
        SUM (total_physical_reads) AS total_physical_reads
    FROM sys.dm_exec_query_stats 
    GROUP BY query_hash, query_plan_hash  
) AS plan_hash_stats
CROSS APPLY 
(
    SELECT TOP 1
        qs.sql_handle AS sample_sql_handle, 
        qs.statement_start_offset AS sample_statement_start_offset, 
        qs.statement_end_offset AS sample_statement_end_offset, 
        CASE 
            WHEN [database_id].value = 32768 THEN 'ResourceDb'
            ELSE DB_NAME (CONVERT (int, [database_id].value)) 
        END AS sample_database_name, 
        OBJECT_NAME (CONVERT (int, [object_id].value), CONVERT (int, [database_id].value)) AS sample_object_name, 
        SUBSTRING (
            sql.[text], 
            (qs.statement_start_offset/2) + 1, 
            (
                (
                    CASE qs.statement_end_offset 
                        WHEN -1 THEN DATALENGTH(sql.[text])
                        WHEN 0 THEN DATALENGTH(sql.[text])
                        ELSE qs.statement_end_offset 
                    END 
                    - qs.statement_start_offset
                )/2
            ) + 1
        ) AS sample_statement_text
    FROM sys.dm_exec_sql_text(plan_hash_stats.sample_plan_handle) AS sql  
    INNER JOIN sys.dm_exec_query_stats AS qs ON qs.plan_handle = plan_hash_stats.sample_plan_handle 
    CROSS APPLY sys.dm_exec_plan_attributes (plan_hash_stats.sample_plan_handle) AS [object_id]
    CROSS APPLY sys.dm_exec_plan_attributes (plan_hash_stats.sample_plan_handle) AS [database_id]
    WHERE [object_id].attribute = 'objectid'
        AND [database_id].attribute = 'dbid'
) AS sample_query_text
ORDER BY total_cpu_time_ms DESC;


/**************  ADHOC WORKLOAD *******************/

SELECT AdHoc_Plan_MB, Total_Cache_MB,
AdHoc_Plan_MB*100.0 / Total_Cache_MB AS 'AdHoc %'
FROM (
SELECT SUM(CASE
WHEN objtype = 'adhoc'
THEN convert(float,size_in_bytes)
ELSE 0 END) / 1048576.0 AdHoc_Plan_MB,
SUM(convert(float,size_in_bytes)) / 1048576.0 Total_Cache_MB
FROM sys.dm_exec_cached_plans) T

WITH Query_Stats 
AS 
(
 SELECT plan_id,
 SUM(count_executions) AS total_executions
 FROM sys.query_store_runtime_stats
 GROUP BY plan_id
)
SELECT TOP 10  t.query_sql_text, q.query_id, p.plan_id,
	s.total_executions/p.count_compiles avg_compiles_per_plan
	  FROM sys.query_store_query_text t JOIN sys.query_store_query q
    ON t.query_text_id = q.query_text_id 
    JOIN sys.query_store_plan p ON q.query_id = p.query_id 
    JOIN Query_Stats s ON p.plan_id = s.plan_id
ORDER BY s.total_executions/p.count_compiles DESC


SELECT Top 100 UseCounts, Cacheobjtype, Objtype, TEXT, query_plan
FROM sys.dm_exec_cached_plans 
CROSS APPLY sys.dm_exec_sql_text(plan_handle)
CROSS APPLY sys.dm_exec_query_plan(plan_handle)
Order by usecounts desc

