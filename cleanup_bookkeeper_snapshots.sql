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

-- create a backup table for ReferentialDataSnapshots if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'ReferentialDataSnapshots')
 BEGIN
    
    CREATE TABLE [maintenance].[ReferentialDataSnapshots](
	[OID] [bigint] NOT NULL,
	[TradingDay] [date] NOT NULL,
	[EventId] [nvarchar](64) NOT NULL,
	[Timestamp] [datetime] NOT NULL,
	[Key] [nvarchar](64) NOT NULL,
	[Value] [nvarchar](max) NOT NULL,
	[Status] [nvarchar](32) NOT NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]



    CREATE NONCLUSTERED INDEX [IX_ReferentialDataSnapshots_Timestamp] ON [maintenance].[ReferentialDataSnapshots]
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

    insert into [maintenance].[ReferentialDataSnapshots] (
            [OID],
            [TradingDay],
            [EventId],
            [Timestamp],
            [Key],
            [Value],
            [Status]
        )
    select [OID],
        [TradingDay],
        [EventId],
        [Timestamp],
        [Key],
        [Value],
        [Status]
    from [bookkeeper].[ReferentialDataSnapshots] (NOLOCK)
    where cast ([TimeStamp] as date) = @StartDate

    set @StartDate = DATEADD(day, 1, @StartDate)
end
PRINT 'Data transfered to the maintenance table'

-- truncate the original table

truncate TABLE [bookkeeper].[ReferentialDataSnapshots]

-- transfer data back
SET IDENTITY_INSERT [bookkeeper].[ReferentialDataSnapshots] ON;

insert into [bookkeeper].[ReferentialDataSnapshots] (
        [OID],
        [TradingDay],
        [EventId],
        [Timestamp],
        [Key],
        [Value],
        [Status]
    )
    select [OID],
        [TradingDay],
        [EventId],
        [Timestamp],
        [Key],
        [Value],
        [Status]
    from [maintenance].[ReferentialDataSnapshots] (NOLOCK)

SET IDENTITY_INSERT [bookkeeper].[ReferentialDataSnapshots] OFF;

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[ReferentialDataSnapshots]

commit