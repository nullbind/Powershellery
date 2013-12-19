

function Get-SPN
{
	<#
	.SYNOPSIS
	Displays Service Principal Names (SPN) for domain accounts based on SPN service name, 
	domain account, or domain group via LDAP queries.

	.DESCRIPTION
	Displays Service Principal Names (SPN) for domain accounts based on SPN service name, 
	domain account, or domain group via LDAP queries. This information can be used to 
	identify systems running specific services and the domain accounts running them.  
	For example, this script could be used to locate domain systems where SQL Server has been 
	installed.  It can also be used to help find systems where members of the Domain Admins 
	group might be logged in if the accounts where used to run services on the domain 
	(which is very common).  So this should be handy for both system administrators and 
	penetration testers.  The script currently supports trusted connections and provided
	credentials.
	
	.EXAMPLE	 
	Get-SPN  -type service -search "*www*"
	Get-SPN  -type service -search "MSSQLSvc*"
	Get-SPN  -type service -search "MSSQLSvc*" -List yes | format-table -autosize
	Get-SPN  -type service -search "*vnc*" -list yes | select server -Unique
	Get-SPN  -type service -search "MSSQLSvc*" -List yes | Select Server | format-table -autosize
	Get-SPN  -type service -search "MSSQLSvc*" -DomainController 192.168.1.100 -Credential domain\user
	Get-SPN  -type service -search "MSSQLSvc*" -List yes -DomainController 192.168.1.100 -Credential domain\user | format-table -autosize
	Get-SPN  -type service -search "MSSQLSvc*" -List yes -DomainController 192.168.1.100 -Credential domain\user | Select Server  | format-table -autosize

	.EXAMPLE	 
	Get-SPN  -type user -search "serveradmin"
	Get-SPN  -type user -search "sqladmin"
	Get-SPN  -type user -search "sqladmin" -List yes | format-table -autosize
	Get-SPN  -type user -search "sqladmin" -List yes | Select Server | format-table -autosize
	Get-SPN  -type user -search "sqladmin" -DomainController 192.168.1.100 -Credential domain\user
	Get-SPN  -type user -search "sqladmin" -List yes -DomainController 192.168.1.100 -Credential domain\user | format-table -autosize
	Get-SPN  -type user -search "sqladmin" -List yes -DomainController 192.168.1.100 -Credential domain\user | Select Server | format-table -autosize

	.EXAMPLE	 
	Get-SPN  -type group -search "Domain Users"
	Get-SPN  -type group -search "Domain Admins"
	Get-SPN  -type group -search "Domain Admins" -List yes | format-table -autosize
	Get-SPN  -type group -search "Domain Admins" -List yes | Select Server | format-table -autosize
	Get-SPN  -type group -search "Domain Admins" -DomainController 192.168.1.100 -Credential domain\user
	Get-SPN  -type group -search "Domain Admins" -List yes -DomainController 192.168.1.100 -Credential domain\user | format-table -autosize
	Get-SPN  -type group -search "Domain Admins" -List yes -DomainController 192.168.1.100 -Credential domain\user | Select Server | format-table -autosize
	
	.LINK
	http://www.netspi.com
	http://msdn.microsoft.com/en-us/library/windows/desktop/ms677949(v=vs.85).aspx
	http://technet.microsoft.com/en-us/library/cc731241.aspx
	http://technet.microsoft.com/en-us/library/cc978021.aspx
	
	.NOTES
	Author: Scott Sutherland 2013, NetSPI
	Version: Get-SPN v.1
	Requirements: Powershell v.3
	Comments: The technique used to query LDAP was based on the "Get-AuditDSDisabledUserAcount" 
	function found in Carols Perez's PoshSec-Mod project.	

	.TODO
	- Validate Powershell v3 with $PSVersionTable.psversion.Major
	- Validate the system is on a domain if no credentials are set with $env:USERDNSDOMAIN
	- Fix this - display message no services instances match search in list view
	- fix all help content so it actually shows up

	#>	
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]
        [string]$SearchDN,

        [Parameter(Mandatory=$True,
        HelpMessage="Search by domain user, domain group, or SPN service name to search for.")]
        [string]$Type,

        [Parameter(Mandatory=$True,
        HelpMessage="Define search for user, group, or SPN service name. Wildcards are accepted")]
        [string]$Search,

        [Parameter(Mandatory=$false,
        HelpMessage="View minimal information that includes the accounts,affected systems,and registered services.  Nice for getting quick list of DAs.")]
        [string]$List
    )

    Begin
    {        
        # Setup domain and user defiend domain controller(if defined)
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $ObjDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $ObjSearcher = New-Object System.DirectoryServices.DirectorySearcher $ObjDomain
        }
        else
        {
            $ObjDomain = [ADSI]""  
            $ObjSearcher = New-Object System.DirectoryServices.DirectorySearcher $ObjDomain
        }
    }

    Process
    {	
        # Setup LDAP queries
        $CurrentDomain = $ObjDomain.distinguishedName
        $QueryGroup = "(&(objectCategory=user)(memberOf=CN=$Search,CN=Users,$CurrentDomain))"
        $QueryUser = "(samaccountname=$Search)"
        $QueryService = "(ServicePrincipalName=$Search)"
        
        # Define the search type 
        if(($Type -eq "group") -or ($Type -eq "user") -or ($Type -eq "service")){

            # Define query based on type
            switch ($Type) 
            { 
                "group" {$MyFilter = $QueryGroup} 
                "user" {$MyFilter = $QueryUser} 
                "service" {$MyFilter = $QueryService} 
                default {"Invalid query type."}
            }
        }
		
        # Define LDAP query options
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $Myfilter
        $ObjSearcher.SearchScope = $SearchScope

        if ($SearchDN)
        {
            $ObjSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        # Get a count of the number of accounts that match the LDAP query
        $Records = $ObjSearcher.FindAll()
        $RecordCount = $Records.count

        # Display search results if results exist
        if ($RecordCount -gt 0){
                
            # Create data table to house results
            $DataTable = New-Object System.Data.DataTable 

            # Create and name columns in the data table
            $DataTable.Columns.Add("Account") | Out-Null
            $DataTable.Columns.Add("Server") | Out-Null
            $DataTable.Columns.Add("Service") | Out-Null            

            # Display account records                
            $ObjSearcher.FindAll() | ForEach-Object {

                # Fill hash array with results                    
                $UserProps = [ordered]@{}                    
                $UserProps.Add('Name', "$($_.properties.name)")
                $UserProps.Add('SAMAccount', "$($_.properties.samaccountname)")
                $UserProps.Add('Description', "$($_.properties.description)")
                $UserProps.Add('UserPrincipal', "$($_.properties.userprincipalname)")
                $UserProps.Add('DN', "$($_.properties.distinguishedname)")
                $UserProps.Add('Created', [dateTime]"$($_.properties.whencreated)")
                $UserProps.Add('LastModified', [dateTime]"$($_.properties.whenchanged)")
                $UserProps.Add('PasswordLastSet', [dateTime]::FromFileTime("$($_.properties.pwdlastset)"))                    
                $UserProps.Add('AccountExpires',( &{$exval = "$($_.properties.accountexpires)"
                    If (($exval -eq 0) -or ($exval -gt [DateTime]::MaxValue.Ticks))
                    {
                        $AcctExpires = "<Never>"
                        $AcctExpires
                    }Else{
                        $Date = [DateTime]$exval
                        $AcctExpires = $Date.AddYears(1600).ToLocalTime()
                        $AcctExpires
                    }
                }))
                $UserProps.Add('LastLogon', [dateTime]::FromFileTime("$($_.properties.lastlogon)"))
                $UserProps.Add('GroupMembership', "$($_.properties.memberof)")
                $UserProps.Add('SPN Count', "$($_.properties['ServicePrincipalName'].count)")                 

                # Only display line for detailed view
                If (!$list){

                    # Format array as object and display records
                    Write-Host " "
                    [pscustomobject]$UserProps 
                }

                # Get number of SPNs for accounts, parse them, and add them to the data table
                $SPN_Count = $_.properties['ServicePrincipalName'].count
                if ($SPN_Count -gt 0)
                {
                        
                    # Only display line for detailed view
                    If (!$list){
                        Write-Output "ServicePrincipalNames (SPN):"
                            $_.properties['ServicePrincipalName']
                    }
                        
                    # Add records to data table
                    foreach ($item in $_.properties['ServicePrincipalName'])
                    {
                        $SpnServer =  $item.split("/")[1].split(":")[0]	
                        $SpnService =  $item.split("/")[0]                                                    
                        $DataTable.Rows.Add($($_.properties.samaccountname), $SpnServer, $SpnService) | Out-Null  
                    }
                }            
                    
                # Only display line for detailed view
                If (!$list){
                    Write-Host " "
                    Write-Host "-------------------------------------------------------------"
                }
            } 

            # Only display lines for detailed view
            If (!$list){

                # Display number of accounts found
                Write-Host "Found $RecordCount accounts that matched your search."   
                Write-Host "-------------------------------------------------------------"
                Write-Host " "                                    

                # Dispaly list view of results
                #$DataTable |  Sort-Object Account,Server,Service | select account,server,service -Unique

                # Display number of service instances
                #$InstanceCount = $DataTable.rows.count
                #Write-Host "-------------------------------------------------------------"
                #Write-Host "Found $InstanceCount service instances that matched your search."
                #Write-Host "-------------------------------------------------------------"
            }else{

                # Dispaly list view of results in sorted order
                $DataTable |  Sort-Object Account,Server,Service | select account,server,service -Unique
            }
        }else{

            # Display fail
            Write-Host " " 
            Write-Host "No records were found that match your search."
            Write-Host ""
        }        
    }
}