# Author: Scott Sutherland 2013, NetSPI
# Version: Get-AppPoolCreds v.-37

#todo
#ftp
#pool
#server
#vdir
#ads

<#
	.SYNOPSIS
    Displays the clear text passwords for custom IIS application pool idenities.
	
	.NOTES
	Must be run as administrator.
	Requires IIS 7 or above in order to support appcmd.exe.
#>

if (Test-Path ("c:\windows\system32\inetsrv\appcmd.exe")){

	# Display status to user
	Write-Host " "
	Write-Host "Found appcmd.exe"
	
	# Command to dump IIS application pool configurations from applicationHost.config
	$MyPools = c:\windows\system32\inetsrv\appcmd.exe list apppool
	$MyPoolsConfigs = c:\windows\system32\inetsrv\appcmd.exe list apppool /text:* 

	# Display status summary to user
	$MyPoolCount = $MyPools.count
	Write-Host "Found $MyPoolCount IIS application pools"
	Write-Host "Dumping IIS application pool credentials in clear text..."
	Write-Host " "

	$MyPoolsConfigs | foreach {

		# Display application pool name
		if($_ -like "*APPPOOL.NAME*")  
		{	
			Write-Host "------------------------------------"
			write-host $_
		}
		
		# Display username for application pool
		if($_ -like "*username*")  
		{
			write-host $_
		}
		
		# Display password for application pool
		if($_ -like "*password*")  
		{
			write-host $_
		}
	} 
	Write-Host "------------------------------------"
	Write-Host " "
}else{
	
	Write-Host " "
	Write-Host "Missing appcmd.exe!!"
	Write-Host " "
}



<#
Below are things I would like to build out in the future.

# Import module
import-module WebAdministration 
		
# Recover application pool credentials
Get-WMIObject -Namespace root\WebAdministration -Class ApplicationPool | Foreach { $I = $_.Name + " - " + $_.ProcessModel.UserName + " - " + $_.ProcessModel.Password; $I }

# OS commands option look like the following
c:\windows\system32\inetsrv\appcmd.exe list apppool /text:*
c:\windows\system32\inetsrv\appcmd.exe list apppool /text:processModel.username
c:\windows\system32\inetsrv\appcmd.exe list apppool /text:processModel.password

# Get the app pool name for each IIS worker process
Get-WmiObject –class win32_process -filter 'name="w3wp.exe"' | Select-Object –Property Name, ProcessId, @{n='AppPool';e={$_.GetOwner().user}} 

#>