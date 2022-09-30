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

-- create a backup table for MarketOpenCloseEvents if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'MarketOpenCloseEvents')
 BEGIN

    CREATE TABLE [maintenance].[MarketOpenCloseEvents](
        [Id] [bigint] IDENTITY(1,1) NOT NULL,
        [Timestamp] [datetime] NOT NULL,
        [MarketId] [nvarchar](128) NOT NULL,
        [IsEnabled] [bit] NOT NULL,
        [TradingDay] [datetime] NOT NULL
    ) ON [PRIMARY]

    CREATE NONCLUSTERED INDEX [IX_MarketOpenCloseEvents_Base] ON [maintenance].[MarketOpenCloseEvents]
        (
            [Timestamp] ASC
        )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
 END

 -- transfer data to the maintenance table

 begin tran

set identity_insert [maintenance].[MarketOpenCloseEvents] on
DECLARE @OldTableStartID bigint, @StartID bigint, @LastID bigint, @EndID bigint

select @OldTableStartID = min(Id)
from [bookkeeper].[MarketOpenCloseEvents] s (NOLOCK)
where s.[Timestamp] > @StartDate

select @StartID = isNull(max(Id),0) + 1
from [maintenance].[MarketOpenCloseEvents]

set @StartID = IIF(@StartID>@OldTableStartID, @StartID, @OldTableStartID)

select @LastID = max(Id)
from [bookkeeper].[MarketOpenCloseEvents]

while @StartID < @LastID
begin
    set @EndID = @StartID + 1000

    PRINT 'Loop: from ' + CAST(@StartID as nvarchar(100)) + ' to ' + CAST(@EndID as nvarchar(100))

    insert into [maintenance].[MarketOpenCloseEvents] (
        [Id],
        [Timestamp],
        [MarketId],
        [IsEnabled],
        [TradingDay]
    )
    select [Id],
        [Timestamp],
        [MarketId],
        [IsEnabled],
        [TradingDay]
    from [bookkeeper].[MarketOpenCloseEvents] (NOLOCK)
    where Id BETWEEN @StartID AND @EndId

    set @StartID = @EndID + 1
end
PRINT 'Data transfered to the maintenance table'
set identity_insert [maintenance].[MarketOpenCloseEvents] off

-- truncate the original table

truncate TABLE [bookkeeper].[MarketOpenCloseEvents]

-- transfer data back

set identity_insert [bookkeeper].[MarketOpenCloseEvents] on
    insert into [bookkeeper].[MarketOpenCloseEvents] (
            [Id],
            [Timestamp],
            [MarketId],
            [IsEnabled],
            [TradingDay]
        )
        select [Id],
            [Timestamp],
            [MarketId],
            [IsEnabled],
            [TradingDay]
        from [maintenance].[MarketOpenCloseEvents] (NOLOCK)
    set identity_insert [bookkeeper].[MarketOpenCloseEvents] off

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[MarketOpenCloseEvents]

commit