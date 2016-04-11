# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
# -------------------------------------------
# Function: Get-DomainObject
# -------------------------------------------
# Based on Get-ADObject function from:
# https://github.com/PowerShellEmpire/PowerTools/blob/master/PowerView/powerview.ps1
function Get-DomainObject
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
        HelpMessage="Domain user to authenticate with domain\user.")]
        [string]$username,

        [Parameter(Mandatory=$false,
        HelpMessage="Domain password to authenticate with domain\user.")]
        [string]$password,

        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$false,
        HelpMessage="LDAP Filter.")]
        [string]$LdapFilter = "",

        [Parameter(Mandatory=$false,
        HelpMessage="LDAP path.")]
        [string]$LdapPath,

        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree"
    )
    Begin
    {
        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }        

        # Create Create the connection to LDAP       
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = (New-Object System.DirectoryServices.DirectoryEntry "LDAP://$DomainController", $Credential.UserName,$Credential.GetNetworkCredential().Password).distinguishedname
            
            # add ldap path
            if($LdapPath)
            {
                $LdapPath = "/"+$LdapPath+","+$objDomain
                $objDomainPath = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$DomainController$LdapPath", $Credential.UserName,$Credential.GetNetworkCredential().Password
            }else{
                $objDomainPath= New-Object System.DirectoryServices.DirectoryEntry "LDAP://$DomainController", $Credential.UserName,$Credential.GetNetworkCredential().Password
            }
            
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomainPath
        }else{
            $objDomain = ([ADSI]"").distinguishedName
            
            # add ldap path
            if($LdapPath)
            {
                $LdapPath = $LdapPath+","+$objDomain
                $objDomainPath  = [ADSI]"LDAP://$LdapPath"
            }else{
                $objDomainPath  = [ADSI]""
            }
              
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomainPath
        }

        # Setup LDAP filter
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $LdapFilter
        $ObjSearcher.SearchScope = "Subtree"
    }

    Process
    {        
        try
        {
            # Return object
            $ObjSearcher.FindAll() | ForEach-Object {
              
                $_
            }
        }
        catch
        {
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }                
    }

    End
    {
    }
}

function Get-DomainSpn
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
        HelpMessage="Domain user to authenticate with domain\user.")]
        [string]$username,

        [Parameter(Mandatory=$false,
        HelpMessage="Domain password to authenticate with domain\user.")]
        [string]$password,

        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="Computer name to filter on.")]
        [string]$ComputerName,

        [Parameter(Mandatory=$false,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        HelpMessage="User name to filter on.")]
        [string]$User
    )

    Begin
    {
        Write-Verbose "Getting domain SPNs..."

        # Setup table to store results
        $TableDomainSpn = New-Object System.Data.DataTable
        $TableDomainSpn.Columns.Add('UserSid') | Out-Null
        $TableDomainSpn.Columns.Add('User') | Out-Null
        $TableDomainSpn.Columns.Add('UserCn') | Out-Null
        $TableDomainSpn.Columns.Add('Service') | Out-Null
        $TableDomainSpn.Columns.Add('ComputerName') | Out-Null
        $TableDomainSpn.Columns.Add('Spn') | Out-Null
        $TableDomainSpn.Columns.Add('LastLogon') | Out-Null
        $TableDomainSpn.Columns.Add('Description') | Out-Null
        $TableDomainSpn.Clear()
    }

    Process
    {

        try
        {
            # Setup LDAP filter
            $SpnFilter = ""

            if($User){
                $SpnFilter = "(objectcategory=person)(SamAccountName=$User)"
            }

            if($ComputerName){
                $ComputerSearch = "$ComputerName`$"
                $SpnFilter = "(objectcategory=computer)(SamAccountName=$ComputerSearch)"
            }

            # Get results
            $SpnResults = Get-DomainObject -LdapFilter "(&(servicePrincipalName=*)$SpnFilter)" -DomainController $DomainController -username $username -password $password -Credential $Credential

            # Parse results
            $SpnResults | ForEach-Object {

                [string]$SidBytes = [byte[]]"$($_.Properties.objectsid)".split(" ");
                [string]$SidString = $SidBytes -replace ' ',''
                $Spn = $_.properties.serviceprincipalname.split(",")
                           
                foreach ($item in $Spn)
                {
                    # Parse SPNs
                    $SpnServer =  $item.split("/")[1].split(":")[0].split(' ')[0]
                    $SpnService =  $item.split("/")[0]

                    # Add results to table
                    $TableDomainSpn.Rows.Add(
                    [string]$SidString,
                    [string]$_.properties.samaccountname,
                    [string]$_.properties.cn,
                    [string]$SpnService,
                    [string]$SpnServer, 
                    [string]$item,
                    [string]$_.properties.lastlogon,
                    [string]$_.properties.description
                 ) | Out-Null
                }
             }
        }catch{
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }
    }

    End
    {
        # Check for results
        if ($TableDomainSpn.Rows.Count -gt 0)
        {
            $TableDomainSpnCount = $TableDomainSpn.Rows.Count
            Write-Verbose "$TableDomainSpnCount SPNs were found that matched the search."
            Return $TableDomainSpn 
        }else{
            Write-Verbose "0 SPNs were found that matched the search."
        }
    }
}
