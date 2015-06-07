-- Script: Get-ServiceAccount.sql
-- Description: Return the service accounts running the major database services.
-- Reference: http://stackoverflow.com/questions/4440141/differences-between-xp-instance-regread-and-xp-regread
-- TODO: Add privilege checks.

DECLARE       @DBEngineLogin		VARCHAR(100)
DECLARE       @AgentLogin			VARCHAR(100)
DECLARE       @BrowserLogin			VARCHAR(100)
DECLARE       @WriterLogin          VARCHAR(100)
DECLARE		  @AnalysisLogin		VARCHAR(100)
DECLARE		  @ReportLogin			VARCHAR(100)
DECLARE		  @IntegrationLogin		VARCHAR(100)
	
 EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\MSSQLServer',
              @value_name   = N'ObjectName',
              @value        = @DBEngineLogin OUTPUT

EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\SQLServerAgent',
              @value_name   = N'ObjectName',
              @value        = @AgentLogin OUTPUT

EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\SQLBrowser',
              @value_name   = N'ObjectName',
              @value        = @BrowserLogin OUTPUT

EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\SQLWriter',
              @value_name   = N'ObjectName',
              @value        = @WriterLogin OUTPUT

EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\MSOLAP$STANDARD',
              @value_name   = N'ObjectName',
              @value        = @AnalysisLogin OUTPUT

EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\ReportServer$STANDARD',
              @value_name   = N'ObjectName',
              @value        = @ReportLogin OUTPUT

EXECUTE       master.dbo.xp_instance_regread
              @rootkey      = N'HKEY_LOCAL_MACHINE',
              @key          = N'SYSTEM\CurrentControlSet\Services\MsDtsServer110',
              @value_name   = N'ObjectName',
              @value        = @IntegrationLogin OUTPUT

SELECT	[DBEngineLogin] = @DBEngineLogin, 
	[AgentLogin] = @AgentLogin,
	[BrowserLogin] = @BrowserLogin,
	[WriterLogin] = @WriterLogin,
	[AnalysisLogin] = @AnalysisLogin,
	[ReportLogin] = @ReportLogin,
	[IntegrationLogin] = @IntegrationLogin

GO