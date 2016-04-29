-- Script: Get-ServiceAccount.sql
-- Description: Return the service accounts running the major database services.
-- Reference: http://stackoverflow.com/questions/4440141/differences-between-xp-instance-regread-and-xp-regread
-- TODO: Add privilege checks.

-- Setup variables
DECLARE		@SQLServerInstance	VARCHAR(250)  
DECLARE		@MSOLAPInstance		VARCHAR(250) 
DECLARE		@ReportInstance 	VARCHAR(250) 
DECLARE		@AgentInstance	 	VARCHAR(250) 
DECLARE		@DBEngineLogin		VARCHAR(100)
DECLARE		@AgentLogin		VARCHAR(100)
DECLARE		@BrowserLogin		VARCHAR(100)
DECLARE     	@WriterLogin		VARCHAR(100)
DECLARE		@AnalysisLogin		VARCHAR(100)
DECLARE		@ReportLogin		VARCHAR(100)
DECLARE		@IntegrationLogin	VARCHAR(100)

-- Get SQL Server Service Name Path 
if @@SERVICENAME = 'MSSQLSERVER'
	BEGIN											
	set @SQLServerInstance = 'SYSTEM\CurrentControlSet\Services\MSSQLSERVER'
	END						
ELSE
	BEGIN
	set @SQLServerInstance = 'SYSTEM\CurrentControlSet\Services\MSSQL$' + cast(@@SERVICENAME as varchar(250))	
	set @MSOLAPInstance = 'SYSTEM\CurrentControlSet\Services\MSOLAP$' + cast(@@SERVICENAME as varchar(250))		
	set @ReportInstance = 'SYSTEM\CurrentControlSet\Services\ReportServer$' + cast(@@SERVICENAME as varchar(250))
	set @AgentInstance = 'SYSTEM\CurrentControlSet\Services\SQLAgent$' + cast(@@SERVICENAME as varchar(250))							
	END

-- Get SQL Server - Calculated
EXECUTE		master.dbo.xp_instance_regread  
		N'HKEY_LOCAL_MACHINE', @SQLServerInstance,  
		N'ObjectName',@DBEngineLogin OUTPUT

-- Get SQL Server Agent - Calculated
EXECUTE		master.dbo.xp_instance_regread  
		N'HKEY_LOCAL_MACHINE', @AgentInstance,  
		N'ObjectName',@AgentLogin OUTPUT

-- Get SQL Server Browser - Static Location
EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\SQLBrowser',
              @value_name   = N'ObjectName',
              @value        = @BrowserLogin OUTPUT

-- Get SQL Server Writer - Static Location
EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\SQLWriter',
              @value_name   = N'ObjectName',
              @value        = @WriterLogin OUTPUT

-- Get MSOLAP - Calculated
EXECUTE		master.dbo.xp_instance_regread  
		N'HKEY_LOCAL_MACHINE', @MSOLAPInstance,  
		N'ObjectName',@AnalysisLogin OUTPUT

-- Get Reporting - Calculated
EXECUTE		master.dbo.xp_instance_regread  
		N'HKEY_LOCAL_MACHINE', @ReportInstance,  
		N'ObjectName',@ReportLogin OUTPUT

-- Get SQL Server DTS Server
EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\MsDtsServer110',
              @value_name   = N'ObjectName',
              @value        = @IntegrationLogin OUTPUT

-- Dislpay results
SELECT		[DBEngineLogin] = @DBEngineLogin, 
		[BrowserLogin] = @BrowserLogin,
		[AgentLogin] = @AgentLogin,
		[WriterLogin] = @WriterLogin,
		[AnalysisLogin] = @AnalysisLogin,
		[ReportLogin] = @ReportLogin,
		[IntegrationLogin] = @IntegrationLogin
GO
