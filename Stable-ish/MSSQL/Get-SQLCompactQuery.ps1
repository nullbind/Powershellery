# Script: Get-SQLCompactQuery
# Author: Scott Sutherland (@_nullbind), NetSPI 2016
# This script can be used as a template for querying sql server compact edition files
# Reference: https://technet.microsoft.com/en-us/library/ms173372(v=sql.110).aspx
# Example: .\Get-SQLCompactQuery.ps1 -Query "SELECT TABLE_NAME from information_schema.tables" -DbFilePath c:\temp\file.sdf -Password SecretPassword!
# Example: .\Get-SQLCompactQuery.ps1 -Query "SELECT TABLE_NAME, COLUMN_NAME from information_schema.columns" -DbFilePath c:\temp\file.sdf -Password SecretPassword!

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false)]
   [string]$LibFilePath,
	
   [Parameter(Mandatory=$true)]
   [string]$DbFilePath,

   [Parameter(Mandatory=$false)]
   [string]$Password,

   [Parameter(Mandatory=$false)]
   [string]$Query = "Select 1"
)

# Define stuff
if (-not $libpath){
    $libpath = "C:\Program Files (x86)\Microsoft SQL Server Compact Edition\v4.0\Desktop\System.Data.SqlServerCe.dll"
}

# Import required library
[Reflection.Assembly]::LoadFile("$libpath") | Out-Null

# Setup up password if provided
if($Password){
    $DbPass = ";Password=`"$Password`""
}else{
    $DbPass = ""
}

# Setup connection string
$connString = "Data Source=`"$DbFilePath`"$DbPass" 
$cn = new-object "System.Data.SqlServerCe.SqlCeConnection" $connString

# Create the command 
$cmd = new-object "System.Data.SqlServerCe.SqlCeCommand"
$cmd.CommandType = [System.Data.CommandType]"Text" 
$cmd.CommandText = "$Query" 
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
