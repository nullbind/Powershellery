<#
	.SYNOPSIS
    Displays the clear text passwords for custom application pool idenities.
	
	.NOTES
	Must be run as administrator.
    Scott Sutherland 2013, NetSPI
#>

Write-Host "Services that are not registered securely:"
Get-WmiObject -class win32_service | where pathname -notlike "*`"*" | select displayname, pathname | Format-Table -AutoSize