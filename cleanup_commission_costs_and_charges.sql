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

-- create a backup table for SharedCostsAndChangesCalculations if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'SharedCostsAndChangesCalculations')
 BEGIN
    
    CREATE TABLE [maintenance].[SharedCostsAndChangesCalculations](
        [Id] [nvarchar](128) NOT NULL,
        [Instrument] [nvarchar](100) NULL,
        [BaseAssetId] [nvarchar](64) NOT NULL,
        [TradingConditionId] [nvarchar](64) NOT NULL,
        [LegalEntity] [nvarchar](64) NOT NULL,
        [TimeStamp] [datetime] NOT NULL,
        [Volume] [float] NOT NULL,
        [Direction] [nvarchar](64) NOT NULL,
        [Data] [nvarchar](max) NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]


    CREATE NONCLUSTERED INDEX [IX_SharedCostsAndChangesCalculations_Timestamp] ON [maintenance].[SharedCostsAndChangesCalculations]
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

    insert into [maintenance].[SharedCostsAndChangesCalculations] (
        [Id],
        [Instrument],
        [BaseAssetId],
        [TradingConditionId],
        [LegalEntity],
        [TimeStamp],
        [Volume],
        [Direction],
        [Data]
    )
    select [Id],
        [Instrument],
        [BaseAssetId],
        [TradingConditionId],
        [LegalEntity],
        [TimeStamp],
        [Volume],
        [Direction],
        [Data]
    from [dbo].[SharedCostsAndChangesCalculations] (NOLOCK)
    where cast ([TimeStamp] as date) = @StartDate

    set @StartDate = DATEADD(day, 1, @StartDate)
end
PRINT 'Data transfered to the maintenance table'

-- truncate the original table

truncate TABLE [dbo].[SharedCostsAndChangesCalculations]

-- transfer data back

insert into [dbo].[SharedCostsAndChangesCalculations] (
        [Id],
        [Instrument],
        [BaseAssetId],
        [TradingConditionId],
        [LegalEntity],
        [TimeStamp],
        [Volume],
        [Direction],
        [Data]
    )
    select [Id],
        [Instrument],
        [BaseAssetId],
        [TradingConditionId],
        [LegalEntity],
        [TimeStamp],
        [Volume],
        [Direction],
        [Data]
    from [maintenance].[SharedCostsAndChangesCalculations] (NOLOCK)

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[SharedCostsAndChangesCalculations]

commit