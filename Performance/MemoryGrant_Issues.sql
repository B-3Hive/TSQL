Thanks for your time on the phone. We discussed that it is likely the CMEMTHREAD waits were driven by queries with large memory grants. You mentioned that you have already discovered a problem query that you have stopped, and CMEMTHREAD waits have since lowered to normal levels. Last night during the pssdiag collection there were three different times when a query with a 207 GB memory grant was running. Here are the details of the session that was running the query.



The 207 GB memory grant query had a query_hash of 0x61ED0DD28EC012EA. You can try to lookup the query_hash with the following query.

SELECT TOP 100 ((qs.total_worker_time/1000)/qs.execution_count) as avg_CPU,((qs.total_elapsed_time/1000)/qs.execution_count) as avg_Duration, qs.execution_count, qs.total_worker_time, qs.query_hash,
st.text, qs.plan_handle, DB_NAME(st.dbid) database_name, qp.query_plan--* 
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(sql_handle) st
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) AS qp
where qs.query_hash in (0x61ED0DD28EC012EA)
ORDER BY qs.total_worker_time DESC
GO


You mentioned you have your own method of monitoring and stopping these large memory grant queries. Another thing you can do to address these is reduce request_max_memory_grant_percent for the default workload group in the resource governor configuration.

https://support.microsoft.com/en-us/help/2964518/recommended-updates-and-configuration-options-for-sql-server-2012-and

	ALTER WORKLOAD GROUP
 	If you have many queries that are exhausting large memory grants, reduce request_max_memory_grant_percent for the default workload group in the resource governor configuration from the default 25 percent to a lower value.


Since the CMEMTHREAD waits are under control you wanted to switch focus back to the PAGELATCH waits, since you were able to correlate UI performance issues to the increase in PAGELATCH waits that occurred from 12:33:02 - 12:34:56. In order to troubleshoot the PAGELATCH waits we need the xevent to capture them. We agreed to put a filter on the latch xevent so it only records latches for tempdb pages, and hopefully this will allow you to run the xevent session for a longer period. Here is the script to create the xevent session with the filter on tempdb.

CREATE EVENT SESSION [latch] ON SERVER 
ADD EVENT sqlserver.latch_suspend_begin(
    ACTION(package0.callstack)
    WHERE ([database_id]=(2)))
ADD TARGET package0.event_file(SET filename=N'D:\Cases\118032117859665\latch.xel')
WITH (MAX_MEMORY=262144 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_CPU,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO
