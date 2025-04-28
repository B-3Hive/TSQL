
/*  Identify Plans Only Used Once */

SELECT text, cp.objtype, cp.size_in_bytes
 FROM sys.dm_exec_cached_plans AS cp
 CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
 WHERE cp.cacheobjtype = N'Compiled Plan'
 AND cp.objtype IN(N'Adhoc', N'Prepared')
 AND cp.usecounts = 1
 ORDER BY cp.size_in_bytes DESC
 OPTION (RECOMPILE);


/*======================================================================*/

/*

This script measures the amount of memory used by the single use plans and compare them 
to the size of the entire plan cache.

NOTE:
if you see more than 50 percent of your plan cache 
being taken up by single use plans you are more than 
likely going to want to examine the use of the optimize for ad-hoc workloads option

*/

SELECT objtype AS [CacheType]
        , count_big(*) AS [Total Plans]
        , sum(cast(size_in_bytes as decimal(18,2)))/1024/1024 AS [Total MBs]
        , avg(usecounts) AS [Avg Use Count]
        , sum(cast((CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END) as decimal(18,2)))/1024/1024 AS [Total MBs - USE Count 1]
        , sum(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS [Total Plans - USE Count 1]
FROM sys.dm_exec_cached_plans
GROUP BY objtype
ORDER BY [Total MBs - USE Count 1] DESC

/*======================================================================*/

/* Plans that are missing indexes  */

;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
 SELECT dec.usecounts, dec.refcounts, dec.objtype
       ,dec.cacheobjtype, des.dbid, des.text     
       ,deq.query_plan
 FROM sys.dm_exec_cached_plans AS dec
      CROSS APPLY sys.dm_exec_sql_text(dec.plan_handle) AS des
      CROSS APPLY sys.dm_exec_query_plan(dec.plan_handle) AS deq
 WHERE
 deq.query_plan.exist(N'/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes/MissingIndexGroup') <> 0
 ORDER BY dec.usecounts DESC

/*======================================================================*/

/*Find Implicit Conversions  

Conversion warning plans indicate a mismatch in the datatype being used in the query to 
the datatype defined in the database. The most common example of such would be the use of an integer value in the query for a column defined as VARCHAR or NVARCHAR.

If you find that you are having a lot of implicit conversions inside of your query plans, then you're going to want to take one of two corrective steps: 
change the column datatype or change your code. 


*/


;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
 SELECT
 cp.query_hash,cp.query_plan_hash,
 ConvertIssue= operators.value('@ConvertIssue', 'nvarchar(250)'),
 Expression= operators.value('@Expression', 'nvarchar(250)'), qp.query_plan
 FROM sys.dm_exec_query_stats cp
 CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
 CROSS APPLY query_plan.nodes('//Warnings/PlanAffectingConvert') rel(operators)



/*======================================================================*/




/*
Find plans that have clustered index seeks and key lookups

Key lookups are one of the plan operators I tend to focus on when examining a 
plan as they are something that can be easily remedied by adjusting indexes

With this information we can look at the indexing on our tables and determine 
if a change to a non-clustered index to make it covering is warranted to improve performance or not


*/

;WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
 SELECT
 cp.query_hash,cp.query_plan_hash,
 PhysicalOperator= operators.value('@PhysicalOp','nvarchar(50)'),
 LogicalOp= operators.value('@LogicalOp','nvarchar(50)'),
 AvgRowSize= operators.value('@AvgRowSize','nvarchar(50)'),
 EstimateCPU= operators.value('@EstimateCPU','nvarchar(50)'),
 EstimateIO= operators.value('@EstimateIO','nvarchar(50)'),
 EstimateRebinds= operators.value('@EstimateRebinds','nvarchar(50)'),
 EstimateRewinds= operators.value('@EstimateRewinds','nvarchar(50)'),
 EstimateRows= operators.value('@EstimateRows','nvarchar(50)'),
 Parallel= operators.value('@Parallel','nvarchar(50)'),
 NodeId= operators.value('@NodeId','nvarchar(50)'),
 EstimatedTotalSubtreeCost= operators.value('@EstimatedTotalSubtreeCost','nvarchar(50)')
 FROM sys.dm_exec_query_stats cp
 CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
 CROSS APPLY query_plan.nodes('//RelOp') rel(operators)


/*======================================================================*/


/* FIND SIMILAR PLANS */


SELECT st.text, qs.query_hash
 FROM sys.dm_exec_query_stats qs
 CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
 WHERE st.text = 'SELECT P.FirstName, P.LastName
 FROM Person.Person AS P
 WHERE P.FirstName = ''Amanda''
 'OR st.text = 'SELECT P.FirstName, P.LastName
 FROM Person.Person AS P
 WHERE P.FirstName = ''Logan'' '
 GO


-- THE RESULTING QUERY_HASH VALUE ALLOWS US TO LOOK AT THE PLAN CACHE


SELECT COUNT(*) AS [Count], query_stats.query_hash,
     query_stats.statement_text AS [Text]
 FROM
     (SELECT QS.*,
     SUBSTRING(ST.text,(QS.statement_start_offset/2) + 1,
     ((CASE statement_end_offset
         WHEN -1 THEN DATALENGTH(ST.text)
         ELSE QS.statement_end_offset END
             - QS.statement_start_offset)/2) + 1) AS statement_text
      FROM sys.dm_exec_query_stats AS QS
      CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST) as query_stats
 GROUP BY query_stats.query_hash, query_stats.statement_text
 ORDER BY 1 DESC



/* 
This allows for us to see the frequency for which some statements are being executed 
over time. If you see that you have many statements with similar query hash and query 
plan hash values then you'll want to consider creating one parameterized statement to 
be used instead.
*/

