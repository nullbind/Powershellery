function Get-SiteAndSubnet
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
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000.")]
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

        $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain

        # get dn of the configuration partiion in the current forrest
        $cfg = ([ADSI] "LDAP://RootDSE").configurationNamingContext

        # get the site container
        $Sites = [ADSI] "LDAP://CN=Sites,$cfg"

        # loop through each object in the site container
        foreach ($site in $sites.children)
        {
            if ($site.objectcategory -like "CN=Site*")
            {
                $site.name
            }
       }

}
}