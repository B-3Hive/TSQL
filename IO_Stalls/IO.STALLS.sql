SELECT  
        DB_NAME(vfs.database_id) [db_name], 
    io_stall_read_ms / NULLIF(num_of_reads, 0) avg_read_latency, 
    io_stall_write_ms / NULLIF(num_of_writes, 0) avg_write_latency,
    physical_name [file_name], 
    io_stall / NULLIF(num_of_reads + num_of_writes, 0) avg_total_latency
FROM    
        sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs 
    JOIN sys.master_files AS mf 
                ON vfs.database_id = mf.database_id AND vfs.FILE_ID = mf.FILE_ID 
ORDER BY 
        avg_total_latency DESC;



--Shortterm Files Stalls looking for < 10 msMS

DECLARE @Reset bit = 0;

--Reset the collection in tempdb 
--DECLARE @Reset bit = 1;

        
IF NOT EXISTS (SELECT NULL FROM tempdb.sys.objects 
WHERE name LIKE '%#fileStats%')  
        SET @Reset = 1;  -- force a reset

IF @Reset = 1 BEGIN 
        IF EXISTS (SELECT NULL FROM tempdb.sys.objects 
        WHERE name LIKE '%#fileStats%')  
                DROP TABLE #fileStats;

        SELECT 
                database_id, 
                file_id, 
                num_of_reads, 
                num_of_bytes_read, 
                io_stall_read_ms, 
                num_of_writes, 
                num_of_bytes_written, 
                io_stall_write_ms, io_stall
        INTO #fileStats 
        FROM sys.dm_io_virtual_file_stats(NULL, NULL);
END

SELECT  
        DB_NAME(vfs.database_id) AS database_name, 
        --vfs.database_id , 
        vfs.FILE_ID , 
        (vfs.io_stall_read_ms - history.io_stall_read_ms)
         / NULLIF((vfs.num_of_reads - history.num_of_reads), 0) avg_read_latency,
        (vfs.io_stall_write_ms - history.io_stall_write_ms)
         / NULLIF((vfs.num_of_writes - history.num_of_writes), 0) AS avg_write_latency ,
        mf.physical_name 
FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs 
                JOIN sys.master_files AS mf 
                        ON vfs.database_id = mf.database_id AND vfs.FILE_ID = mf.FILE_ID 
                RIGHT OUTER JOIN #fileStats history 
                        ON history.database_id = vfs.database_id AND history.file_id = vfs.file_id
ORDER BY avg_write_latency DESC;