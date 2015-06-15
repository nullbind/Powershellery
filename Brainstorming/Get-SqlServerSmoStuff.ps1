# Scott's smo notes:

# SDK SMO API Examples
# Description:  This file contains examples of how to used the smo api for standard tasks.
# Requirements:  The SMO libraries install with SQL Server.  They are listed below.
# C:\Program Files\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.Smo.dll
# C:\Program Files\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.SmoExtended.dll
# References:
# https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.server.aspx
# Notes: The functions all seem to return results as a datatable object - super cool

# Import SMO Libs
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended")| Out-Null

# Authenticate - Integrated Windows Auth - works
# $srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') "server\instance" 


# Authenticate - SQL Server authentication - mixed mode - works
#$srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') "10.1.1.1"
#$srv.ConnectionContext.LoginSecure=$false; 
#$srv.ConnectionContext.set_Login("user"); 
#$srv.ConnectionContext.set_Password("password")  
#$srv.Information

# Authenticate - Windows Domain authentication - not working, not sure if libs/sql provider supports this
#[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
#[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended")| out-null
#$srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') "10.1.1.1"
#$srv.ConnectionContext.LoginSecure=$false; 
#$MyUser ="domain\user"
#$MyPass = ConvertTo-SecureString 'password' -AsPlainText -Force
#$MyCred = New-Object System.Management.Automation.PSCredential ($MyUser, $MyPass)
#$userName = $MyCred.UserName 
#$srv.ConnectionContext.set_Login($userName)
#$srv.ConnectionContext.set_SecurePassword($MyCred.Password)
#$srv.Information


# Get version / server information
$srv.Information
$srv.Name
$srv.NetName
$srv.ComputerNamePhysicalNetBIOS
$srv.Version
$srv.VersionMajor
$srv.VersionMinor
$srv.Edition
$srv.EngineEdition
$srv.OSVersion
$srv.DomainInstanceName
$srv.DomainName
$srv.SqlDomainGroup


# Get service informaiton
$srv.ServiceName
$srv.ServiceAccount
$srv.ServiceStartMode
$srv.BrowserServiceAccount


# Get state information
$srv.State
$srv.Status


# Get listener information
$srv.NamedPipesEnabled
$srv.TcpEnabled


# Get directory path information
$srv.RootDirectory
$srv.InstallDataDirectory
$srv.InstallSharedDirectory
$srv.ErrorLogPath
$srv.MasterDBLogPath
$srv.MasterDBPath
$srv.BackupDirectory


# Logins, roles, and privileges
$srv.ConnectionContext
$srv.LoginMode
$srv.Logins
$srv.Roles
$srv.EnumServerPermissions()


# windows account asscoiated with db
$srv.EnumWindowsUserInfo()
$srv.EnumWindowsUserInfo() | select "account name"
$srv.EnumWindowsDomainGroups()
$srv.EnumWindowsGroupInfo("Domain Admins")


# Credentials / proxy_account
$srv.Credentials
$srv.ProxyAccount


# Databse information
$srv.Databases


# Other settings
$srv.Configuration
$srv.Settings
$srv.Properties
$srv.Mail
$srv.MailProfile
$srv.Triggers
$srv.AuditLevel
$srv.Audits
$srv.LinkedServers
$srv.Endpoints
$srv.JobServer
$srv.EnumServerAttributes()


# cluster / mirror information
$srv.IsClustered
$srv.ClusterName
$srv.EnumClusterMembersState
$srv.EnumClusterSubnets
$srv.EnumDatabaseMirrorWitnessRoles()


$srv.ActiveDirectory

#get data
#$srv = new-object Microsoft.SqlServer.Management.Smo.Server("(local)")
#$db = $srv.Databases.Item("AdventureWorks2012")
#$tb = $db.Tables.Item("Person", "Person")
#$col = $tb.Columns.Item("LastName")
#$col.Nullable = $TRUE
#$col.Alter()


# server enumeration
# https://msdn.microsoft.com/en-us/library/ms210366.aspx
$srv.PingSqlServerVersion("server\Standard")
$srv.PingSqlServerVersion("1.1.1.1",'sa','password')
$SQLSvr = [Microsoft.SqlServer.Management.Smo.SmoApplication]::EnumAvailableSqlServers($true); $SQLSvr | Out-GridView

