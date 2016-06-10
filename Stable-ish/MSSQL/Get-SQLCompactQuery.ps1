# This script can be used as a template for querying sql server compact edition files

# Import required library
[Reflection.Assembly]::LoadFile("C:\Program Files (x86)\Microsoft SQL Server Compact Edition\v4.0\Desktop\System.Data.SqlServerCe.dll")

# Setup connection string
$connString = "Data Source='C:\temp\file.sdf';Password='password'" 
$cn = new-object "System.Data.SqlServerCe.SqlCeConnection" $connString

# Create the command 
$cmd = new-object "System.Data.SqlServerCe.SqlCeCommand"
$cmd.CommandType = [System.Data.CommandType]"Text" 
$cmd.CommandText = "select 1" 
$cmd.Connection = $cn

# Create data table to store results
$dt = new-object System.Data.DataTable

# Open connection
$cn.Open() 

# Run query
$rdr = $cmd.ExecuteReader()

# Populate data table
$dt.Load($rdr) 
$cn.Close()

# Return data
$dt | Out-Default | Format-Table
