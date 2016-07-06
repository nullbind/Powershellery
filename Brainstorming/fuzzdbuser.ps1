# Create table for output
$tblresults = New-Object System.Data.DataTable 
$tblresults.columns.Add("ComputerName") | Out-Null
$tblresults.columns.Add("Instance")| Out-Null
$tblresults.columns.Add("DatabaseName")| Out-Null
$tblresults.columns.Add("DatabaseUser")| Out-Null

Get-SQLInstanceLocal | 
Get-SQLDatabase -Verbose -NoDefaults | 
ForEach-Object {
	$ComputerName = $_.computername 
	$Instance = $_.instance
	$DatabaseName = $_.databasename 
	1..50 | 
	foreach-object {
    Write-Output "Fuzzing...$_"
		$Results = Get-SQLQuery -Instance $instance -Query "use $databasename;select user_Name($_) as blah"
		$DatabaseUser = $results | select blah -ExpandProperty blah
    $tblresults.Rows.Add($ComputerName, $instance, $DatabaseName, $DatabaseUser) | Out-Null
	}
}

 $tblresults | Where-Object{ $_.databaseuser.length -ge 2 }
