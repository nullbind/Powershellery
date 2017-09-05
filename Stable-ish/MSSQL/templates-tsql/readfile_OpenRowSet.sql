-- select the contents of a file using openrowset
-- note: ad-hoc queries have to be enabled
-- https://docs.microsoft.com/en-us/sql/t-sql/functions/openrowset-transact-sql
SELECT cast(BulkColumn as varchar(max)) as Document FROM OPENROWSET(BULK N'C:\windows\temp\blah.txt', SINGLE_BLOB) AS Document
