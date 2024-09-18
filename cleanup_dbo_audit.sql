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

-- create a backup table for AuditTrail if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'AuditTrail')
 BEGIN
    
    CREATE TABLE [maintenance].[AuditTrail](
        [Id] [int] NOT NULL,
        [Timestamp] [datetime2](7) NOT NULL,
        [CorrelationId] [nvarchar](max) NOT NULL,
        [UserName] [nvarchar](max) NOT NULL,
        [Type] [nvarchar](max) NOT NULL,
        [DataType] [nvarchar](max) NOT NULL,
        [DataReference] [nvarchar](max) NOT NULL,
        [DataDiff] [nvarchar](max) NOT NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]


    CREATE NONCLUSTERED INDEX [IX_AuditTrail_Timestamp] ON [maintenance].[AuditTrail]
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

    insert into [maintenance].[AuditTrail] (
        [Id],
        [Timestamp],
        [CorrelationId],
        [UserName],
        [Type],
        [DataType],
        [DataReference],
        [DataDiff]
    )
    select [Id],
        [Timestamp],
        [CorrelationId],
        [UserName],
        [Type],
        [DataType],
        [DataReference],
        [DataDiff]
    from [dbo].[AuditTrail] (NOLOCK)
    where cast ([TimeStamp] as date) = @StartDate

    set @StartDate = DATEADD(day, 1, @StartDate)
end
PRINT 'Data transfered to the maintenance table'

-- truncate the original table

truncate TABLE [dbo].[AuditTrail]

-- transfer data back

insert into [dbo].[AuditTrail] (
        [Id],
        [Timestamp],
        [CorrelationId],
        [UserName],
        [Type],
        [DataType],
        [DataReference],
        [DataDiff]
    )
    select [Id],
        [Timestamp],
        [CorrelationId],
        [UserName],
        [Type],
        [DataType],
        [DataReference],
        [DataDiff]
    from [maintenance].[AuditTrail] (NOLOCK)

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[AuditTrail]

commit