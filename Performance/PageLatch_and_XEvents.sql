Select session_id,
wait_type,
wait_duration_ms,
blocking_session_id,
resource_description,
      ResourceType = Case
When Cast(Right(resource_description, Len(resource_description) - Charindex(':', resource_description, 3)) As Int) - 1 % 8088 = 0 Then 'Is PFS Page'
            When Cast(Right(resource_description, Len(resource_description) - Charindex(':', resource_description, 3)) As Int) - 2 % 511232 = 0 Then 'Is GAM Page'
            When Cast(Right(resource_description, Len(resource_description) - Charindex(':', resource_description, 3)) As Int) - 3 % 511232 = 0 Then 'Is SGAM Page'
            Else 'Is Not PFS, GAM, or SGAM page' 
            End
From sys.dm_os_waiting_tasks
Where wait_type Like 'PAGE%LATCH_%'
And resource_description Like '2:%'


CREATE EVENT SESSION [latch] ON SERVER 
ADD EVENT sqlserver.latch_suspend_begin(
    ACTION(package0.callstack))
ADD TARGET package0.event file(SET filename=N'D:\temp\latch.xel')
WITH (MAX_MEMORY=262144 KB,EVENT__ 
RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=PER_CPU,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

•	Start the xevent session with the following command.

ALTER EVENT SESSION [latch] ON SERVER STATE = start

Let the xevent session run for several minutes while the latch contention is occurring. If you notice any performance degradation that is not acceptable then you can run the following command to stop it.

                ALTER EVENT SESSION [latch] ON SERVER STATE = stop

•	Collect a mini dump by running DBCC STACKDUMP

•	Next turn on trace flag 4406. This is the trace flag that enables the additional fix that was included in update.

DBCC TRACEON(4406, -1)

•	Let the pssdiag run with trace flag 4406 enabled for 15 minutes. 


Here is the checklist of what we need uploaded to the workspace afterwards.

•	Pssdiag output
•	Xevents, this should be in the pssdiag output if you change the file path.
•	The mini dump we collected. This will be in the default dump directory, which is usually the same as the errorlog directory.

Here is the workspace URL.





