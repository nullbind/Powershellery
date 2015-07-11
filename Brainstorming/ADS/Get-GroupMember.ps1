# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
# author: scott sutherland (@_nullbind), netspi 2015
# description: this will use adsi to query for domain group memebers.  It can be used from a non domain systems.
# Get-GroupMember -Group "Enterprise Admins"
# Get-GroupMember -DomainController dc1.acme.com -Credential acme.com\user1 -Group "Enterprise Admins"
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

