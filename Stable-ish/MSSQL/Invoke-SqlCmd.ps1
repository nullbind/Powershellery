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
	
	.LINK
	http://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlconnection%28v=vs.110%29.aspx
	http://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlcommand%28v=vs.110%29.aspx
	
	.NOTES
	Author: Scott Sutherland - 2014, NetSPI
	Version: Invoke-SqlCmd.ps1 v1.0
	Comments: This should work on SQL Server 2005 and Above.
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

Begin
{
	# -----------------------------------------------
	# Connect to the sql server
	# -----------------------------------------------

	# Create fun connection object
	$conn = New-Object System.Data.SqlClient.SqlConnection

	# Check if domain domain credentials were provided
	if($SqlUser){
		$DomainUserCheck = $SqlUser.Contains("\")
	}

	# Set authentication type and create connection string
	if($SqlUser -and $SqlPassword -and !$DomainUserCheck){
    
		# Setup connection to use SQL Server login
		$conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUser;Password=$SqlPass;"
		[string]$ConnectUser = $SqlUser
	}else{

		# Create entry in Credential Manager if a domain user is used
		if ($DomainUserCheck -and (Test-Path  ("C:\Windows\System32\cmdkey.exe"))){   
     		
			# Status user
			Write-Output "[*] Attempting to authenticate to $SqlServerInstance with domain account $SqlUser..."
		
			# Add entry so trusted connection with use alternative domain credentials
			$SqlServerInstanceCol = $SqlServerInstance -replace ',', ':'
			$CredManCmd = 'cmdkey /add:'+$SqlServerInstanceCol+' /user:'+$SqlUser+' /pass:'+$SqlPass 
			Write-Verbose "Command: $CredManCmd"
			$ExecManCmd = invoke-expression $CredManCmd
        	}else{
        		
			# Status user
			Write-Output "[*] Attempting to authenticate to $SqlServerInstance as the current Windows user..."
        	}

	        # Setup Trusted Connection
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
}
Process
{

	# -----------------------------------------------
   	# Send query to server and process results
    	# -----------------------------------------------
    	$cmd = New-Object System.Data.SqlClient.SqlCommand($query,$conn)
    	$results = $cmd.ExecuteReader()
    	$MyQueryResults = New-Object System.Data.DataTable
    	$MyQueryResults.Load($results)
    	$MyQueryResults

    	# Disconnect from database
    	$conn.Close()
}

End
{
	# -----------------------------------------------
	# Clean up 
	# -----------------------------------------------

	# Remove credentials manager entry
	if ($DomainUserCheck){
		$CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol   
		$ExecManDel = invoke-expression $CredManDel
	}

	# Status user
	Write-Output "[*] Done." 
 }
