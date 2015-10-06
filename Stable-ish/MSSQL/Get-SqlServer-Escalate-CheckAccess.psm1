# This ps1 files include functions to support the Dump-DomainInfo.ps1 function.


# ------------------------------
# Function: Get-DomainTrusts
# ------------------------------
Function Get-DomainTrusts {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
        HelpMessage="Domain user to authenticate with domain\user.")]
        [string]$username,

        [Parameter(Mandatory=$false,
        HelpMessage="Domain password to authenticate with domain\user.")]
        [string]$password,
        
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
        Write-Verbose "Getting domain trusts..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {
        try
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
        
            if($TblTrusts.Rows.Count -gt 0)
            {
                $TblTrustsCount = $TblTrusts.Rows.Count
                Write-Verbose "$TblTrustsCount  domain trusts were found."
                return $TblTrusts
            }else{
                Write-Verbose "0 domain trusts were found."
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


# -------------------------------
# Function: Get-DomainControllers
# -------------------------------        
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
function Get-DomainControllers
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
        Write-Verbose "Getting domain controllers..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create LDAP connection
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {
        try
        {                
            # Create table for domain controllers
            $TableDomainControllers = New-Object System.Data.DataTable 
            $TableDomainControllers.Columns.Add("name") | Out-Null
            $TableDomainControllers.Columns.Add("dnshostname") | Out-Null
            $TableDomainControllers.Columns.Add("operatingsystem ") | Out-Null
            $TableDomainControllers.Columns.Add("operatingsystemversion") | Out-Null 
            $TableDomainControllers.Columns.Add("operatingsystemservicepack") | Out-Null
            $TableDomainControllers.Columns.Add("whenchanged") | Out-Null
            $TableDomainControllers.Columns.Add("logoncount") | Out-Null
            $TableDomainControllers.Columns.Add("description") | Out-Null   
            $TableDomainControllers.Clear()         

            # Setup LDAP filter
            $CompFilter = "(&(objectCategory=computer)(userAccountControl:1.2.840.113556.1.4.803:=8192))"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }

            # Add domain controllers to table
            $ObjSearcher.FindAll() | ForEach-Object {             
                
                $TableDomainControllers.Rows.Add(
                [string]$_.properties.name,
                [string]$_.properties.dnshostname,
                [string]$_.properties.operatingsystem,
                [string]$_.properties.operatingsystemversion,
                [string]$_.properties.operatingsystemservicepack,
                [string]$_.properties.whenchanged,
                [string]$_.properties.logoncount, 
                [string]$_.properties.description   
                ) | Out-Null
         
            }
        
            # Check for domain controllers
            if($TableDomainControllers.Rows.Count -gt 0)
            {
                $TableDomainControllersCount = $TableDomainControllers.Rows.Count
                Write-Verbose "$TableDomainControllersCount domain controllers found."
                return $TableDomainControllers
            }else{
                Write-Verbose "No domain controllers found."
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



# -------------------------------------------
# Function: Get-DomainDcRoleNameMaster
# ------------------------------------------- 
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx 
Function Get-DomainDcRoleNameMaster{
}


# -------------------------------------------
# Function: Get-DomainDcRoleGlobalCatalog
# -------------------------------------------  
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
Function Get-DomainDcRoleGlobalCatalog{
}


# -------------------------------------------
# Function: Get-DomainDcRoleInfrastructureMaster
# -------------------------------------------  
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
Function Get-DomainDcRoleInfrastructureMaster{
}


# -------------------------------------------
# Function: Get-DomainDcRolePDC
# ------------------------------------------- 
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx  
Function Get-DomainDcRolePDC{
}


# -------------------------------------------
# Function: Get-DomainDcRoleRidMaster
# -------------------------------------------
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx  
Function Get-DomainDcRoleRidMaster{
}

        
        
# -------------------------------------------
# Function: Get-DomainDcRoleSchemaMaster
# -------------------------------------------   
#﻿ Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
Function Get-DomainDcRoleSchemaMaster{
}


     
# -------------------------------------------
# Function: Get-DomainUsers
# -------------------------------------------
# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
function Get-DomainUsers
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

        Write-Verbose "Getting domain users..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {

        try
        {          
        
            # Setup table for domain users
            $TableDomainUsers = New-Object System.Data.DataTable
            $TableDomainUsers.Columns.Add("objectsid") | Out-Null
            $TableDomainUsers.Columns.Add("samaccountname") | Out-Null
            $TableDomainUsers.Columns.Add("samaccounttype") | Out-Null
            $TableDomainUsers.Columns.Add("userprincipalname") | Out-Null
            $TableDomainUsers.Columns.Add("displayname") | Out-Null
            $TableDomainUsers.Columns.Add("givenname") | Out-Null
            $TableDomainUsers.Columns.Add("sn") | Out-Null
            $TableDomainUsers.Columns.Add("description") | Out-Null
            $TableDomainUsers.Columns.Add("admincount") | Out-Null
            $TableDomainUsers.Columns.Add("homedirectory") | Out-Null
            $TableDomainUsers.Columns.Add("memberof") | Out-Null
            $TableDomainUsers.Clear()

            # Setup the LDAP filter
            $CompFilter = "(&(objectCategory=person)(objectClass=user))"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }

            # Add domain user information to table
            $ObjSearcher.FindAll() | ForEach-Object {

                [string]$SidBytes = [byte[]]"$($_.Properties.objectsid)".split(" ");
                [string]$SidString = $SidBytes -replace ' ',''
                $TableDomainUsers.Rows.Add( 
                [string]$SidString,
                [string]$_.properties.samaccountname,
                [string]$_.properties.samaccounttype,
                [string]$_.properties.userprincipalname,
                [string]$_.properties.displayname,
                [string]$_.properties.givenname,
                [string]$_.properties.sn,  
                [string]$_.properties.description,       
                [string]$_.properties.admincount,
                [string]$_.properties.homedirectory,
                [string]$_.properties.memberof
                ) | Out-Null                        
            }

            # Check for domain users
            if($TableDomainUsers.Rows.Count -gt 0)
            {
                $TableDomainUsersCount = $TableDomainUsers.Rows.Count
                Write-Verbose "$TableDomainUsersCount domain users found."
                Return $TableDomainUsers
            }else{
                Write-Verbose "0 domain users were found."
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


# -------------------------------------------
# Function: Get-DomainGroupMembers
# -------------------------------------------
# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
function Get-DomainGroupMembers
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
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$true,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [string]$Group,

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
        Write-Verbose "Getting members of the `"$group`" group..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }
      
        # Create LDAP connection
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $root = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $rootdn = $root | select distinguishedName -ExpandProperty distinguishedName
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)/CN=$Group, CN=Users,$rootdn" , $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $root = ([ADSI]"").distinguishedName
            $objDomain = [ADSI]("LDAP://CN=$Group, CN=Users," + $root)  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }    

    Process
    {
        try
        {
            # Create data table for group members
            $TblMembers = New-Object System.Data.DataTable
            $TblMembers.Columns.Add("Group") | Out-Null 
            $TblMembers.Columns.Add("GroupMember") | Out-Null 
            $TblMembers.Clear()

            # Add group members to table
            $MemberCount = $objDomain.member.count
            Write-Verbose "$MemberCount members found in the `"$group`" group."
            if($MemberCount -gt 0)
            {
                $objDomain.member | %{                    
                    $TblMembers.Rows.Add($group,$_.split("=")[1].split(",")[0]) | Out-Null 
                }
                Return $TblMembers
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


# -------------------------------------------
# Function: Get-UserGroupMemberships
# -------------------------------------------
Function Get-DomainUserGroups {
    Write-Verbose "Getting groups the user is a member of..."
}
        

# -------------------------------------------
# Function: Get-DomainNetworks
# -------------------------------------------
Function Get-DomainNetworks {
    Write-Verbose "Getting domain networks..."
}
        

# -------------------------------------------
# Function: Get-DomainComputers
# -------------------------------------------
function Get-DomainComputers
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
        Write-Verbose "Getting domain computers..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {
        
        try
        {
            # Setup table for domain computers
            $TableDomainComputers = New-Object System.Data.DataTable
            $TableDomainComputers.Columns.Add('ObjectSid') | Out-Null 
            $TableDomainComputers.Columns.Add('SamAccountName') | Out-Null  
            $TableDomainComputers.Columns.Add('dnshostname') | Out-Null        
            $TableDomainComputers.Columns.Add('cn') | Out-Null 
            $TableDomainComputers.Columns.Add('OperatingSystem') | Out-Null
            $TableDomainComputers.Columns.Add('ServicePack') | Out-Null
            $TableDomainComputers.Columns.Add('Description') | Out-Null
            $TableDomainComputers.Columns.Add('MemeberOf') | Out-Null
            $TableDomainComputers.Columns.Add('LapsPassword') | Out-Null
            $TableDomainComputers.Clear()


            # Setup LDAP filter
            $CompFilter = "(objectCategory=Computer)"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }

            # Add domain computers to table
            $ObjSearcher.FindAll() | ForEach-Object {
              
                [string]$SidBytes = [byte[]]"$($_.Properties.objectsid)".split(" ")
                [string]$SidString = $SidBytes -replace ' ',''

                $TableDomainComputers.Rows.Add( 
                [string]$SidString,
                [string]$_.properties.samaccountname,
                [string]$_.properties.dnshostname,
                [string]$_.properties.cn,
                [string]$($_.properties['operatingsystem']), 
                [string]$($_.properties['operatingsystemservicepack']),
                [string]$_.properties.description,  
                [string]$_.properties.memberof,
                [string]$($_.properties['ms-MCS-AdmPwd'])             
                ) | Out-Null
            }

            # Check for domain computers
            if($TableDomainComputers.Rows.Count -gt 0)
            {
                $TableDomainComputersCount = $TableDomainComputers.Rows.Count
                Write-Verbose "$TableDomainComputersCount domain computers found."
                Return $TableDomainComputers
            }else{
                Write-Verbose "0 domain computers were found."
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


function Get-DomainPasswordsLAPS
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
        Write-Verbose "Getting domain LAPS passwords..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {        
        try
        {              
            # Create data table for LAPS information
            $TableLAPS = New-Object System.Data.DataTable 
            $TableLAPS.Columns.Add('Hostname') | Out-Null
            $TableLAPS.Columns.Add('Password') | Out-Null
            $TableLAPS.Clear()

            # Setup LDAP filter for domain computers
            $CompFilter = "(&(objectCategory=Computer))"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }            

            # Add LAPS passwords to the table
            $ObjSearcher.FindAll() | ForEach-Object {

                $CurrentHost = $($_.properties['dnshostname'])
			    $CurrentPassword = $($_.properties['ms-MCS-AdmPwd'])

                # Check for readable password and add to table
                if ($CurrentPassword.length -ge 1)
                {
                    # Add domain computer to data table
                    $TableLAPS.Rows.Add($CurrentHost,$CurrentPassword) | Out-Null
                }                
             }

            # Check for LAPS passwords
            if($TableLAPS.Rows.Count -gt 0)
            {
                $TableLAPsCount = $TableLAPS.Rows.Count
                Write-Verbose "$TableLAPSCount LAPS passwords found."
                Return $TableLAPS
            }else{
                Write-Verbose "0 LAPS passwords were found."
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

        

# -------------------------------------------
# Function: Get-DomainExploitableSystems
# -------------------------------------------
function Get-DomainExploitableSystems
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

        Write-Verbose "Getting exploitable domain computers..."

        # Create PS Credential object
        if($Password)
        {
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        } 
    }

    Process
    {    
        # Create data table for hostnames, os, and service packs from LDAP
        $TableAdsComputers = New-Object System.Data.DataTable 
        $TableAdsComputers.Columns.Add('Hostname') | Out-Null        
        $TableAdsComputers.Columns.Add('OperatingSystem') | Out-Null
        $TableAdsComputers.Columns.Add('ServicePack') | Out-Null
        $TableAdsComputers.Columns.Add('LastLogon') | Out-Null

        # Setup LDAP filter
        $CompFilter = "(&(objectCategory=Computer))"
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $CompFilter
        $ObjSearcher.SearchScope = "Subtree"

        if ($SearchDN)
        {
            $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        # Add computers to table
        $ObjSearcher.FindAll() | ForEach-Object {

            # Setup fields
            $CurrentHost = $($_.properties['dnshostname'])
            $CurrentOs = $($_.properties['operatingsystem'])
            $CurrentSp = $($_.properties['operatingsystemservicepack'])
            $CurrentLast = $($_.properties['lastlogon'])
            $CurrentUac = $($_.properties['useraccountcontrol'])

            # Convert useraccountcontrol to binary so flags can be checked
            # http://support.microsoft.com/en-us/kb/305144
            # http://blogs.technet.com/b/askpfeplat/archive/2014/01/15/understanding-the-useraccountcontrol-attribute-in-active-directory.aspx
            $CurrentUacBin = [convert]::ToString($CurrentUac,2)

            # Check the 2nd to last value to determine if its disabled
            $DisableOffset = $CurrentUacBin.Length - 2
            $CurrentDisabled = $CurrentUacBin.Substring($DisableOffset,1)

            # Add computer to list if it's enabled
            if ($CurrentDisabled  -eq 0){

                # Add domain computer to data table
                $TableAdsComputers.Rows.Add($CurrentHost,$CurrentOS,$CurrentSP,$CurrentLast) | Out-Null 
            }            
 
         }
    
        # Create data table for list of patches levels with a MSF exploit
        $TableExploits = New-Object System.Data.DataTable 
        $TableExploits.Columns.Add('OperatingSystem') | Out-Null 
        $TableExploits.Columns.Add('ServicePack') | Out-Null
        $TableExploits.Columns.Add('MsfModule') | Out-Null  
        $TableExploits.Columns.Add('CVE') | Out-Null
        
        # Add exploits to data table
        $TableExploits.Rows.Add("Windows 7","","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Server Pack 1","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Server Pack 1","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Server Pack 1","exploit/windows/iis/ms03_007_ntdll_webdav","http://www.cvedetails.com/cve/2003-0109") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Server Pack 1","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 2","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 2","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 2","exploit/windows/iis/ms03_007_ntdll_webdav","http://www.cvedetails.com/cve/2003-0109") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 2","exploit/windows/smb/ms04_011_lsass","http://www.cvedetails.com/cve/2003-0533/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 2","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 3","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 3","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 3","exploit/windows/iis/ms03_007_ntdll_webdav","http://www.cvedetails.com/cve/2003-0109") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 3","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/dcerpc/ms07_029_msdns_zonename","http://www.cvedetails.com/cve/2007-1748") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/smb/ms04_011_lsass","http://www.cvedetails.com/cve/2003-0533/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/smb/ms06_066_nwapi","http://www.cvedetails.com/cve/2006-4688") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/smb/ms06_070_wkssvc","http://www.cvedetails.com/cve/2006-4691") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","Service Pack 4","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","","exploit/windows/iis/ms03_007_ntdll_webdav","http://www.cvedetails.com/cve/2003-0109") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","","exploit/windows/smb/ms05_039_pnp","http://www.cvedetails.com/cve/2005-1983") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2000","","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Server Pack 1","exploit/windows/dcerpc/ms07_029_msdns_zonename","http://www.cvedetails.com/cve/2007-1748") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Server Pack 1","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Server Pack 1","exploit/windows/smb/ms06_066_nwapi","http://www.cvedetails.com/cve/2006-4688") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Server Pack 1","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Server Pack 1","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Service Pack 2","exploit/windows/dcerpc/ms07_029_msdns_zonename","http://www.cvedetails.com/cve/2007-1748") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Service Pack 2","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","Service Pack 2","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003","","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003 R2","","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003 R2","","exploit/windows/smb/ms04_011_lsass","http://www.cvedetails.com/cve/2003-0533/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003 R2","","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2003 R2","","exploit/windows/wins/ms04_045_wins","http://www.cvedetails.com/cve/2004-1080/") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2008","Service Pack 2","exploit/windows/smb/ms09_050_smb2_negotiate_func_index","http://www.cvedetails.com/cve/2009-3103") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2008","Service Pack 2","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2008","","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2008","","exploit/windows/smb/ms09_050_smb2_negotiate_func_index","http://www.cvedetails.com/cve/2009-3103") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2008","","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Server 2008 R2","","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","Server Pack 1","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","Server Pack 1","exploit/windows/smb/ms09_050_smb2_negotiate_func_index","http://www.cvedetails.com/cve/2009-3103") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","Server Pack 1","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","Service Pack 2","exploit/windows/smb/ms09_050_smb2_negotiate_func_index","http://www.cvedetails.com/cve/2009-3103") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","Service Pack 2","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows Vista","","exploit/windows/smb/ms09_050_smb2_negotiate_func_index","http://www.cvedetails.com/cve/2009-3103") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Server Pack 1","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Server Pack 1","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Server Pack 1","exploit/windows/smb/ms04_011_lsass","http://www.cvedetails.com/cve/2003-0533/") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Server Pack 1","exploit/windows/smb/ms05_039_pnp","http://www.cvedetails.com/cve/2005-1983") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Server Pack 1","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 2","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 2","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 2","exploit/windows/smb/ms06_066_nwapi","http://www.cvedetails.com/cve/2006-4688") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 2","exploit/windows/smb/ms06_070_wkssvc","http://www.cvedetails.com/cve/2006-4691") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 2","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 2","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 3","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","Service Pack 3","exploit/windows/smb/ms10_061_spoolss","http://www.cvedetails.com/cve/2010-2729") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","","exploit/windows/dcerpc/ms03_026_dcom","http://www.cvedetails.com/cve/2003-0352/") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","","exploit/windows/dcerpc/ms05_017_msmq","http://www.cvedetails.com/cve/2005-0059") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","","exploit/windows/smb/ms06_040_netapi","http://www.cvedetails.com/cve/2006-3439") | Out-Null  
        $TableExploits.Rows.Add("Windows XP","","exploit/windows/smb/ms08_067_netapi","http://www.cvedetails.com/cve/2008-4250") | Out-Null  

        # Create data table to house vulnerable server list
        $TableVulnComputers = New-Object System.Data.DataTable 
        $TableVulnComputers.Columns.Add('ComputerName') | Out-Null
        $TableVulnComputers.Columns.Add('OperatingSystem') | Out-Null
        $TableVulnComputers.Columns.Add('ServicePack') | Out-Null
        $TableVulnComputers.Columns.Add('LastLogon') | Out-Null
        $TableVulnComputers.Columns.Add('MsfModule') | Out-Null  
        $TableVulnComputers.Columns.Add('CVE') | Out-Null   
        
        # Iterate through each exploit
        $TableExploits | 
        ForEach-Object {
                     
            $ExploitOS = $_.OperatingSystem
            $ExploitSP = $_.ServicePack
            $ExploitMsf = $_.MsfModule
            $ExploitCve = $_.CVE

            # Iterate through each ADS computer
            $TableAdsComputers | 
            ForEach-Object {
                
                $AdsHostname = $_.Hostname
                $AdsOS = $_.OperatingSystem
                $AdsSP = $_.ServicePack                                                        
                $AdsLast = $_.LastLogon
                
                # Add exploitable systems to vul computers data table
                if ($AdsOS -like "$ExploitOS*" -and $AdsSP -like "$ExploitSP" ){                    
                   
                    # Add domain computer to data table                    
                    $TableVulnComputers.Rows.Add($AdsHostname,$AdsOS,$AdsSP,[dateTime]::FromFileTime($AdsLast),$ExploitMsf,$ExploitCve) | Out-Null 
                }

            }

        }     
        

        # Check for vulnerable servers
        $VulnComputer = $TableVulnComputers | select ComputerName -Unique | measure
        $vulnComputerCount = $VulnComputer.Count
        If ($VulnComputer.Count -gt 0){

            Write-Verbose "$vulnComputerCount potentially exploitable systems found."
            Return $TableVulnComputers | Sort-Object { $_.lastlogon -as [datetime]} -Descending

        }else{

            Write-Verbose "0 potentially exploitable domain systems were found."

        }      

    }

    End
    {

    }
}             
           
        
# -------------------------------------------
# Function: Get-Spn
# -------------------------------------------
# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
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
        Write-Verbose "Getting domain SPNs..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {

        try
        {        
            # Setup table for domain SPN information
            $TableDomainSpn = New-Object System.Data.DataTable
            $TableDomainSpn.Columns.Add('SpnAccountObjectSid') | Out-Null 
            $TableDomainSpn.Columns.Add('SpnSamAccountName') | Out-Null
            $TableDomainSpn.Columns.Add('SpnCn') | Out-Null 
            $TableDomainSpn.Columns.Add('SpnService') | Out-Null
            $TableDomainSpn.Columns.Add('SpnServer') | Out-Null
            $TableDomainSpn.Columns.Add('Spn') | Out-Null                     
            $TableDomainSpn.Columns.Add('lastlogon') | Out-Null  
            $TableDomainSpn.Columns.Add('Description') | Out-Null 
            $TableDomainSpn.Clear()               
            
            # Setup the LDAP filter        
            $CompFilter = "(servicePrincipalName=*)"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }

            # Add SPNs to the table
            $ObjSearcher.FindAll() | ForEach-Object {                 

                [string]$SidBytes = [byte[]]"$($_.Properties.objectsid)".split(" ");
                [string]$SidString = $SidBytes -replace ' ',''
                $Spn = $_.properties.serviceprincipalname.split(",")
                           
                foreach ($item in $Spn)
                {
                    $SpnServer =  $item.split("/")[1].split(":")[0].split(' ')[0]
                    $SpnService =  $item.split("/")[0]    
                
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
               
             # Check for SPNs
             if ($TableDomainSpn.Rows.Count -gt 0)
             {
               $TableDomainSpnCount = $TableDomainSpn.Rows.Count
               Write-Verbose "$TableDomainSpnCount SPNs were found."
               Return $TableDomainSpn 
             }else{
               Write-Verbose "No SPNs were found."              
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

# -------------------------------------------
# Function: Get-DomainDfsServers
# -------------------------------------------
# Ref: https://github.com/PowerShellEmpire/PowerTools/pull/51/files
function Get-DomainDfsServers
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
        Write-Verbose "Getting domain file servers from DFS LDAP queries..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {

        try
        {        
            # Setup table for DFS server information
            $TableDFSServers = New-Object System.Data.DataTable
            $TableDFSServers.Columns.Add('name') | Out-Null 
            $TableDFSServers.Columns.Add('remoteservername') | Out-Null  
            $TableDFSServers.Clear()            
            
            # Setup LDAP filter        
            $CompFilter = "(&(objectClass=fTDfs))"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }

            # Add DFS servers to the table
            $ObjSearcher.FindAll() | ForEach-Object {        
                $_.properties.name                  
                $_.properties.remoteservername

                $TableDFSServers.Rows.Add( 
                    [string]$_.properties.name,                
                    [string]$_.properties.remoteservername             
                 ) | Out-Null               
            }
               
            # Check for DFS servers
            if($TableDFSServers.Rows.Count -gt 0)
            {
                Return $TableDFSServers            
            }else{
                #Write-Verbose "No DFS servers found."
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


# -------------------------------------------
# Function: Get-DomainFileServers
# -------------------------------------------
# Note: Need to fix recursion
function Get-DomainFileServers
{    
    [CmdletBinding(DefaultParametersetName="Default")]
    Param(

        [Parameter(Mandatory=$false,
        HelpMessage="Domain user to authenticate with domain\user.")]
        [string]$username,

        [Parameter(Mandatory=$false,
        HelpMessage="Domain password to authenticate with domain\user.")]
        [string]$password,
        
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
        Write-Verbose "Getting domain file servers..."

        # Create PS Credential object
        if($Password)
        {            
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {        
        
        # Setup data table to store file servers        
        $TableFileServers = New-Object System.Data.DataTable 
        $TableFileServers.Columns.Add('ComputerName') | Out-Null
        $TableFileServers.Columns.Add('SharePath') | Out-Null
        $TableFileServers.Columns.Add('ShareDrive') | Out-Null
        $TableFileServers.Columns.Add('ShareLabel') | Out-Null
        $TableFileServers.Columns.Add('Source') | Out-Null
        $TableFileServers.Clear()

        # ----------------------------------------------------------------
        # Enumerate Domain File Servers via LDAP User Properties
        # ----------------------------------------------------------------        
        try
        {                
        
            # Status user        
            Write-Verbose "Getting domain file servers from the HomeDirectory, ScriptPath, and ProfilePath LDAP user properties..."

            $SAMAccountFilter = "(sAMAccountType=805306368)"
        
            # Search parameters
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = "(&(objectCategory=Person))"
            $ObjSearcher.SearchScope = $SearchScope

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }
        
            # Add fileservers from scriptpath property 
            $ObjSearcher.FindAll() | ForEach-Object {      
            
                # Check ScriptPath Property          
                if ($_.properties.scriptpath){           
                    [string]$ScriptFileServer = $_.properties.scriptpath.split("\\")[2];
                    [string]$ScriptSharePath =  $_.properties.scriptpath
              
                    $TableFileServers.Rows.Add($ScriptFileServer,$ScriptSharePath,"","","ScriptPath") | Out-Null
                }

                # Check HomeDirectory Property
                if ($_.properties.homedirectory){           
                    [string]$HomeFileServer = $_.properties.homedirectory.split("\\")[2];
                    [string]$HomeSharePath =  $_.properties.homedirectory
                    [string]$HomeDrive = $_.properties.homedrive
                
                    if ($HomeDrive) {
                        $HomeShareDrive = $HomeDrive
                    }else{
                        $HomeShareDrive = ""
                    }
                              
                    $TableFileServers.Rows.Add($HomeFileServer,$HomeSharePath,$HomeShareDrive,"","HomeDirectory") | Out-Null
                }

                # Check ProfilePath Property
                if ($_.properties.profilepath){           
                    [string]$ScriptFileServer = $_.properties.profilepath.split("\\")[2];
                    [string]$ScriptSharePath =  $_.properties.profilepath
              
                    $TableFileServers.Rows.Add($ScriptFileServer,$ScriptSharePath,"","","ProfilePath") | Out-Null
                }
            }                    
        }
        catch
        {
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }


        # ----------------------------------------------------------------
        # Enumerate Domain File Servers via LDAP Computer Properties - DFS
        # ----------------------------------------------------------------
        try
        {
            # Get list of DFS servers
            $TableDFSServers = Get-DomainDFSServers -username $username -password $password -DomainController $DomainController
            if($TableDFSServers.Rows.Count -gt 0)
            {
                # Add DFS servers to file server table
                $TableDFSServers | 
                ForEach-Object {                                
                    $TableFileServers.Rows.Add($_.remoteservername,$_.name,"","","DFS") | Out-Null
                }         
            }
        }
        catch
        {
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }
        
        
        # ----------------------------------------------------------------
        # Enumerate Domain File Servers via Drives.xml on DC sysvol share
        # ----------------------------------------------------------------
        # Note: figure out how to auth to the smb share using unc path without havin to mount the share
        try
        {                    

            # Grab DC
            if($DomainController){
                $TargetDC = "\\$DomainController"
            }else{
                $TargetDC = $env:LOGONSERVER
            }            

            # Create randomish name for dynamic mount point etc
            $set = "abcdefghijklmnopqrstuvwxyz".ToCharArray();
            $result += $set | Get-Random -Count 10
            $DriveName = [String]::Join("",$result)             
            $DrivePath = "$TargetDC\sysvol" 
            
            # Status user                    
            Write-Verbose "Getting domain file servers from Drives.xml files on $DrivePath..."               

            # Map a temp drive to the DC       
            Write-Verbose "Creating temp share $DriveName to $DrivePath..."
            If ($Credential.UserName){                                
                New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath -Credential $Credential | Out-Null
            }else{                
                New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath | Out-Null
            }

            # Parse out drives.xml files into the data table
            $TempDrive = $DriveName+":"
            cd $TempDrive  
        
            # access file via known unc path with ipc$ connection instead of mounting a drive
            #Get-ChildItem -Path "\\MSP02DC00P\SYSVOL\netspi.local\Policies"
            #\\\\dns_domain_name\Sysvol\dns_domain_name\Policies\\[group_policy_id]\User\Preferences\Drives\Drives.xml 
        
            Get-ChildItem -Recurse -filter "Drives.xml" -ErrorAction Ignore | 
            Select fullname | 
            ForEach-Object {
                $DriveFile=$_.FullName;
                [xml]$xmlfile=gc $Drivefile;
                [string]$FileServer = $xmlfile| Select-xml "/Drives/Drive/Properties/@path" | Select-object -expand node | ForEach-Object {$_.Value.split("\\")[2];}             
                [string]$SharePath = $xmlfile| Select-xml "/Drives/Drive/Properties/@path" | Select-object -expand node | ForEach-Object {$_.Value}             
                [string]$ShareDrive = $xmlfile| Select-xml "/Drives/Drive/@name" | Select-object -expand node | ForEach-Object {$_.Value} 
                [string]$ShareLabel = $xmlfile| Select-xml "/Drives/Drive/Properties/@label" | Select-object -expand node | ForEach-Object {$_.Value}
                        
                $TableFileServers.Rows.Add($FileServer,$SharePath,$ShareDrive,$ShareLabel,"Drives.xml") | Out-Null            
            } 

            # Remove temp drive               
            Write-Verbose "Removing temp share $DriveName to $DrivePath......"         
            cd C:
            Remove-PSDrive $DriveName         
        }
        catch
        {
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }
                
        
        # Check for file servers
        if ($TableFileServers.Rows.Count -gt 0)
        {
            $TableFileServersCount = $TableFileServers.Rows.Count 
            Write-Verbose "$TableFileServersCount domain file servers found."    
            Return $TableFileServers 
        }else{
            Write-Verbose "0 domain file servers found."
        }
    }
}


# -------------------------------------------
# Function: Get-DomainGPPasswords
# -------------------------------------------
# Note: Need to fix recursion
Function Get-DomainGPPasswords{
    Write-Verbose "Getting domain group policy passwords..."
} 

# -------------------------------------------
# Function: Get-DomainOU
# -------------------------------------------
Function Get-DomainOU{
    Write-Verbose "Getting domain OUs..."
} 


# -------------------------------------------
# Function: Get-DomainGPO
# -------------------------------------------
Function Get-DomainGPOs{
    Write-Verbose "Getting domain GPOs..."
} 


# -------------------------------------------
# Function: Get-DomainDeligatedUserRights
# -------------------------------------------
Function Get-DeligatedUserRights{
    Write-Verbose "Getting domain deligated user rights..."
} 

# -------------------------------------------
# Function: Get-DomainComputerAcls
# -------------------------------------------
Function Get-ComputerAcls{
    Write-Verbose "Getting domain computer acls..."
} 
        

# -------------------------------------------
# Function: Get-NetLogonFiles
# -------------------------------------------
Function Get-NetLogonFiles{
    Write-Verbose "Getting domain netlogon files..."
} 

# -------------------------------------------
# Function: Get-DomainAccountPolicy
# ------------------------------------------- 
# Ref: http://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx
function Get-DomainAccountPolicy
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
        Write-Verbose "Getting domain account policy..."

        # Create PS Credential object
        if($Password){
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }
    }

    Process
    {              
        # Create table for account policy
        $TableAccountPolicy = New-Object System.Data.DataTable 
        $TableAccountPolicy.Columns.Add("minlength") | Out-Null
        $TableAccountPolicy.Columns.Add("minpwdage") | Out-Null
        $TableAccountPolicy.Columns.Add("maxpwdage") | Out-Null
        $TableAccountPolicy.Columns.Add("pwdhistorylength") | Out-Null
        $TableAccountPolicy.Columns.Add("lockoutthreshhold") | Out-Null 
        $TableAccountPolicy.Columns.Add("lockoutduration") | Out-Null
        $TableAccountPolicy.Columns.Add("lockoutobservationwindow") | Out-Null
        $TableAccountPolicy.Columns.Add("pwdproperties") | Out-Null
        $TableAccountPolicy.Columns.Add("whenchanged") | Out-Null
        $TableAccountPolicy.Columns.Add("gplink") | Out-Null

        # Setup LDAP filter
        $CompFilter = "(&(objectClass=domainDNS)(fSMORoleOwner=*))" 
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $CompFilter
        $ObjSearcher.SearchScope = "Subtree"


        if ($SearchDN)
        {
            $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        # Add account policy to table
        $ObjSearcher.FindAll() | ForEach-Object {        
                                              
            $TableAccountPolicy.Rows.Add(             
            [string]$_.properties.minpwdlength,
            [string][Math]::Floor([decimal](((([string]$_.properties.minpwdage -replace '-','') / (60 * 10000000)/60))/24)),
            [string][Math]::Floor([decimal](((([string]$_.properties.maxpwdage -replace '-','') / (60 * 10000000)/60))/24)),
            [string]$_.properties.pwdhistorylength,
            [string]$_.properties.lockoutthreshold,
            [string]([string]$_.properties.lockoutduration -replace '-','') / (60 * 10000000),
            [string]([string]$_.properties.lockoutobservationwindow -replace '-','') / (60 * 10000000),                
            [string]$_.properties.pwdproperties,
            [string]$_.properties.whenchanged,
            [string]$_.properties.gplink 
            ) | Out-Null

        }

        if($TableAccountPolicy.Rows.Count -gt 0)
        {
            Write-Verbose "Successfully dumped the domain account policy."
            Return $TableAccountPolicy 
        }else{
            Write-Verbose "Unable to dump the domain account policy."
        }      
    }

    End
    {
        
    }
}

# -------------------------------------------
# Function: Dump-DomainInfo 
# -------------------------------------------
Function Dump-DomainInfo 
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
        HelpMessage="Folder to write output to.")]
        [string]$OutFolder,
        
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
    BEGIN
    {
        # ------------------------------------------------------------
        # Setup Credential Object and LDAP
        # ------------------------------------------------------------

        # Create PS Credential object
        if($Password)
        {
            Write-Verbose "Creating PsCredential object..."
            $secpass = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($Username, $secpass)                
        }

        # Create the connection to LDAP
        if ($DomainController -and $Credential.GetNetworkCredential().Password)
        {
            $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        }else{
            $objDomain = [ADSI]""  
            $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
        } 
                

        # ------------------------------------------------------------
        # Setup Output Directory
        # ------------------------------------------------------------
        if($OutFolder){            
            $OutFolderCmd = "echo test > $OutFolder\test.txt"           
        }else{
            $OutFolder = "."
            $OutFolderCmd = "echo test > $OutFolder\test.txt"             
        }

        # Create output folder
        $CheckAccess = (Invoke-Expression $OutFolderCmd) 2>&1
        if($CheckAccess -like "*denied."){
            Write-Host "Access denied to output directory."
            Break    
        }else{
            Write-Verbose "Verified write access to output directory."
            $RemoveCmd = "del $outfolder\test.txt"
            Invoke-Expression $RemoveCmd
        }  

        # ------------------------------------------------------------
        # Setup Data Tables 
        # ------------------------------------------------------------

        # Domains
        $TableDomains = New-Object System.Data.DataTable         
        $TableDomains.Columns.Add('Domain') | Out-Null

        # Domain Trusts
        $TableDomainTrusts = New-Object System.Data.DataTable         
        $TableDomainTrusts.Columns.Add('Domain') | Out-Null
        $TableDomainTrusts.Columns.Add('TrustedDomain') | Out-Null
        $TableDomainTrusts.Columns.Add('TrustType') | Out-Null

        # Domain Controllers
        $TableDomainControllers = New-Object System.Data.DataTable         
        $TableDomainControllers.Columns.Add('ComputerName') | Out-Null
        $TableDomainControllers.Columns.Add('IpAddress') | Out-Null
        $TableDomainControllers.Columns.Add('Available') | Out-Null 
        $TableDomainControllers.Columns.Add('Domain') | Out-Null
        $TableDomainControllers.Columns.Add('Role') | Out-Null                     
    }

    PROCESS
    {        

        # ------------------------------------------------------------
        # Grab Information from Active Directory
        # ------------------------------------------------------------
        # Need to update to enumerate trusts, domains, and dcs recursively


        # Grab initial domain controller
        if($DomainController){
            $TargetDC = $DomainController
        }else{
            $TargetDC  = $env:LOGONSERVER  -replace '\\',''         
        }


        # Check authentication method
        if ($password)
        {
            Write-Host "Attempting to dump information from $TargetDC as $username..." 
        }else{
            Write-Host "Attempting to dump information from $TargetDC as the current user..."
        }

        # Status the user
        Write-Host "Note: Be patient, in large domains this can take a while." -foreground gray
        Write-Host "Note: Run with -verbose switch to view details in run time." -foreground gray


        # Get domain's distinguishedName 
        Write-Verbose "Getting domain's distinguishedName..."
        $CurrentDomain = $ObjDomain.distinguishedName
        Write-Verbose "Domain's Distinguished Name: $CurrentDomain" 
            
        
        # Get domain trusts         
        $OutputPath_DomainTrusts = "$outfolder\$TargetDC"+"_Domain_Trusts.csv"
        Get-DomainTrusts -username $username -password $password -DomainController $DomainController | Export-Csv $OutputPath_DomainTrusts -NoTypeInformation


        # Get domain controllers
        $OutputPath_Domain_Contollers = "$outfolder\$TargetDC"+"_Domain_Computers_Domain_Controllers.csv"
        Get-DomainControllers -username $username -password $password -DomainController $DomainController | Export-Csv $OutputPath_Domain_Contollers -NoTypeInformation


        # Get domain controller roles
        # Get-DomainDcRoles
        # Get-DomainDcRoleNameMaster
        # Get-DomainDcRoleGlobalCatalog
        # Get-DomainDcRoleInfrastructureMaster
        # Get-DomainDcRolePDC
        # Get-DomainDcRoleRidMaster
        # Get-DomainDcRoleSchemaMaste
        
     
        # Get domain users
        $OutputPath_Domain_Users = "$outfolder\$TargetDC"+"_Domain_Users.csv"
        $TableDomainUsers = Get-DomainUsers -username $username -password $password -DomainController $DomainController 
        $TableDomainUsers | Export-Csv $OutputPath_Domain_Users -NoTypeInformation


        # Get locked accounts        
        # Get disabled accounts        
        # Get admin accounts        
        # Get no pw change required accounts 


        # Get domain group members
        $OutputPath_Domain_Users_DA = "$outfolder\$TargetDC"+"_Domain_Users_DomainAdmins.csv"
        $TableDomainAdmins = Get-DomainGroupMembers  -username $username -password $password -DomainController $DomainController -Group "Domain Admins" | Export-Csv $OutputPath_Domain_Users_DA -NoTypeInformation
        $OutputPath_Domain_Users_EA = "$outfolder\$TargetDC"+"_Domain_Users_EnterpriseAdmins.csv"  
        $TableDomainEnterprise = Get-DomainGroupMembers  -username $username -password $password -DomainController $DomainController -Group "Enterprise Admins" | Export-Csv $OutputPath_Domain_Users_EA -NoTypeInformation
        $OutputPath_Domain_Users_FA = "$outfolder\$TargetDC"+"_Domain_Users_ForestAdmins.csv"
        $TableDomainForest = Get-DomainGroupMembers  -username $username -password $password -DomainController $DomainController -Group "Forest Admins" | Export-Csv $OutputPath_Domain_Users_FA -NoTypeInformation


        # Get domain groups for a specific user
        #Get-UserGroupMemberships
        
 
        #Get-DomainSites


        #Get-DomainNetworks
        

        # Get domain computers
        $OutputPath_Domain_Computers = "$outfolder\$TargetDC"+"_Domain_Computers.csv"
        $TableDomainComputers = Get-DomainComputers -username $username -password $password -DomainController $DomainController 
        $TableDomainComputers | Export-Csv $OutputPath_Domain_Computers -NoTypeInformation


        # Get LAPS passwords 
        # Note: modify this so it can process the data table from Get-DomainComputers to avoid another query
        # Example: $TableDomainComputers | where {$_.lapspassword -gt ""} | Export-Csv $OutputPath_Domain_Computers_LAPS -NoTypeInformation
        $OutputPath_Domain_Computers_LAPS = "$outfolder\$TargetDC"+"_Domain_Passwords_LAPS.csv"
        Get-DomainPasswordsLAPS -username $username -password $password -DomainController $DomainController | Export-Csv $OutputPath_Domain_Computers_LAPS -NoTypeInformation


        # Get exploitable domain systems 
        # Note: modify this so it can process the data table from Get-DomainComputers to avoid another query
        # Example: Get-DomainExploitableSystems -importtable $TableDomainComputers
        $OutputPath_Domain_Computers_Exploitable = "$outfolder\$TargetDC"+"_Domain_Computers_Expoitable_Systems.csv"
        Get-DomainExploitableSystems -username $username -password $password -DomainController $DomainController | Export-Csv $OutputPath_Domain_Computers_Exploitable -NoTypeInformation        
           

        # Get all user and computer SPNs 
        # fix output so that it includes the full spn which includes the instance info for sql server
        # Consider grabbing the SPN from get-domaincomputer / get-domainuser and parsing them out to avoid another query.
        $OutputPath_Domain_SPNs = "$outfolder\$TargetDC"+"_Domain_SPNs.csv"
        $TableDomainSPNs = Get-DomainSpn -username $username -password $password -DomainController $DomainController 
        $TableDomainSPNs | Export-Csv $OutputPath_Domain_SPNs -NoTypeInformation        
           

        # Prase interesting SPN services in files from Get-SPN table
        $SpnList = $TableDomainSPNs | Select-Object SpnService -ExpandProperty SpnService | Sort-Object SpnService -Unique
        $SpnList | 
        ForEach-Object{
            Write-Verbose "Parsing out systems running SPN service $_ ..."
            $SpnService = $_
            $OutputPath_SpnService = "$outfolder\$TargetDC"+"_Domain_Computers_Spn_$SpnService.csv"
            $SpnServiceFiltered =  $TableDomainSPNs | Where-Object { $_.SpnService -like "*$SpnService*" -and $_.SpnServer -like "*.*" } | Select-Object SpnServer,SpnService,Spn -Unique 
            $SpnServiceFilteredCount = $SpnServiceFiltered | Measure-Object | Select-Object Count -ExpandProperty Count
            Write-Verbose "$SpnServiceFilteredCount $SpnService servers found."
            $SpnServiceFiltered | Export-Csv $OutputPath_SpnService -NoTypeInformation            
        }


        # Get DA SPNs from dcs


        # Get DA sessions from file servers and dcs


        # Get domain file servers and shares
        # Note: add the perforance fix using known paths to drives.xml
        $OutputPath_Domain_Computer_File_Servers = "$outfolder\$TargetDC"+"_Domain_Computers_File_Servers.csv"
        Get-DomainFileServers -username $username -password $password -DomainController $DomainController | Export-Csv $OutputPath_Domain_Computer_File_Servers -NoTypeInformation   
        

        # Get group policy passwords
        #Get-DomainGPPasswords
         

        # Get domain ous
        #Get-DomainOU


        # Get domain group policy objects
        #Get-DomainGPOs


        # Get deligate user rights
        #Get-DeligatedUserRights


        # Get domain computer acls
        #Get-ComputerAcls
        

        # Get list of netlogon files
        #Get-NetLogonFiles


        # Get domain account policy 
        $OutputPath_Domain_Account_Policy = "$outfolder\$TargetDC"+"_Domain_Account_Policy.csv"
        Get-DomainAccountPolicy -username $username -password $password -DomainController $DomainController | Export-Csv $OutputPath_Domain_Account_Policy -NoTypeInformation          

        Write-Host "All done."

    }

    END
    {
    }
}

