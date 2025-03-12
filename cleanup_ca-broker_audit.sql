-- @StartDate determines how many rows are persisted (based on timestamp)

DECLARE @StartDate DATETIME

-- automatic start date: keeps 3 full months of data (starting from 1 day of the month)
set @StartDate = DATEADD(month, -3, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0))

-- uncomment this line to set a specific start day
--set @StartDate = '2022-06-01'

-- abort transactions on any errors
SET XACT_ABORT ON;

-- create schema if not exists

IF (SCHEMA_ID('maintenance') IS NULL) 
BEGIN
    EXEC ('CREATE SCHEMA [maintenance] AUTHORIZATION [dbo]')
END

-- create a backup table for CA_BROKER_AuditEntries if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'CA_BROKER_AuditEntries')
 BEGIN
    
    CREATE TABLE [maintenance].[CA_BROKER_AuditEntries](
        [Id] [nvarchar](450) NOT NULL,
        [TaskId] [nvarchar](450) NULL,
        [ActionType] [nvarchar](200) NOT NULL,
        [StepExecution] [nvarchar](200) NULL,
        [Status] [nvarchar](200) NULL,
        [DataDiff] [nvarchar](max) NULL,
        [Username] [nvarchar](max) NULL,
        [Comment] [nvarchar](max) NULL,
        [Timestamp] [datetime2](7) NOT NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]



    CREATE NONCLUSTERED INDEX [IX_CA_BROKER_AuditEntries_Timestamp] ON [maintenance].[CA_BROKER_AuditEntries]
    (
        [TimeStamp] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

 END

 -- transfer data to the maintenance table

 begin tran

DECLARE @EndDate DATE
set @EndDate = cast(GETDATE() as date)

while @StartDate <= @EndDate
begin

    PRINT 'Loop: day ' + CAST(@StartDate as nvarchar(100))

    insert into [maintenance].[CA_BROKER_AuditEntries] (
            [Id],
            [TaskId],
            [ActionType],
            [StepExecution],
            [Status],
            [DataDiff],
            [Username],
            [Comment],
            [Timestamp]
        )
    select a.[Id],
            a.[TaskId],
            a.[ActionType],
            a.[StepExecution],
            a.[Status],
            a.[DataDiff],
            a.[Username],
            a.[Comment],
            a.[Timestamp]
    from [corporateActions_broker].[AuditEntries] a (NOLOCK)
    inner join [corporateActions_broker].Tasks t (NOLOCK)
    on t.Id = a.TaskId
    where cast (a.[TimeStamp] as date) = @StartDate
        and t.[Status] != 'ExecutionCompleted'

    set @StartDate = DATEADD(day, 1, @StartDate)
end
PRINT 'Data transfered to the maintenance table'

-- truncate the original table

truncate TABLE [corporateActions_broker].[AuditEntries]

-- transfer data back

insert into [corporateActions_broker].[AuditEntries] (
        [Id],
        [TaskId],
        [ActionType],
        [StepExecution],
        [Status],
        [DataDiff],
        [Username],
        [Comment],
        [Timestamp]
    )
    select [Id],
        [TaskId],
        [ActionType],
        [StepExecution],
        [Status],
        [DataDiff],
        [Username],
        [Comment],
        [Timestamp]
    from [maintenance].[CA_BROKER_AuditEntries] (NOLOCK)

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[CA_BROKER_AuditEntries]

commit