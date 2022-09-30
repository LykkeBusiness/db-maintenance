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

-- create a backup table for BlobData if not exists

IF NOT EXISTS (SELECT 0 
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'maintenance' 
           AND TABLE_NAME = 'BlobData')
 BEGIN
    
    CREATE TABLE [maintenance].[BlobData](
        [BlobKey] [nvarchar](128) NOT NULL,
        [Data] [nvarchar](max) NULL,
        [Timestamp] [datetime] NULL
    ) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]


    CREATE NONCLUSTERED INDEX [IX_BlobData_Timestamp] ON [maintenance].[BlobData]
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

    insert into [maintenance].[BlobData] (
        [BlobKey],
        [Data],
        [Timestamp]
    )
    select [BlobKey],
        [Data],
        [Timestamp]
    from [bookkeeper].[BlobData] (NOLOCK)
    where cast ([TimeStamp] as date) = @StartDate

    set @StartDate = DATEADD(day, 1, @StartDate)
end
PRINT 'Data transfered to the maintenance table'

-- truncate the original table

truncate TABLE [bookkeeper].[BlobData]

-- transfer data back

insert into [bookkeeper].[BlobData] (
        [BlobKey],
        [Data],
        [Timestamp]
    )
    select [BlobKey],
        [Data],
        [Timestamp]
    from [maintenance].[BlobData] (NOLOCK)

PRINT 'Data transfered back to the original table'

-- truncate maintenance

truncate TABLE [maintenance].[BlobData]

commit