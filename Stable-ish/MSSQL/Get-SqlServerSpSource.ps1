#Script Name: Get-SqlServerSpSource.ps1
#Author: Scott Sutherland, NetSPI 2014
#Description: This script dumps all of the custom 
#stored procedures on an SQL Server from all
#accessible database so they can be analyzed
#offline for things like hardcoded passwords,
#crypto keys, elevated execution, and sql injection

# -----------------------------------------------
# Create database tables
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
# Get list of dateabases
# -----------------------------------------------

# Status user


# Connect to the database
$conn = New-Object System.Data.SqlClient.SqlConnection
$SqlServerInstance = "server\SQLEXPRESS"
$SqlUsername = "user"
$SqlPassword = "password"
$conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUsername;Password=$SqlPassword;"

write-host "[*] Connecting to $SqlServerInstance as $SqlUsername..."
$conn.Open()

# Setup query to grab a list of databases
$QueryDatabases = "SELECT name from master..sysdatabases 
	where has_dbaccess(name)=1 and 
	name not like 'master' and
	name not like 'tempdb' and
	name not like 'model' and
	name not like 'msdb'"

# User status
write-host "[*] Enumerating accessible databases..."

# Query the databases and load the results into the TableDatabase data table object
$cmd = New-Object System.Data.SqlClient.SqlCommand($QueryDatabases,$conn)
$results = $cmd.ExecuteReader()
$TableDatabases.Load($results)

# Check if any accessible database where found and print them out
if ($TableDatabases.rows.count -eq 0){

	write-host "No accessible databases found."
}else{
	$DbCount = $TableDatabases.rows.count
	write-host "[*] $DbCount accessible databases were found."
}


# -------------------------------------------------
# Get list of custom stored procedures for each db
# -------------------------------------------------

if ($TableDatabases.rows.count -ne 0){	

	$TableDatabases | foreach {

		[string]$CurrentDatabase = $_.name
		
		# Setup query to grab a list of databases
		$QueryProcedures = "SELECT ROUTINE_CATALOG,SPECIFIC_SCHEMA,ROUTINE_NAME,ROUTINE_DEFINITION FROM $CurrentDatabase.INFORMATION_SCHEMA.ROUTINES order by ROUTINE_NAME"		

		# Query the databases and load the results into the TableDatabase data table object
		$cmd = New-Object System.Data.SqlClient.SqlCommand($QueryProcedures,$conn)
		$results = $cmd.ExecuteReader()
		$TableSP.Load($results)
		write-host "[*] Checking database $CurrentDatabase for custom stored procedures..."	
	
	}
}

# Status user	
$SpCount = $TableSP.rows.count 
write-host "[*] $SpCount procedures were found across $DbCount databases."
write-host "[*] Exporting source code:"

if ($SpCount -ne 0) {
	# -------------------------------------------------
	# Output source code to txt files in folder structure
	# -------------------------------------------------
	mkdir sp_source_output | Out-Null
	$TableDatabases | foreach {
		
		[string]$DirDb = $_.name
		mkdir sp_source_output\$DirDb | Out-Null
		
		write-host "[*]  - Exporting stored procedures from database $DirDb to .\sp_source_output folder......"

		$TableSP | where {$_.ROUTINE_CATALOG -eq $DirDb} | 
		foreach {			
			[string]$ProcName = $_.ROUTINE_NAME
			$_.ROUTINE_DEFINITION |
			Out-File .\sp_source_output\$DirDb\$ProcName.sql		
		}
	}

	# -------------------------------------------------
	# Output source code to CSV file
	# -------------------------------------------------
	write-host "[*]  - Exporting stored procedures to .\sp_source_output\stored_procedures_source.csv..."
	$TableSP | Export-CSV .\sp_source_output\stored_procedures_source.csv

	# -------------------------------------------------
	# Search source code for interesting keywords
	# Goal = 
	# - custom sp with execute as sysadmin and sqli :)
	# - custom sp with command execution
	# -------------------------------------------------
	
	# Create output file
	mkdir .\sp_source_output\keywords_results | Out-Null
	$KeywordPath = ".\sp_source_output\keywords_results\"
	
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
					
	write-host "[*] Searching for interesting keywords in files..."
	$InterestingKeywords | foreach {
		
		write-host "[*]  - Searching for string $_..."	
		$KeywordFilePath = "$KeywordPath$_.txt"		
		Get-ChildItem -Recurse .\sp_source_output\ | Select-String "$_" >> $KeywordFilePath
	}
		
	# -------------------------------------------------
	# Search source code for potential sqli
	# -------------------------------------------------
	
	# Create output file
	mkdir .\sp_source_output\sqli_results | Out-Null
	$SQLPath = ".\sp_source_output\sqli_results\"
	
	# Create potential sqli keywords array
	$SQLiKeywords =@("sp_executesql",
				  "sp_sqlexec",
				  "exec",				  
				  "execute"
					)
					
	write-host "[*] Searching for potential sqli..."
	$SQLiKeywords | foreach {
		
		write-host "[*]  - Searching for string $_..."	
		$SqlFilePath = "$SQLPathpotential-sqli"		
		Get-ChildItem -Recurse .\sp_source_output\ | Select-String "$_"  >> $SqlFilePath
	}
	
	# Run a scan for three ticks in a row '''
	write-host "[*]  - Searching for string '''..."	
	$SqlFilePath = "$SQLPathpotential-sqli-tripticks"
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String "'''" >> $SqlFilePath
		
	# http://technet.microsoft.com/en-us/library/ms161953%28v=sql.105%29.aspx
	# http://blogs.msdn.com/b/brian_swan/archive/2011/02/16/do-stored-procedures-protect-against-sql-injection.aspx
	
	write-host "[*] All done - Enjoy! :)"
}
