# Get-DomainTrusts -DomainController dc1.acme.com -Credential acme.com\user

function Get-DomainTrusts
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
        
        $CompFilter = "(objectClass=trustedDomain)"
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $CompFilter
        $ObjSearcher.SearchScope = "Subtree"

        if ($SearchDN)
        {
            $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        #﻿# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
        # Create data table to house results
        $TblTrusts = New-Object System.Data.DataTable 
        $TblTrusts.Columns.Add("trustpartner") | Out-Null
        $TblTrusts.Columns.Add("distinguishedname") | Out-Null
        $TblTrusts.Columns.Add("trusttype") | Out-Null
        $TblTrusts.Columns.Add("trustdirection") | Out-Null
        $TblTrusts.Columns.Add("trustattributes") | Out-Null
        $TblTrusts.Columns.Add("whenchanged") | Out-Null
        $TblTrusts.Columns.Add("objectclass") | Out-Null

        $ObjSearcher.FindAll() | ForEach-Object {
             
            [string]$name = $_.properties.name
            [string]$trustpartner = $_.properties.trustpartner
            [string]$distinguishedname = $_.properties.distinguishedname
            [string]$trusttype = $_.properties.trusttype
            [string]$trustdirection = $_.properties.trustdirection
            [string]$trustattributes = $_.properties.trustattributes
            [string]$whenchanged = $_.properties.whenchanged
            [string]$objectclass = $_.properties.objectclass

            #add trust to table
            $TblTrusts.Rows.Add($trustpartner,$distinguishedname,$trusttype,$trustdirection,$trustattributes,$whenchanged,$objectclass) | Out-Null
         }
        
        return $TblTrusts
    }

    End
    {
        
    }
}

