-- Script: Get-QueryHistory.sql
-- Description: Get query history / cache plans.  This requires sysadmin
-- privileges.
-- Reference: https://msdn.microsoft.com/en-us/library/ms187404.aspx

SELECT t.[text]
FROM sys.dm_exec_cached_plans AS p
CROSS APPLY sys.dm_exec_sql_text(p.plan_handle) AS t