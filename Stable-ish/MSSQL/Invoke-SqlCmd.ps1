 <#
	.SYNOPSIS
	This script can be used to query SQL Servers and view the results without needing the binaries that ship with SQL Server.

	.DESCRIPTION
	This script can be used to query SQL Servers and view the results without needing the binaries that ship with SQL Server.
    It can be used with trusted connections, SQL Server logins, and alter domain credentials.  Authentication is supported
    for both trusted and untrusted domains.

	.EXAMPLE
	Below is an example of how to query a SQL Server using the current Windows user context or "trusted connection".
	PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -query "select name from master..sysdatabases"
    
	.EXAMPLE
	Below is an example of how to query a SQL Server using alternative domain credentials.
	PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -query "select name from master..sysdatabases" -SqlUser domain\user -SqlPass MyPassword!

	.EXAMPLE
	Below is an example of how to query a SQL Server using a SQL Server login".
	PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -query "select name from master..sysdatabases" -SqlUser MyUser -SqlPass MyPassword!

#>

[CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL or Domain Login username.')]
    [string]$SqlUser,
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL or Domain Login password.')]
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

# Check for domain credentials
if($SqlUser){
    $DomainUserCheck = $SqlUser.Contains("\")
}

# Set authentication type and create connection string
if($SqlUser -and $SqlPassword -and !$DomainUserCheck){
    
    # SQL login / alternative domain credentials
    $conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUser;Password=$SqlPass;"
    [string]$ConnectUser = $SqlUser
}else{

    # Create credentials management entry if a domain user is used
    if ($DomainUserCheck -and (Test-Path  ("C:\Windows\System32\cmdkey.exe"))){   
     		
        Write-Output "[*] Attempting to authenticate to $SqlServerInstance with domain account $SqlUser..."
        $SqlServerInstanceCol = $SqlServerInstance -replace ',', ':'
	    $CredManCmd = 'cmdkey /add:'+$SqlServerInstanceCol+' /user:'+$SqlUser+' /pass:'+$SqlPass 
        Write-Verbose "Command: $CredManCmd"
        $ExecManCmd = invoke-expression $CredManCmd
    }else{

        Write-Output "[*] Attempting to authenticate to $SqlServerInstance as the current Windows user..."
    }

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

    # -----------------------------------------------
    # Clean up credentials manager entry
    # -----------------------------------------------
     if ($DomainUserCheck){
        $CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol
        Write-Verbose "Command: $CredManDel"   
        $ExecManDel = invoke-expression $CredManDel
     }
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

# -----------------------------------------------
# Clean up credentials manager entry
# -----------------------------------------------
 if ($DomainUserCheck){
    $CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol
    Write-Verbose "Command: $CredManDel"   
    $ExecManDel = invoke-expression $CredManDel
 }
