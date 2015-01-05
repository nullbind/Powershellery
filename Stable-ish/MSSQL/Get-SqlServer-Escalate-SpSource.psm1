function Get-SqlServer-Escalate-SpSource
{
    <#
	.SYNOPSIS
	   This script can be used to export custom stored procedures from all accessible databases on a SQL Server.

	.DESCRIPTION
	   This script can be used to export custom stored procedures from all accessible databases on a SQL Server to
	   .sql files in a provided output directory.  It then searches for keywords that are commonly associated with
	   vulnerabilities like hardcoded passwords, hardcoded crypto keys, execute as sysadmin, and sql injection.  
	   This script can accept SQL Credentials or use the current user's trusted connection.

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a trusted connection. 

	   PS C:\> Get-SqlServer-Escalate-SpSource -SQLServerInstance SQLSERVER1\SQLEXPRESS

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a SQL Login.

	   PS C:\> Get-SqlServer-Escalate-SpSource -SQLServerInstance SQLSERVER1\SQLEXPRESS -SqlUser MyUser -SqlPass MyPass

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a trusted connection,
	   and set a custom output directory.

	   PS C:\> Get-SqlServer-Escalate-SpSource -SqlServerInstance SQLSERVER1\SQLEXPRESS -OutDir .\myfolder\

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a trusted connection.
	   The command below also checks the exported stored procedures interesting keywords they
 	   may indiciate things like hardcoded passwords, elevated execution, and SQL injection.

	   PS C:\> Get-SqlServer-Escalate-SpSource -SqlServerInstance SQLSERVER1\SQLEXPRESS -RunChecks 

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a trusted connection.
	   The -RunChecks switch checks the exported stored procedures for interesting keywords that
 	   may indiciate hardcoded passwords, elevated execution, and SQL injection.
 	   This syntax also targets a specific database and store procedure.

	   PS C:\> Get-SqlServer-Escalate-SpSource -SqlServerInstance SQLSERVER1\SQLEXPRESS -RunChecks -Database mydb -Procedure mysp

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a trusted connection.
	   The command below also checks the exported stored procedures interesting keywords they
 	   may indiciate things like hardcoded passwords, elevated execution, and SQL injection.
 	   The -verbose flag will display the current keyword being search for as well as some
 	   additional information about the script's operation.

	   PS C:\> Get-SqlServer-Escalate-SpSource -SqlServerInstance SQLSERVER1\SQLEXPRESS -RunChecks -verbose

	.LINK
	   http://www.netspi.com
	   http://technet.microsoft.com/en-us/library/ms161953%28v=sql.105%29.aspx
	   http://blogs.msdn.com/b/brian_swan/archive/2011/02/16/do-stored-procedures-protect-against-sql-injection.aspx

	.NOTES
	   Author: Scott Sutherland - 2014, NetSPI
	   Version: Get-SqlServer-Escalate-SpSource v1.2
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
    [string]$SqlServerInstance,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Output directory.')]
    [string]$OutDir,

    [Parameter(Mandatory=$false,
    HelpMessage='Database to target.')]
    [string]$Database,

    [Parameter(Mandatory=$false,
    HelpMessage='Procedure to target.')]
    [string]$Procedure,

    [Parameter(Mandatory=$false,
    HelpMessage='Search stored procedures for interesting strings.')]
    [switch]$RunChecks
    
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

    # Create data table to house list of non default databases  
    $TableDatabases = New-Object System.Data.DataTable 
    $TableDatabases.Columns.Add('name') | Out-Null

    # Create data table to house list of stored procedures
    $TableSP = New-Object System.Data.DataTable 
    $TableSP.Columns.Add('ROUTINE_CATALOG') | Out-Null
    $TableSP.Columns.Add('SPECIFIC_SCHEMA') | Out-Null
    $TableSP.Columns.Add('ROUTINE_NAME') | Out-Null
    $TableSP.Columns.Add('ROUTINE_DEFINITION') | Out-Null


    # -----------------------------------------------
    # Get list of accessible non default dateabases
    # -----------------------------------------------       

    # Check for user supplied database
    if ($Database) {
        $SqlDatabase = "and name like '$Database'"
    }else{
        $SqlDatabase = ""
    }

    # Setup query to grab a list of accessible databases
    $QueryDatabases = "SELECT name from master..sysdatabases 
	    where has_dbaccess(name)=1 and
	    name not like 'tempdb' and
	    name not like 'model' and
	    name not like 'msdb' $SqlDatabase"

    # User status
    write-host "[*] Enumerating accessible databases..."

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
    # Get list of custom stored procedures for each db
    # -------------------------------------------------

    if ($TableDatabases.rows.count -ne 0){	

        write-host "[*] Searching for custom stored procedures..."
        $x = 0
	    $TableDatabases | foreach {

		    [string]$CurrentDatabase = $_.name

            # Check for user supplied stored procedure name
            if ($Procedure) {
                $SqlProcedure = "WHERE ROUTINE_NAME like '$Procedure'"
            }else{
                $SqlProcedure = ""
            }
		
		    # Setup query to grab a list of databases
		    $QueryProcedures = "SELECT ROUTINE_CATALOG,SPECIFIC_SCHEMA,ROUTINE_NAME,ROUTINE_DEFINITION FROM $CurrentDatabase.INFORMATION_SCHEMA.ROUTINES $SqlProcedure order by ROUTINE_NAME"		

		    # Query the databases and load the results into the TableDatabase data table object
		    $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryProcedures,$conn)
		    $results = $cmd.ExecuteReader()
		    $TableSP.Load($results)

            # Get sp count for each database
            if ($x -eq 0){
                $x = $TableSP.rows.count 
                write-host "[*]  - Found $x in $CurrentDatabase"               
            }else{
                $CurrNumRows = $TableSP.rows.count 
                $PrevNumRows = $x
                $FoundNumRows = $CurrNumRows-$PrevNumRows
                write-host "[*]  - Found $FoundNumRows in $CurrentDatabase"
                $x = $TableSP.rows.count 
            }            		
	    }
    }

    # Get number of custom stored procedures found
    $SpCount = $TableSP.rows.count 
    
    # Set status color   
    if ( $SpCount -ne 0){ 
            $LineColor = 'green' 
    }else{
            $LineColor = 'red'
    }
    write-host "[*] $SpCount custom stored procedures found across $DbCount databases." -foreground $LineColor

    if ($SpCount -ne 0) {

        #Create output directory
        if( $OutDir ){
            $OutPutDir = "$OutDir\sp_source_output"
        }else{
            $OutPutDir = ".\sp_source_output"
        }

        # Attempt to create output directory
        write-host "[*] Exporting source code to $OutPutDir..."
        write-verbose "[*] Attempting to create output directory..."
        $CheckOutDir = Test-Path $OutPutDir
        if($CheckOutDir){
            write-host "[*] Error: Can't create directory `"$OutPutDir`", it already exists." -ForegroundColor Red
            break
        }else{
            mkdir $OutPutDir | Out-Null
            write-verbose "[*] $OutPutDir created."
        }
        
	    # -------------------------------------------------
	    # Output source code to txt files in folder structure
	    # -------------------------------------------------

	    $TableDatabases | foreach {
		
		    [string]$DirDb = $_.name
		    mkdir $OutPutDir\exported_sp_tsql_files\$DirDb | Out-Null
		
		    write-host "[*]  - Exporting from $DirDb"

		    $TableSP | where {$_.ROUTINE_CATALOG -eq $DirDb} | 
		    foreach {			
			    [string]$ProcName = $_.ROUTINE_NAME
			    $_.ROUTINE_DEFINITION |
			    Out-File $OutPutDir\exported_sp_tsql_files\$DirDb\$ProcName.sql		
		    }
	    }

	    # -------------------------------------------------
	    # Output source code to CSV file
	    # -------------------------------------------------

	    write-verbose "[*]  - Exporting stored procedures to $OutPutDir\exported_stored_procedures_source.csv..."
	    $TableSP | Export-CSV $OutPutDir\exported_stored_procedures_source.csv
        
        if ($RunChecks){
	        # -------------------------------------------------
	        # Search source code for interesting keywords
	        # -------------------------------------------------
	
	        # Create output file
	        mkdir $OutPutDir\search-results-keywords | Out-Null
	        $KeywordPath = "$OutPutDir\search-results-keywords\"
	
	        # Create keywords array
	        $InterestingKeywords =@("encr",
				          "password",
				          "with execute as",
				          "trigger",
				          "xp_cmdshell",
				          "cmd",
				          "openquery",
				          "openrowset",
				          "connect",
				          "grant",
				          "proxy",
				          "osql"
					        )
					
	        write-host "[*] Searching for interesting keywords..."
            write-host "[*] NOTE: THIS CAN TAKE A WHILE IF THERE ARE THOUSANDS OF PROCEDURES"
	        $InterestingKeywords | foreach {
		
		        write-verbose  "[*]  - Searching for string $_..."	
		        $KeywordFilePath = "$KeywordPath$_.txt"		
		        Get-ChildItem -Recurse $OutPutDir\exported_sp_tsql_files\ | Select-String -SimpleMatch "$_" | Out-File -Append $KeywordFilePath
	        }
		
	        # -------------------------------------------------
	        # Search source code for potential sqli keywords
	        # -------------------------------------------------
	
	        # Create output file
	        mkdir $OutPutDir\search-results-sqli | Out-Null
	        $SQLPath = "$OutPutDir\search-results-sqli\sqli.txt"
	
	        # Create potential sqli keywords array
            $SymAt = "@"
            [string]$SymOpen = "("
	        $SQLiKeywords =@("sp_executesql",
				          "sp_sqlexec",
				          "exec @",	
				          "exec (",	
				          "exec(",			  
				          "execute @",	
				          "execute (",	
				          "execute("
					        )
					           
	        $SQLiKeywords | foreach {
		
		        write-verbose "[*]  - Searching for string $_..."		
		        Get-ChildItem -Recurse $OutPutDir\ | Select-String -SimpleMatch "$_"  >> $SQLPath
	        }
	
	        # Run a scan for three ticks in a row '''	        
	        Get-ChildItem -Recurse $OutPutDir\exported_sp_tsql_files\ | Select-String "'''" | Out-File -Append $SQLPath       
        }
    }
    
	write-host "[*] All done, results can be found in $OutPutDir\" -foreground "green"
}
