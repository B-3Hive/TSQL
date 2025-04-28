USE [master]
GO
/****** Object:  StoredProcedure [dbo].[sp_GenerateIndexes]    Script Date: 08/18/2009 13:52:05 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE [dbo].[sp_GenerateIndexes]
(
  @TableName  varchar(255),
  @Stats      char(1) = 'Y',
  @ListOnly   char(1) = 'N',
  @IndexStats char(1) = 'Y'
)
as
---------------------------------------------------------------------------------------------------

--               
-- Description:  This procedure is used to generate SQL statements that can drop and recreate
--               all indexes on a specified table.  This procedure will also generate SQL
--               statements to create "theoretical" indexes which are based on the statistics
--               objects that exist for that table.  If you choose to implement these indexes,
--               remember to also drop the original statistics object.
--               
--               The primary use of this table is to allow DBA's to capture the code to recreate
--               indexes on a table while they experiment with different index configurations.
--               
---------------------------------------------------------------------------------------------------
set nocount on


---------------------------------------------------------------------
-- Declare and initialize local variables                          --
---------------------------------------------------------------------

declare @IndexName       sysname,
        @ObjectID        int,
        @IndexID         int,
        @IndexKeys       varchar(2500),
        @IndexFillFactor int,
        @IndexStatus     int,
        @Count           int, 
        @CurrentKey      sysname,
        @Output          varchar(2000),
        @SQLVersion      char(1)

  
select  @IndexName       = '',
        @IndexKeys       = '',
        @IndexFillFactor = 0,
        @IndexStatus     = 0,
        @Output          = '',
        @Count           = 0,
        @CurrentKey      = '',
        @SQLVersion      = convert(char(1),serverproperty('ProductVersion'))


---------------------------------------------------------------------
-- Validate input parameters                                       --
---------------------------------------------------------------------

-- Convert to uppercase to accomodate case sensitive environments
select @Stats      = upper(@Stats),
       @ListOnly   = upper(@ListOnly),
       @IndexStats = upper(@IndexStats)

-- Handle invalid user input
IF (@Stats      <> 'Y') select @Stats      = 'N'
IF (@ListOnly   <> 'N') select @ListOnly   = 'Y'
IF (@IndexStats <> 'Y') select @IndexStats = 'N'


-- If the specified table does not exist, display warning and exit
select @ObjectID = object_id(@TableName)

IF (@ObjectID IS NULL)
BEGIN
  select @Output = 'The specified table (' + @TableName + ') does not exist in the current database.'
  print  @Output
  return -1
END


---------------------------------------------------------------------
-- M A I N   P R O C E S S I N G                                   --
---------------------------------------------------------------------
--                                                                 --
-- Process Indexes for the specified table                         --
--                                                                 --
-- Prepare work table                                              --
--                                                                 --
-- Generate sql code to create/drop indexes                        --
--                                                                 --
-- Produce table report detailing existing indexes                 --
--                                                                 --
---------------------------------------------------------------------


---------------------------------------------------------------------
-- Process Indexes for the specified table                         --
---------------------------------------------------------------------

DECLARE Index_Cursor CURSOR FAST_FORWARD FOR
 SELECT indid, 
        [name], 
        status,
        case(origfillfactor) when 0 then 100 else origfillfactor end
   FROM sysindexes
  WHERE id = @ObjectID 
    AND indid between 1  and 254 
  ORDER BY indid

OPEN Index_Cursor

FETCH NEXT
 FROM Index_Cursor
 INTO @IndexID, 
      @IndexName, 
      @IndexStatus,
      @IndexFillFactor

-- If no indexes found, raise error and exit
IF (@@FETCH_STATUS = -1)
BEGIN
  select @Output = 'The specified table (' + @TableName + ') does not have any indexes.'
  print  @Output
  close      Index_Cursor
  deallocate Index_Cursor
  return -1
END


-- Create temp table
IF (object_id('tempdb..#IndexTable') IS NOT NULL)
  drop table #IndexTable

create table #IndexTable
(
  TableName       sysname NOT NULL,
  IndexName       sysname NOT NULL,
  IndexID         int     NOT NULL,
  IndexStatus     int,
  IndexKeys       varchar(2500)NOT NULL,
  IndexFillFactor tinyint NOT NULL
)

WHILE (@@FETCH_STATUS <> -1)
BEGIN
  -- Determine Index Keys
  select @IndexKeys  = index_col(@TableName, @IndexID, 1) + 
                       case (indexkey_property(object_id(@TableName),@IndexID,1,N'IsDescending'))
                         when 1 then ' DESC' 
                         else '' 
                       end ,
         @Count      = 2, 
         @CurrentKey = index_col(@TableName, @IndexID, 2) + 
                       case (indexkey_property(object_id(@TableName),@IndexID,1,N'IsDescending'))
                         when 1 then ' DESC' 
                         else '' 
                       end


  WHILE (@CurrentKey IS NOT NULL)
  BEGIN
    select @IndexKeys = @IndexKeys + ', ' + @CurrentKey, 
           @Count     = @Count + 1

    select @CurrentKey = index_col(@TableName, @IndexID, @Count) + 
                         case (indexkey_property(object_id(@TableName),@IndexID,1,N'IsDescending'))
                           when 1 then ' DESC' 
                           else ''
                         end
  END


  -- Populate Temp Table with index row
  insert #IndexTable (TableName,  IndexName,  IndexID,  IndexStatus,  IndexKeys,  IndexFillFactor)
  values             (@TableName, @IndexName, @IndexID, @IndexStatus, @IndexKeys, @IndexFillFactor)

  -- Next index
  FETCH NEXT
  FROM Index_Cursor
  INTO @IndexID, 
       @IndexName, 
       @IndexStatus,
       @IndexFillFactor
  
END


---------------------------------------------------------------------
-- Prepare work table                                              --
---------------------------------------------------------------------

select 'TableName'   = it.TableName,
       'IndexName'   = it.IndexName,
       'ID'          = it.IndexID,
       'Clust'       = convert(varchar(5),case 
                                            when (IndexStatus & 16)<>0 then 'YES' 
                                            else 'no' 
                                          end),
       'Uniq'        = case (indexproperty(object_id(it.TableName),it.IndexName,'IsUnique'))
                         when (1) then 'YES'
                         else 'no'
                       end,
       'PK'          = case (select xtype from sysobjects where parent_obj = object_id(it.TableName) and name = it.IndexName) 
                         when ('PK') then 'YES'
                         else 'no'
                       end,
       'IgDup'       = case (select sum(si.status & 1) from sysindexes SI where si.name = it.IndexName)
                         when 0 then 'no' 
                         else 'YES' 
                       end ,
       'Stat'        = case (indexproperty(object_id(it.TableName),it.IndexName,'IsStatistics')) 
                         when (1) then 'YES'
                         else 'no'
                       end,
       'Hyp'         = case (indexproperty(object_id(it.TableName),it.IndexName,'IsHypothetical')) 
                         when (1) then 'YES'
                         else 'no'
                       end,
       'Fill'        = convert(tinyint,IndexFillFactor),
       -- 2005 specific 
       'PadIdx'      = case (indexproperty(object_id(it.TableName),it.IndexName,'IsPadIndex')) 
                         when (0) then (case (@SQLVersion) when '8' then 'n/a' else 'no' end)
                         when (1) then (case (@SQLVersion) when '8' then 'n/a' else 'YES' end)
                         else '??'
                       end,
       -- 2005 specific 
       'RowLk'       = case (indexproperty(object_id(it.TableName),it.IndexName,'IsRowLockDisallowed')) 
                         when (0) then (case (@SQLVersion) when '8' then 'n/a' else 'YES' end)
                         when (1) then (case (@SQLVersion) when '8' then 'n/a' else 'no' end)
                         else '??'
                       end,
       -- 2005 specific 
       'PgLk'       = case (indexproperty(object_id(it.TableName),it.IndexName,'IsPageLockDisallowed')) 
                         when (0) then (case (@SQLVersion) when '8' then 'n/a' else 'YES' end)
                         when (1) then (case (@SQLVersion) when '8' then 'n/a' else 'no' end)
                         else '??'
                       end,
                       
       'ColumnNames' = left(IndexKeys,200)
    into #Indexes
    from #IndexTable it


---------------------------------------------------------------------
-- Generate sql code to create/drop indexes                        --
---------------------------------------------------------------------


IF (@ListOnly = 'N')
BEGIN
  print 'CREATES:'
  -- ADD PRIMARY KEYS
  select 'ALTER TABLE dbo.[' + rtrim(TableName) + '] WITH NOCHECK ' + 
         'ADD CONSTRAINT ' +
         '[' + IndexName + '] PRIMARY KEY ' +
         case (clust) 
           when 'YES' then 'CLUSTERED '
           else 'NONCLUSTERED'
         end + 
         '(' + ColumnNames + ')'  +
         case (@SQLVersion) 
           when '8' then (' WITH FILLFACTOR = ' + convert(char(3),Fill) + ' ON [PRIMARY]')
           else ' WITH (FILLFACTOR = '   + convert(char(3),Fill) 
             + ', IGNORE_DUP_KEY = '   + (case(IgDup) when 'YES' then 'ON' else 'OFF' end )
             + ', ALLOW_ROW_LOCKS = '  + (case(RowLk) when 'YES' then 'ON' else 'OFF' end )
             + ', ALLOW_PAGE_LOCKS = ' + (case(PgLk)  when 'YES' then 'ON' else 'OFF' end )
             + ') ON [PRIMARY]'
           end
             
    from #Indexes
   where Stat = 'no'
     and Hyp  = 'no'
     and PK   = 'YES'

  -- ADD INDEXES, CLUSTERED FIRST
  UNION
  select 'CREATE ' +
          case (uniq) 
            when 'YES' then 'UNIQUE '
            else ''
          end +
          case (clust) 
            when 'YES' then 'CLUSTERED '
            else ''
          end +
         'INDEX ' +
         '[' + IndexName + '] ' +
         'ON dbo.[' + rtrim(TableName) + '](' 
         + ColumnNames + ')' +
         case (@SQLVersion) 
           when '8' then (' WITH FILLFACTOR = ' + convert(char(3),Fill) + (case(IgDup) when 'YES' then ', IGNORE_DUP_KEY ' else '' end) + ' ON [PRIMARY]')
           else ' WITH (FILLFACTOR = '   + convert(char(3),Fill) 
             + ', IGNORE_DUP_KEY = '   + (case(IgDup) when 'YES' then 'ON' else 'OFF' end )
             + ', ALLOW_ROW_LOCKS = '  + (case(RowLk) when 'YES' then 'ON' else 'OFF' end )
             + ', ALLOW_PAGE_LOCKS = ' + (case(PgLk)  when 'YES' then 'ON' else 'OFF' end )
             + ') ON [PRIMARY]'
           end

    from #Indexes
   where Stat = 'no'
     and Hyp  = 'no'
     and PK   = 'no'

  
  
  -- DROP INDEXES, CLUSTERED LAST
  print ' '
  print ' '
  print 'DROPS: '
  select 'ALTER TABLE dbo.[' + rtrim(TableName) + '] ' + 
         'DROP CONSTRAINT ' +
         '[' + IndexName + ']   -- PRIMARY KEY CONSTRAINT, IF CLUSTERED DROP LAST'
    from #Indexes
   where Stat  = 'no'
     and Hyp   = 'no'
     and PK    = 'YES'
  UNION
  select 'DROP ' +
         'INDEX ' +
         'dbo.[' + rtrim(TableName) + '].' + 
         '[' + IndexName + '] '
    from #Indexes
   where Stat  = 'no'
     and Hyp   = 'no'
     and PK    = 'no'
     and Clust = 'no'
  UNION
  select 'DROP ' +
         'INDEX ' +
         'dbo.[' + rtrim(TableName) + '].' + 
         '[' + IndexName + '] ' + '    -- DROP CLUSTERED INDEX LAST'
    from #Indexes
   where Stat  = 'no'
     and Hyp   = 'no'
     and PK    = 'no'
     and Clust = 'YES'

  -- Theoretical Indexes based on statistic objects
  IF (@IndexStats = 'Y')
  BEGIN
    print ' '
    print ' '
    print 'THEORETICAL:'
    select 'CREATE ' +
            case (uniq) 
              when 'YES' then 'UNIQUE '
              else ''
             END +
            case (clust) 
              when 'YES' then 'CLUSTERED '
              else ''
            END +
           'INDEX ' +
           '[' + IndexName + '] ' +
           'ON dbo.[' + rtrim(TableName) + '](' + 
           ColumnNames + ')' +
         case (@SQLVersion) 
           when '8' then (' WITH FILLFACTOR = ' + convert(char(3),Fill) + (case(IgDup) when 'YES' then ', IGNORE_DUP_KEY ' else '' end) + ' ON [PRIMARY]')
           else ' WITH (FILLFACTOR = '   + convert(char(3),Fill) 
             + ', IGNORE_DUP_KEY = '   + (case(IgDup) when 'YES' then 'ON' else 'OFF' end )
             + ', ALLOW_ROW_LOCKS = '  + (case(RowLk) when 'YES' then 'ON' else 'OFF' end )
             + ', ALLOW_PAGE_LOCKS = ' + (case(PgLk)  when 'YES' then 'ON' else 'OFF' end )
             + ') ON [PRIMARY]'
           end
      from #Indexes
     where Stat = 'YES'
        or Hyp  = 'YES'
    print ' '
    print ' '
  END
END


---------------------------------------------------------------------
-- Produce table report detailing existing indexes                 --
---------------------------------------------------------------------

IF @Stats = 'Y'
BEGIN
  select 'TableName' = left(TableName, 40), 
         'IndexName' = left(IndexName, 50),
         ID,
         Clust,
         Uniq,
         PK,
         IgDup,
         Stat,
         Hyp,
         Fill,
         PadIdx,
--         RowLk,
--         PgLk,
         ColumnNames
    from #Indexes
END
ELSE
BEGIN
  select 'TableName' = left(TableName, 40), 
         'IndexName' = left(IndexName, 50),
         ID,
         Clust,
         Uniq,
         PK,
         IgDup,
         Stat,
         Hyp,
         Fill,
         PadIdx,
--         RowLk,
--         PgLk,
         ColumnNames
    from #Indexes
   where Stat = 'no'
END

close      Index_Cursor
deallocate Index_Cursor

