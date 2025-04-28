--Calculating the percentage of I/O by Drive
----------------------------------------------------
With g as
(select db_name(mf.database_id) as database_name, mf.physical_name, 
left(mf.physical_name, 1) as drive_letter, 
vfs.num_of_writes, 
vfs.num_of_bytes_written as BYTESWRITTEN, 
vfs.io_stall_write_ms, 
mf.type_desc, vfs.num_of_reads, vfs.num_of_bytes_read, vfs.io_stall_read_ms,
vfs.io_stall, vfs.size_on_disk_bytes
from sys.master_files mf
join sys.dm_io_virtual_file_stats(NULL, NULL) vfs
on mf.database_id=vfs.database_id and mf.file_id=vfs.file_id
--order by vfs.num_of_bytes_written desc)
)
select database_name,drive_letter, BYTESWRITTEN,
Percentage = RTRIM(CONVERT(DECIMAL(5,2),
BYTESWRITTEN*100.0/(SELECT SUM(BYTESWRITTEN) FROM g))) 
--where drive_letter='R' <-- You can put specify drive )))
+ '%'
from g --where drive_letter='R'
order by BYTESWRITTEN desc
-------------------------------------------------------
