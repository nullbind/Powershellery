function Get-MssqlLogins
{
     <#
	    .SYNOPSIS
	    This script can be used to obtain a list of all logins from a SQL Server as a sysadmin or user with the PUBLIC role.

	    .DESCRIPTION
	    This script can be used to obtain a list of all logins from a SQL Server as a sysadmin or user with the PUBLIC role.
        Selecting all of the logins from the master..syslogins table is not possible using a login with only the PUBLIC role.
        However, it is possible to quickly enumerate SQL Server logins using the SUSER_SNAME function by fuzzing the principal_id
        number parameter, because the principal ids assigned to logins are incremental.

	    .EXAMPLE
	    Below is an example of how to enumerate logins from a SQL Server using the current Windows user context or "trusted connection".
	    PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS"
    
	    .EXAMPLE
	    Below is an example of how to enumerate logins from a SQL Server using alternative domain credentials.
	    PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser domain\user -SqlPass MyPassword!

	    .EXAMPLE
	    Below is an example of how to enumerate logins from a SQL Server using a SQL Server login".
	    PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword!

	    .EXAMPLE
	    Below is an example of how to enumerate logins from a SQL Server using a SQL Server login with non default fuzznum".
	    PS C:\> Invoke-SQLCmd -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword! -FuzzNum 500
    
	    .NOTES
	    Author: Scott Sutherland - 2014, NetSPI
	    Version: Get-MssqlLogins v1.0
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
        HelpMessage='Set target SQL Server instance.')]
        [string]$SqlServerInstance,
        [Parameter(Mandatory=$false,
        HelpMessage='Max SID to fuzz.')]
        [string]$FuzzNum
    )

    #------------------------------------------------
    # Set default values
    #------------------------------------------------
    if(!$FuzzNum){
        [int]$FuzzNum = 300
    }

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
        $conn.Close()
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
    # Enumerate sql server logins with SUSER_NAME()
    # -----------------------------------------------
    write-host "[*] FuzzNum set to $FuzzNum." 
    write-host "[*] Enumerating users..."

    # Open database connection
    $conn.Open()

    # Create table to store results
    $MyQueryResults = New-Object System.Data.DataTable
    $MyQueryResultsClean = New-Object System.Data.DataTable
    $MyQueryResultsClean.Columns.Add('name') | Out-Null 

    # Creat loop to fuzz principal_id number
    $PrincipalID = 0

    do {
        
        # incrememt number
        $PrincipalID++

        # Setup query
        $query = "SELECT SUSER_NAME($PrincipalID) as name"

        # Execute query
        $cmd = New-Object System.Data.SqlClient.SqlCommand($query,$conn)

        # Parse results
        $results = $cmd.ExecuteReader()
        $MyQueryResults.Load($results)
    }
    while ($PrincipalID -le $FuzzNum)    

    # Filter list of sql logins
    $MyQueryResults | select name -Unique | Where-Object {$_.name -notlike "*##*"} | Where-Object {$_.name -notlike ""} | ForEach-Object {
        
        # Get sql login name
        $SqlLoginName = $_.name

        # add cleaned up list to new data table
        $MyQueryResultsClean.Rows.Add($SqlLoginName) | Out-Null
    }

    # Close database connection
    $conn.Close()

    # Display initial login count
    $SqlLoginCount = $MyQueryResultsClean.Rows.Count
    Write-Host "[*] $SqlLoginCount initial logins were found." -foreground "green"

    # ----------------------------------------------------
    # Validate sql login with sp_defaultdb error ananlysis
    # ----------------------------------------------------

    # Status user
    Write-Host "[*] Verifying the logins..."

    # Open database connection
    $conn.Open()

    # Create table to store results
    $SqlLoginCheck = New-Object System.Data.DataTable
    $SqlLoginCheck.Columns.Add('name') | Out-Null 
    $SqlLoginCheck.Columns.Add('errormsg') | Out-Null 

    # Check if sql logins are valid 
    $MyQueryResultsClean | Sort-Object name
    #$MyQueryResultsClean | Sort-Object name | ForEach-Object {

        # Get sql login name
        #$SqlLoginNameTest = $_.name
    
        # Setup query
        #$query = "EXEC sp_defaultdb '$SqlLoginNameTest', 'NOTAREALDATABASE1234ABCD'"

        # Execute query
        #$cmd = New-Object System.Data.SqlClient.SqlCommand($query,$conn)

        # Parse results
        #$results = $cmd.ExecuteReader()
        #SqlLoginCheck.Load($results)
    #}

    # Close database connection
    $conn.Close()

    # -----------------------------------------------
    # Clean up credentials manager entry
    # -----------------------------------------------
    if ($DomainUserCheck){
        $CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol
        Write-Verbose "Command: $CredManDel"   
        $ExecManDel = invoke-expression $CredManDel
    }
}
