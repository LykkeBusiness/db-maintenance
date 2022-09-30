# db-maintenance
Scripts for maintaining and cleaning up the db

## Scripts

###  get_big_tables.sql

Lists tables that use more than 1 gb of space.

### cleanup_[service]_table

Cleans up data for a specified table. All scripts persist data for the last 3 months to a table in the [maintenance] schema. This period can be altered by changing *@StartDate* parameter.

The script algorithm:

- Create the [maintenance] schema if not exists
- Create a table if not exists
- start a transaction
- Copy limited amount of data from the original table to the maintenance table, in batches (iteration is based on identity ID or on a timestamp)
- Truncate the original data table
- Copy data back from the maintenance table to the original table
- Truncate the maintenance table
- Commit

## How to use

- Determine the biggest tables by executing **get_big_tables.sql**
- Stop the corresponding services (usually mtcore, commission, bookkeeper)
- Execute the maintenance scripts one by one (do not try to do this in parallel)
- Check that the tables use less space by executing **get_big_tables.sql** script again

## Final thoughts

The scripts only release the logical space - the space taken on disc is not changed. You will need to use "shrink files" functionality of Sql Server to achieve that.

**get_db_space.sql** shows how much space is used and how much can be freed.