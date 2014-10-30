 <#
	.SYNOPSIS
	This script can be used to query sql servers and view the results.

	.DESCRIPTION
	This script can be used to query sql servers and view the results.

	.EXAMPLE
	Below is the basic usage.
	PS C:\> Get-SqlServerSpSource -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -query "select name from master..sysdatabases"
    
    	.EXAMPLE
	Below is the basic usage.
	PS C:\> Get-SqlServerSpSource -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -query "select name from master..sysdatabases"

	.EXAMPLE
	Run query against remote sql server that is on an untrusted domain with credentials from the same untrusted domain.  I'll
	update the script to switches to automatically generate the credential manager entries later.  This can also be used to connect
	an sql server on a trusted domain with altenative domain credentials.
	cmdkey /add:acmedomain.sqlsrv1.com:51785 /user:acmedomain\user2 /pass:MyPassword!
	.\sqlcmd.ps1 -SqlServerInstance "acmedomain.sqlsrv1.com,51785" -query "select SYSTEM_USER"
	.\sqlcmd.ps1 -SqlServerInstance "acmedomain.sqlsrv1.com\myinstance" -query "select SYSTEM_USER"
	cmdkey /del:acmedomain.sqlsrv1.com:51785

#>

[CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login username.')]
    [string]$SqlUser,
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login password.')]
    [string]$SqlPass,   
    [Parameter(Mandatory=$true,
    HelpMessage='sql query.')]
    [string]$query,
    [Parameter(Mandatory=$true,
    HelpMessage='Set target SQL Server instance.')]
    [string]$SqlServerInstance
)

# -----------------------------------------------
# Connect to the sql server
# -----------------------------------------------
# Create fun connection object
$conn = New-Object System.Data.SqlClient.SqlConnection

# Set authentication type and create connection string
if($SqlUser -and $SqlPass){

# SQL login
$conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUser;Password=$SqlPass;"
[string]$ConnectUser = $SqlUser
}else{

# Trusted connection
$conn.ConnectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=SSPI;"
$UserDomain = [Environment]::UserDomainName
$Username = [Environment]::UserName
$ConnectUser = "$UserDomain\$Username"
}

# Attempt database connection
try{
$conn.Open()
write-host "[*] Connected." -foreground "green"
}catch{
$ErrorMessage = $_.Exception.Message
write-host "[*] Connection failed" -foreground "red"
write-host "[*] Error: $ErrorMessage" -foreground "red"
Break
}

# -----------------------------------------------
# Send query to server and process results
# -----------------------------------------------
$cmd = New-Object System.Data.SqlClient.SqlCommand($query,$conn)
$results = $cmd.ExecuteReader()
$MyQueryResults = New-Object System.Data.DataTable
$MyQueryResults.Load($results)
$MyQueryResults
