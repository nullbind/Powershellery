# -------------------------------------------
# Function: Get-DomainObjectAcl
# -------------------------------------------
# Ref: http://www.experts-exchange.com/Programming/Languages/Scripting/clearPowershell/Q_24625381.html
# add filter for objecttype (ou/user/group/computer)
function Get-DomainObjectAcls
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
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]
        [string]$SearchDN,

        [Parameter(Mandatory=$false,
        HelpMessage="User to filter by.")]
        [string]$User = "*"
    )
    Begin
    {

        Write-Verbose "Getting domain object dacls..."

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
            # Setup table fof object dacls
            $TableDomainObjects = New-Object System.Data.DataTable
            $TableDomainObjects.Columns.Add("Name") | Out-Null
            $TableDomainObjects.Columns.Add("distinguishedName") | Out-Null
            $TableDomainObjects.Columns.Add("SecurityPrincipal") | Out-Null
            $TableDomainObjects.Columns.Add("AccessType") | Out-Null
            $TableDomainObjects.Columns.Add("Permissions") | Out-Null
            $TableDomainObjects.Columns.Add("AppliesTo") | Out-Null
            $TableDomainObjects.Columns.Add("AppliesToObjectType") | Out-Null
            #$TableDomainObjects.Columns.Add("AppliesToProperty") | Out-Null
            $TableDomainObjects.Clear()

            # Setup the LDAP filter
            $CompFilter = "(&(objectCategory=person)(objectClass=user))"            
            #$CompFilter = "((objectClass=group))"
            $ObjSearcher.PageSize = $Limit
            $ObjSearcher.Filter = $CompFilter
            $ObjSearcher.SearchScope = "Subtree"

            if ($SearchDN)
            {
                $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
            }

            # Find DACL information
            $ObjSearcher.FindAll() | 
            ForEach-Object {
                
                # Retrieve all Access Control Entries from the AD Object
                $Object = $_.GetDirectoryEntry()                    
                $ObjectAcl = $Object.PsBase.ObjectSecurity.GetAccessRules($True,$False,[Security.Principal.NTAccount])

                # Filter down to explicit Access Control Entries and domain security principals
                $ObjectAcl = $ObjectAcl | Where-Object { 
                    $_.IsInherited -eq $False -And 
                    $_.IdentityReference -Like "*\*" -And 
                    $_.IdentityReference -NotMatch "NT AUTHORITY*|BUILTIN*" 
                }     
                
                # get acls
                $ObjectAcl |  
                ForEach-Object{                   

                    # Change the values for InheritanceType to friendly names
                    $AppliesTo = switch ($_.InheritanceType) 
                    {
                      "None"            { "This object only" }
                      "Descendents"     { "All child objects" }
                      "SelfAndChildren" { "This object and one level Of child objects" }
                      "Children"        { "One level of child objects" }
                      "All"             { "This object and all child objects"} 
                    }                    

                    # Search for the Object Type in the Schema
                    if([string]$_.InheritedObjectType -NotMatch "0{8}.*") 
                    {
                        [string]$InheritedObjectTypeStuff = [string]$_.InheritedObjectType                    
                        $LdapFilter = "(SchemaIDGUID=\$InheritedObjectTypeStuff | `
                        %{ '{0:X2}' -f $_ })"
                        $Result = (New-Object DirectoryServices.DirectorySearcher($Schema, $LdapFilter)).FindOne()
                        $AppliesToObjectType = $Result.Properties.ldapdisplayname
                    }else{ 
                        $AppliesToObjectType = "All" 
                    }
                    
                    <#
                    # Figure out what rights this applies to 
                    if ([string]$_.ObjectType -NotMatch "0{8}.*") 
                    {
                        # Search for a possible Extended-Right or Property Set
                        $LdapFilter = "(rightsGuid=[string]$_.ObjectType)"
                        $Result = (New-Object DirectoryServices.DirectorySearcher($ExtendedRights, $LdapFilter)).FindOne()
                        If ($Result) 
                        {
                            $AppliesToProperty = $Result.Properties["displayname"]
                        }else{   
                                     
                            # Search for the attribute name in the Schema
                            $LdapFilter = "(SchemaIDGUID=\$($_.ObjectType.ToByteArray() |
                            ForEach-Object{ 
                                '{0:X2}' -f $_ 
                            }))"
                            $Result = (New-Object DirectoryServices.DirectorySearcher($Schema, $LdapFilter)).FindOne()
                            $AppliesToProperty =  $Result.Properties["ldapdisplayname"]
                        }
                    }else{ 
                        $AppliesToProperty = "All" 
                    }   
                    #>

                    #Add object dacl information to table                               
                    $TableDomainObjects.Rows.Add( 
                        [string]$Object.Get("name"),
                        [string]$Object.Get("distinguishedName"),  
                        [string]$_.IdentityReference,
                        [string]$_.AccessControlType,
                        [string]$_.ActiveDirectoryRights,
                        [string]$AppliesTo,
                        [string]$AppliesToObjectType
                    ) | Out-Null                                                              
                }           
            }       
                                            
            # Check for deligated rights
            if($TableDomainObjects.Rows.Count -gt 0)
            {
                $TableDomainObjectsCount = $TableDomainObjects.Rows.Count
                Write-Verbose "$TableDomainObjectsCount deligated rights were found."
                Return $TableDomainObjects
            }else{
                Write-Verbose "0 deligated rights were found."
            }        
        }catch{
          "Error was $_"
          $line = $_.InvocationInfo.ScriptLineNumber
          "Error was in Line $line"
        }                
    }

    End
    {

    }
}
