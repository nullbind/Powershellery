function Get-SqlServer-Enum-SqlLogins
{
    <#
        .SYNOPSIS
        This script can be used to obtain a list of all logins from a SQL Server as a sysadmin or user with the PUBLIC role.

        .DESCRIPTION
        This module can be used to obtain a list of all logins from a SQL Server with any
        login. Selecting all of the logins from the master..syslogins table is restricted 
        to sysadmins.  However, logins with the PUBLIC role (everyone) can quickly enumerate
        all SQL Server logins using the SUSER_SNAME function by fuzzing the principal_id parameter. 
        This is pretty simple, because the principal ids assigned to logins are incremental.  Once 
        logins have been enumerated they can be verified via sp_defaultdb error ananlysis.  
        This is important, because not all of the principal ids resolve to SQL logins.  Some resolve
        to roles etc.

        .EXAMPLE
        Below is an example of how to enumerate logins from a SQL Server using the current Windows user context or "trusted connection".
        PS C:\> Get-SqlServer-Enum-SqlLogins -SQLServerInstance "SQLSERVER1\SQLEXPRESS" 
    
        .EXAMPLE
        Below is an example of how to enumerate logins from a SQL Server using a SQL Server login".
        PS C:\> Get-SqlServer-Enum-SqlLogins -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword!

        .EXAMPLE
        Below is an example of how to enumerate logins from a SQL Server using a SQL Server login".
        PS C:\> Get-SqlServer-Enum-SqlLogins -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword! | Export-Csv c:\temp\sqllogins.csv -NoTypeInformation

        .EXAMPLE
        Below is an example of how to enumerate logins from a SQL Server using a SQL Server login with non default fuzznum".
        PS C:\> Get-SqlServer-Enum-SqlLogins -SQLServerInstance "SQLSERVER1\SQLEXPRESS" -SqlUser MyUser -SqlPass MyPassword! -FuzzNum 500
    
        .LINKS
        www.netspi.com
        http://msdn.microsoft.com/en-us/library/ms174427.aspx
        
        .NOTES
        Author: Scott Sutherland - 2014, NetSPI
        Version: Get-SqlServer-Enum-SqlLogins v1.0
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
        [int]$FuzzNum = 300
    }

    # -----------------------------------------------
    # Connect to the sql server
    # -----------------------------------------------
    # Create fun connection object
    $conn = New-Object  -TypeName System.Data.SqlClient.SqlConnection


    # Set authentication type and create connection string
    if($SqlUser)
    {
        # SQL login / alternative domain credentials
        Write-Output  -InputObject "[*] Attempting to authenticate to $SqlServerInstance with the Login $SqlUser..."
        $conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUser;Password=$SqlPass;"
        [string]$ConnectUser = $SqlUser
    }
    else
    {
        # Trusted connection
        Write-Output  -InputObject "[*] Attempting to authenticate to $SqlServerInstance as the current Windows user..."        
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
    # Enumerate sql server logins with SUSER_NAME()
    # -----------------------------------------------
    Write-Host  -Object "[*] Fuzzing $FuzzNum SQL Server principal_ids..." 

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

        # Setup query
        $query = "SELECT SUSER_NAME($PrincipalID) as name"

        # Execute query
        $cmd = New-Object  -TypeName System.Data.SqlClient.SqlCommand -ArgumentList ($query, $conn)

        # Parse results
        $results = $cmd.ExecuteReader()
        $MyQueryResults.Load($results)
    }
    while ($PrincipalID -le $FuzzNum-1)    

    # Filter list of sql logins
    $MyQueryResults |
    Select-Object name -Unique |
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
    Write-Host "[*] $SqlLoginCount SQL Server logins and roles were found." 


    # ----------------------------------------------------
    # Validate sql login with sp_defaultdb error ananlysis
    # ----------------------------------------------------

    # Status user
    Write-Host  -Object '[*] Identifying the logins...'

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
        Write-Host  -Object '[*] No verified logins found.' -ForegroundColor 'red'
    }

    # Clean up credentials manager entry
    if ($DomainUserCheck)
    {
        $CredManDel = 'cmdkey /delete:'+$SqlServerInstanceCol
        Write-Verbose  -Message "Command: $CredManDel"   
        $ExecManDel = Invoke-Expression  -Command $CredManDel
    }
}
