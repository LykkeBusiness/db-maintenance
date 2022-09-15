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

-- create a backup table for TradingEngineSnapshots if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'TradingEngineSnapshots')
 BEGIN

    CREATE TABLE [maintenance].[TradingEngineSnapshots](
        [OID] [bigint] IDENTITY(1,1) NOT NULL,
        [CorrelationId] [nvarchar](64) NOT NULL,
        [Timestamp] [datetime] NOT NULL,
        [Orders] [nvarchar](max) NOT NULL,
        [Positions] [nvarchar](max) NOT NULL,
        [AccountStats] [nvarchar](max) NOT NULL,
        [BestFxPrices] [nvarchar](max) NOT NULL,
        [BestPrices] [nvarchar](max) NOT NULL,
        [TradingDay] [datetime] NOT NULL,
        [Status] [nvarchar](32) NOT NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

    CREATE NONCLUSTERED INDEX [IX_TradingEngineSnapshots_Base] ON [maintenance].[TradingEngineSnapshots]
        (
            [Timestamp] ASC
        )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
 END

 -- transfer data to the maintenance table

 begin tran

set identity_insert [maintenance].[TradingEngineSnapshots] on
DECLARE @OldTableStartID bigint, @StartID bigint, @LastID bigint, @EndID bigint

select @OldTableStartID = min(OID)
from [dbo].[TradingEngineSnapshots] s (NOLOCK)
where s.[Timestamp] > @StartDate

select @StartID = isNull(max(OID),0) + 1
from [maintenance].[TradingEngineSnapshots]

set @StartID = IIF(@StartID>@OldTableStartID, @StartID, @OldTableStartID)

select @LastID = max(OID)
from [dbo].[TradingEngineSnapshots]

while @StartID < @LastID
begin
    set @EndID = @StartID + 10

    PRINT 'Loop: from ' + CAST(@StartID as nvarchar(100)) + ' to ' + CAST(@EndID as nvarchar(100))

    insert into [maintenance].[TradingEngineSnapshots] (
        [OID],
        [CorrelationId],
        [Timestamp],
        [Orders],
        [Positions],
        [AccountStats],
        [BestFxPrices],
        [BestPrices],
        [TradingDay],
        [Status]
    )
    select [OID],
        [CorrelationId],
        [Timestamp],
        [Orders],
        [Positions],
        [AccountStats],
        [BestFxPrices],
        [BestPrices],
        [TradingDay],
        [Status] 
    from [dbo].[TradingEngineSnapshots] (NOLOCK)
    where OID BETWEEN @StartID AND @EndId

    set @StartID = @EndID + 1
end
PRINT 'Data transfered to the maintenance table'
set identity_insert [maintenance].[TradingEngineSnapshots] off

-- truncate the original table

truncate TABLE [dbo].[TradingEngineSnapshots]

-- transfer data back

set identity_insert [dbo].[TradingEngineSnapshots] on
    insert into [dbo].[TradingEngineSnapshots] (
            [OID],
            [CorrelationId],
            [Timestamp],
            [Orders],
            [Positions],
            [AccountStats],
            [BestFxPrices],
            [BestPrices],
            [TradingDay],
            [Status]
        )
        select [OID],
            [CorrelationId],
            [Timestamp],
            [Orders],
            [Positions],
            [AccountStats],
            [BestFxPrices],
            [BestPrices],
            [TradingDay],
            [Status] 
        from [maintenance].[TradingEngineSnapshots] (NOLOCK)
    set identity_insert [dbo].[TradingEngineSnapshots] off

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[TradingEngineSnapshots]

commit