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
	$TableSP | Export-CSV .\custom_stored_procedures_source.csv

	# -------------------------------------------------
	# Output source code to CSV file
	# -------------------------------------------------
	mkdir keywords_results | Out-Null
	write-host "[*] Searching for interesting keywords in files..."
	write-host "[*] Searching for string encr..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "encr" >>.\keywords_results\encr.txt
	write-host "[*] Searching for string password..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "password" >>.\keywords_results\password.txt
	write-host "[*] Searching for string execute..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "pass">>.\keywords_results\pass.txt
	write-host "[*] Searching for string with execute..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "with execute as">>.\keywords_results\execute.txt
	write-host "[*] Searching for string trigger..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "trigger">>.\keywords_results\trigger.txt
	write-host "[*] Searching for string xp_cmdshell..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "xp_cmdshell">>.\keywords_results\xp_cmdshell.txt
	write-host "[*] Searching for string cmd..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "cmd">>.\keywords_results\cmd.txt
	write-host "[*] Searching for string openquery..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "openquery">>.\keywords_results\openquery.txt
	write-host "[*] Searching for string openrowset..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "openrowset">>.\keywords_results\openrowset.txt
	write-host "[*] Searching for string connect..."
	Get-ChildItem -Recurse .\sp_source_output\ | Select-String -pattern "connect">>.\keywords_results\connect.txt

	write-host "[*] All done - Enjoy! :)"
}
