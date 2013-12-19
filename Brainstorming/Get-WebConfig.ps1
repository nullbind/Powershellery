<#
	.SYNOPSIS
    Displays the clear text connection strings from web.config files.
	
	.NOTES
	Must be run as administrator.  
	Requires IIS 6 or above in order to support Aspnet_regiis.exe.
#>

# Aspnet_regiis.exe installs off of C:\Windows\Microsoft.NET\Framework\ by default
# Get list of Aspnet_regiis.exe file paths
$MyFiles = Get-ChildItem -Path C:\Windows\Microsoft.NET\Framework\  -filter Aspnet_regiis.exe -recurse | select fullname

# Check if Aspnet_regiis.exe exists
if($MyFiles.count -gt 0){

	# Parse out path for first instance of Aspnet_regsql.exe
	$MyEXE = $MyFiles.fullname | select -first 1
	$MyEXE
	
	# Get physical paths for all installed IIS web applications
	# appcmd list vdir /text:physicalpaths
	
	# Dump clear text connection strings
	
	# Dump encrypted connection strings in clear text (where the web.config has been copied to c:\)
	# Encrypt = aspnet_regiis.exe -pef connectionStrings "c:\"
	# Decrypt = aspnet_regiis.exe -pdf connectionStrings "c:\" 
	# http://msdn.microsoft.com/en-us/library/zhhddkxy%28v=vs.100%29.aspx
	
}else{
	Write-Host "Aspnet_regiis.exe doesn't appear to be installed!"
}


