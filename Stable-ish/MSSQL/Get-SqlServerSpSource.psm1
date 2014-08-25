function Get-SqlServerSpSource
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

	   PS C:\> .\Get-SqlServerSpSource.ps1 -SQLServerInstance SQLSERVER1\SQLEXPRESS
	   [*] Attempting to Connect to SQLSERVER1\SQLEXPRESS as domain\user...
	   [*] Connected.
	   [*] Enumerating accessible databases...
	   [*] 4 accessible databases found.
	   [*] Searching for custom stored procedures...
	   [*]  - Checking Appliction1DB database...
	   [*]  - Checking Appliction2DB database...
	   [*]  - Checking Appliction3DB database...
	   [*]  - Checking Appliction4DB database...
	   [*] 400 custom stored procedures found across 4 databases.
	   [*] Exporting source code...
	   [*]  - Exporting stored procedures from Appliction1DB database to .\sp_source_output...
	   [*]  - Exporting stored procedures from Appliction2DB database to .\sp_source_output...
	   [*]  - Exporting stored procedures from Appliction3DB database to .\sp_source_output...
	   [*]  - Exporting stored procedures from Appliction4DB database to .\sp_source_output...
	   [*]  - Exporting stored procedures to .\sp_source_output\stored_procedures_source.csv...
	   [*] Searching for interesting keywords...
	   [*]  - Results can be found in .\sp_source_output\search-results-keywords\
	   [*] Searching for potential SQLi keywords...
	   [*]  - Results can be found in .\sp_source_output\search-results-sqli\
	   [*] All done - Enjoy! :)

	.EXAMPLE
	   Exporting custom stored procedures from a remote SQL Server using a provided SQL Login and export directory.

	   PS C:\> .\Get-SqlServerSpSource.ps1 -SQLServerInstance SQLSERVER1\SQLEXPRESS -sqluser MyUser -SQLPass MyPassword! -OutDir .\myfolder
	   [*] Attempting to Connect to SQLSERVER1\SQLEXPRESS as MyUser...
	   [*] Connected.
	   [*] Enumerating accessible databases...
	   [*] 4 accessible databases found.
	   [*] Searching for custom stored procedures...
	   [*]  - Checking Appliction1DB database...
	   [*]  - Checking Appliction2DB database...
	   [*]  - Checking Appliction3DB database...
	   [*]  - Checking Appliction4DB database...
	   [*] 400 custom stored procedures found across 4 databases.
	   [*] Exporting source code...
	   [*]  - Exporting stored procedures from Appliction1DB database to .\myfolder\sp_source_output...
	   [*]  - Exporting stored procedures from Appliction2DB database to .\myfolder\sp_source_output...
	   [*]  - Exporting stored procedures from Appliction3DB database to .\myfolder\sp_source_output...
	   [*]  - Exporting stored procedures from Appliction4DB database to .\myfolder\sp_source_output...
	   [*]  - Exporting stored procedures to .\myfolder\sp_source_output\stored_procedures_source.csv...
	   [*] Searching for interesting keywords...
	   [*]  - Results can be found in .\myfolder\sp_source_output\search-results-keywords\
	   [*] Searching for potential SQLi keywords...
	   [*]  - Results can be found in .\myfolder\sp_source_output\search-results-sqli\
	   [*] All done - Enjoy! :)

	.LINK
	   http://www.netspi.com
	   http://technet.microsoft.com/en-us/library/ms161953%28v=sql.105%29.aspx
	   http://blogs.msdn.com/b/brian_swan/archive/2011/02/16/do-stored-procedures-protect-against-sql-injection.aspx

	.NOTES
	   Author: Scott Sutherland - 2014, NetSPI
	   Version: Get-SqlServerSpSource v1.1
	   Comments: Should work on SQL Server 2005 and Above.
	   TODO: add total to each db,add keywords instances found across x files to verbose, update help
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
    [string]$OutDir
    
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

    # Setup query to grab a list of accessible databases
    $QueryDatabases = "SELECT name from master..sysdatabases 
	    where has_dbaccess(name)=1 and 
	    name not like 'master' and
	    name not like 'tempdb' and
	    name not like 'model' and
	    name not like 'msdb'"

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
		
		    # Setup query to grab a list of databases
		    $QueryProcedures = "SELECT ROUTINE_CATALOG,SPECIFIC_SCHEMA,ROUTINE_NAME,ROUTINE_DEFINITION FROM $CurrentDatabase.INFORMATION_SCHEMA.ROUTINES order by ROUTINE_NAME"		

		    # Query the databases and load the results into the TableDatabase data table object
		    $cmd = New-Object System.Data.SqlClient.SqlCommand($QueryProcedures,$conn)
		    $results = $cmd.ExecuteReader()
		    $TableSP.Load($results)

            # Get sp count for each database
            if ($x -eq 0){
                $x = $TableSP.rows.count 
                write-verbose "[*]  - Found $x in $CurrentDatabase"               
            }else{
                $CurrNumRows = $TableSP.rows.count 
                $PrevNumRows = $x
                $FoundNumRows = $CurrNumRows-$PrevNumRows
                write-verbose "[*]  - Found $FoundNumRows in $CurrentDatabase"
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
        write-verbose "[*] Attempting to create output directory..."
        try{
            mkdir $OutPutDir | Out-Null
            write-verbose "[*] $OutPutDir created." 
        }catch{
            $ErrorMessage = $_.Exception.Message
            write-host "[*] Failed to create output directory." -foreground "red"
            write-host "[*] Error: $ErrorMessage" -foreground "red"   
            Break
        }

        

	    # -------------------------------------------------
	    # Output source code to txt files in folder structure
	    # -------------------------------------------------
        
        write-host "[*] Exporting source code to $OutPutDir..."

	    $TableDatabases | foreach {
		
		    [string]$DirDb = $_.name
		    mkdir $OutPutDir\$DirDb | Out-Null
		
		    write-verbose "[*]  - Exporting from $DirDb..."

		    $TableSP | where {$_.ROUTINE_CATALOG -eq $DirDb} | 
		    foreach {			
			    [string]$ProcName = $_.ROUTINE_NAME
			    $_.ROUTINE_DEFINITION |
			    Out-File $OutPutDir\$DirDb\$ProcName.sql		
		    }
	    }

	    # -------------------------------------------------
	    # Output source code to CSV file
	    # -------------------------------------------------

	    write-verbose "[*]  - Exporting stored procedures to $OutPutDir\stored_procedures_source.csv..."
	    $TableSP | Export-CSV $OutPutDir\stored_procedures_source.csv

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
	    $InterestingKeywords | foreach {
		
		    write-verbose  "[*]  - Searching for string $_..."	
		    $KeywordFilePath = "$KeywordPath$_.txt"		
		    Get-ChildItem -Recurse $OutPutDir | Select-String -SimpleMatch "$_" >> $KeywordFilePath
	    }

        write-verbose "[*]  - Results can be found in $OutPutDir\search-results-keywords\"
		
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
					
	    write-host "[*] Searching for potential SQLi keywords..."
	    $SQLiKeywords | foreach {
		
		    write-verbose "[*]  - Searching for string $_..."		
		    Get-ChildItem -Recurse $OutPutDir\ | Select-String -SimpleMatch "$_"  >> $SQLPath
	    }
	
	    # Run a scan for three ticks in a row '''
	    write-verbose "[*]  - Searching for string '''..."	
	    Get-ChildItem -Recurse $OutPutDir\ | Select-String "'''" >> $SQLPath
		
        write-verbose "[*]  - Results can be found in $OutPutDir\search-results-sqli\"

	    write-verbose "[*] All results can be found in $OutPutDir\"
	    write-host "[*] All done - Enjoy! :)" -foreground "green"
    }
}
