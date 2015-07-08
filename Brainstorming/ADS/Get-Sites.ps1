# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
﻿# need to fix so it also works on remote dc, only works locally at the moment
function Get-Sites
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
            $site = ([ADSI] "LDAP://$DomainController/RootDSE").configurationNamingContext
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
        else
        {
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain

            $Site = [ADSI] "LDAP://CN=Sites,CN=Configuration,DC=netspi,DC=local"
            $SiteCfg = ([ADSI] "LDAP://RootDSE").configurationNamingContext
            $Site = ([ADSI] "LDAP://RootDSE").configurationNamingContext
        }
    }

    Process
    {
        
        
        $site 

        $CompFilter = ""
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $CompFilter
        $ObjSearcher.SearchScope = "Subtree"

        #$sitesDN = "LDAP://CN=Sites," + $([adsi] "LDAP://$DomainController/RootDSE").Get("ConfigurationNamingContext")                     
        #$subnetsDN="LDAP://CN=Subnets,CN=Sites," + $([adsi] "LDAP://$DomainController/RootDSE").Get("ConfigurationNamingContext")

        #$SearchDN = "CN=Sites"

        #if ($SearchDN)
        #{
            #$objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DomainController/RootDSE")
        #}

        $ObjSearcher.FindAll() | ForEach-Object {
             $_.properties
         }
        
    }

    End
    {

    }
}

