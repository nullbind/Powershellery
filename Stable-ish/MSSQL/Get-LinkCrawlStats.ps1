
# .\Get-LinkCrawlStats.ps1 -CrawlFile .\msfoutput.csv
# this script can be used to prase output from the sql server link crawler module.
[CmdletBinding()]
	Param(
	
	[Parameter(Mandatory=$true,
	HelpMessage='This is the file output from the Metasploit mssql_linkcrawl module.')]
	[string]$CrawlFile
	)

    # Import csv file
    $file = Import-Csv -Path $CrawlFile

    # Get counts
    $LinkCount_Total = $file | select link_server | measure | select Count -ExpandProperty Count
    $LinkCount_Up = $file | Where-Object {$_.link_state -like "up"} | select link_server | measure | select Count -ExpandProperty Count
    $LinkCount_Sysadmin = $file | Where-Object {$_.link_privilege -like "SYSADMIN!"} | select link_server | measure | select Count -ExpandProperty Count
    $LinkCount_User = $file | Where-Object {$_.link_privilege -notlike "SYSADMIN!" -and $_.link_state -like "up"} | select link_server | measure | select Count -ExpandProperty Count
    $ServerCount_Total = $file | select db_server | Sort-Object -Unique db_server|  measure | select Count -ExpandProperty Count
    $ServerCount_Sysadmin = $file | Where-Object {$_.link_privilege -like "SYSADMIN!"} | select db_server | Sort-Object -Unique db_server | measure | select Count -ExpandProperty Count
    $ServerCount_User = $file | Where-Object {$_.link_privilege -notlike "SYSADMIN!" -and $_.link_state -like "up"} | Sort-Object -Unique link_server | measure | select Count -ExpandProperty Count

    # Display counts
    Write-Output " "
    Write-Output "Total Links:$LinkCount_Total"
    Write-Output "Total Live Links:$LinkCount_Up"
    Write-Output "Total Live User Links:$LinkCount_User"
    Write-Output "Total Live Sysadmin Links:$LinkCount_Sysadmin"
    Write-Output "Total Live Servers:$ServerCount_Total"
    Write-Output "Total Live Servers with User privs:$ServerCount_User"
    Write-Output "Total Live Servers with Sysadmin privs:$ServerCount_Sysadmin"

    $Linkusers = $file |  select link_user | Where-Object {$_.link_user -notlike ""} | Sort-Object -Unique link_user   
    $LinkUserCount = $LinkUsers.count    
    Write-Output "Total Link Users: $LinkUserCount "
    $LinkUsers
    



