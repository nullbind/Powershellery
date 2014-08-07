#Script Name: Get-SqlServerSpSource.ps1
#Author: Scott Sutherland, NetSPI 2014
#Description: This script dumps all of the custom 
#stored procedures on an SQL Server from all
#accessible database so they can be analyzed
#offline for things like hardcode password,
#crypto keys, elevated status, and sql injection

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
write-host "[*] Connecting to the database server..."

# Connect to the database
$conn = New-Object System.Data.SqlClient.SqlConnection
$conn.ConnectionString = "Server=127.0.0.1;Database=master;User ID=user;Password=password;"
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
	
	write-host "[*] Enumerating custom stored procedures..."

	$TableDatabases | foreach {

		[string]$CurrentDatabase = $_.name
		
		# Setup query to grab a list of databases
		$QueryProcedures = "SELECT ROUTINE_CATALOG,SPECIFIC_SCHEMA,ROUTINE_NAME,ROUTINE_DEFINITION FROM $CurrentDatabase.INFORMATION_SCHEMA.ROUTINES order by ROUTINE_NAME"		

		# Query the databases and load the results into the TableDatabase data table object
		$cmd = New-Object System.Data.SqlClient.SqlCommand($QueryProcedures,$conn)
		$results = $cmd.ExecuteReader()
		$TableSP.Load($results)
		write-host "[*] Checking $CurrentDatabase for custom stored procedures..."	
	
	}
}

# Status user	
$SpCount = $TableSP.rows.count 
write-host "[*] $spCount procedures were found across $DbCount databases."

if ($SpCount -ne 0) {
	# -------------------------------------------------
	# Output source code to txt files in folder structure
	# -------------------------------------------------
	write-host "[*] Exporting source code to files in the sp_source_output folder..."	
	mkdir sp_source_output | Out-Null
	$TableDatabases | foreach {
		
		[string]$DirDb = $_.name
		mkdir sp_source_output\$DirDb | Out-Null
		
		write-host "[*] Exporting stored procedures from $DirDb..."

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
	write-host "[*] Exporting source code to custom_stored_procedures_source.csv..."
	$TableSP | Export-CSV .\sp_source_output\custom_stored_procedures_source.csv

	# -------------------------------------------------
	# Search source code for interesting keywords
	# -------------------------------------------------
	
	# Create output file
	mkdir .\sp_source_output\keywords_results | Out-Null
	$KeywordPath = ".\sp_source_output\keywords_results\"
	
	# Create keywords array
	$Keywords =@("encr",
				  "password",
				  "with execute as",
				  "trigger",
				  "xp_cmdshell",
				  "cmd",
				  "openquery",
				  "openrowset",
				  "connect",
				  "osql"
					)
					
	write-host "[*] Searching for interesting keywords in files..."
	$Keywords | foreach {
		
		write-host "[*] Searching for string $_..."	
		$KeywordFilePath = "$KeywordPath$_.txt"		
		Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "$_" >> $KeywordFilePath
	}
		
	# -------------------------------------------------
	# Search source code for potential sqli
	# -------------------------------------------------
	
	# Create output file
	mkdir .\sp_source_output\sqli_results | Out-Null
	$SQLPath = ".\sp_source_output\sqli_results\"
	
	# Create keywords array
	$SQLs =@("'''")
					
	write-host "[*] Searching for potential sqli..."
	$SQLs | foreach {
		
		write-host "[*] Searching for string $_..."	
		$SqlFilePath = "$SQLPathpotential-sqli"		
		Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "$_" >> $SqlFilePath
	}
	
		
	# http://technet.microsoft.com/en-us/library/ms161953%28v=sql.105%29.aspx
	# http://blogs.msdn.com/b/brian_swan/archive/2011/02/16/do-stored-procedures-protect-against-sql-injection.aspx
	
	write-host "[*] All done - Enjoy! :)"
}
