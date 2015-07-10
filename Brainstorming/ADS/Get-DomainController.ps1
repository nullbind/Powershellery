#﻿# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
function Get-DomainController
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
        $CompFilter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))"
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $CompFilter
        $ObjSearcher.SearchScope = "Subtree"

        if ($SearchDN)
        {
            $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        # Create table for domain controllers
        $TblDCS = New-Object System.Data.DataTable 
        $TblDCS.Columns.Add("name") | Out-Null
        $TblDCS.Columns.Add("dnshostname") | Out-Null
        $TblDCS.Columns.Add("operatingsystem ") | Out-Null
        $TblDCS.Columns.Add("operatingsystemversion") | Out-Null 
        $TblDCS.Columns.Add("operatingsystemservicepack") | Out-Null
        $TblDCS.Columns.Add("whenchanged") | Out-Null
        $TblDCS.Columns.Add("logoncount") | Out-Null

        $ObjSearcher.FindAll() | ForEach-Object {             

             [string]$name = $_.properties.name
             [string]$dnshostname = $_.properties.dnshostname
             [string]$operatingsystem  = $_.properties.operatingsystem
             [string]$operatingsystemversion  = $_.properties.operatingsystemversion
             [string]$operatingsystemservicepack = $_.properties.operatingsystemservicepack
             [string]$whenchanged = $_.properties.whenchanged
             [string]$logoncount = $_.properties.logoncount             

             #add dc to table
            $TblDCS.Rows.Add($name,$dnshostname,$operatingsystem ,$operatingsystemversion ,$operatingsystemservicepack,$whenchanged,$logoncount) | Out-Null
         
         }
        
        return $TblDCS
    }

    End
    {

    }
}

