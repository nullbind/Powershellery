 function Get-DomainOuDacl
{
<#
.SYNOPSIS    

    Description: Report on permissions assigned on domain OUs to domain users and groups.
    Author: Scott Sutherland (@_nullbind), NetSPi 2015
    Author: Khai Tran (@k_tr4n), NetSPi 2015
 
.DESCRIPTION

    Report on permissions assigned on domain OUs to domain users and groups.  It requires
    the ActiveDirectory module included in the Remote Server Administration Tools.

.EXAMPLE

    Below is the standard command usage as a domain user.

    PS C:\> Get-DomainOuDacl -verbose

.EXAMPLE

    Below is the standard command usage as a domain user, but it limits the results to the specific user or group
    provided

    PS C:\> Get-DomainOuDacl -Verbose -user demo.com\user

.EXAMPLE

    Below is the standard command usage as a domain user, but it limits the results to the specific user or group
    provided.  It also targets a specific domain controller with alternative domain credentials.  This can be 
    executed from a non domain system.

    PS C:\> Get-DomainOuDacl -Verbose -DomainController 192.168.1.1 -Credential demo.com\user -user demo.com\user

.LINK
  https://msdn.microsoft.com/en-us/library/ms679006%28v=vs.85%29.aspx
  https://msdn.microsoft.com/en-us/library/system.directoryservices.extendedrightaccessrule(v=vs.110).aspx

#>
    [CmdletBinding(DefaultParametersetName="Default")]
    Param(

        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$false,
        HelpMessage="Search for Dacls for specific domain user.")]
        [string]$User
    )

    Begin
    {
        # Import required ADS module
        Import-Module ActiveDirectory

        # Create randomish name for dynamic mount point 
        $Set = "abcdefghijklmnopqrstuvwxyz".ToCharArray();
        $Result += $Set | Get-Random -Count 10
        $DriveRandom = [String]::Join("",$Result)
        $DriveName = $DriveRandom + ':'

        # Map a temp drive to the DC sysvol share
        Write-Verbose "Creating temp ADS drive $DriveName..."
        If (($Credential) -and ($DomainController)){
            $TargetDC = "$DomainController"
            New-PSDrive -PSProvider ActiveDirectory -Name $DriveRandom -Root "" -Server $TargetDC -credential $Credential | Out-Null
            cd $DriveName

        }else{
            New-PSDrive -PSProvider ActiveDirectory -Name $DriveRandom -Root "" | Out-Null
            cd $DriveName
        }

        # Create data table for inventory of object typees
        $TableTypes = New-Object System.Data.DataTable 
        $TableTypes.Columns.Add('GuidNumber')| Out-Null
        $TableTypes.Columns.Add('GuidName')| Out-Null
        $TableTypes.Clear| Out-Null

        # Get standard rights
        Write-Host "Getting standard rights"
        Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID |
        ForEach-Object {
            $TableTypes.Rows.Add([System.GUID]$_.schemaIDGUID,$_.name) | Out-Null
        }

        # Get extended rights
        Write-Host "Getting extended rights"
        Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID |
        ForEach-Object {
           $TableTypes.Rows.Add([System.GUID]$_.rightsGUID,$_.name) | Out-Null
        }

        # Create data table for results
        $TableDacl = New-Object System.Data.DataTable 
        $TableDacl.Columns.Add('OuName')| Out-Null
        $TableDacl.Columns.Add('Description')| Out-Null
        $TableDacl.Columns.Add('Owner')| Out-Null
        $TableDacl.Columns.Add('Group')| Out-Null
        $TableDacl.Columns.Add('IdentityReference')| Out-Null
        $TableDacl.Columns.Add('ActiveDirectoryRights')| Out-Null
        $TableDacl.Columns.Add('InheritanceType')| Out-Null
        $TableDacl.Columns.Add('ObjectType')| Out-Null
        $TableDacl.Columns.Add('ObjectTypeName')| Out-Null
        $TableDacl.Columns.Add('InheritedObjectType')| Out-Null
        $TableDacl.Columns.Add('ObjectFlags')| Out-Null
        $TableDacl.Columns.Add('AccessControlType')| Out-Null
        $TableDacl.Columns.Add('IsInherited')| Out-Null
        $TableDacl.Columns.Add('InheritanceFlags')| Out-Null
        $TableDacl.Columns.Add('PropagationFlags')| Out-Null
        $TableDacl.Clear| Out-Null
    }

    Process
    {
   
        # Grab DACL information for each domain computer   
        Write-Verbose "Processing OUs"
        get-ADOrganizationalUnit -filter * -Properties * |
        ForEach-Object{
    
            # Get current computer name
            $OuName = $_.ou 
            $OuDesc = $_.description       
          
            Write-Verbose "Processing $OuName"

            # Get current access controls
            $ntsec = $_.nTSecurityDescriptor
            $nTSec_owner = $ntsec.Owner
            $nTSec_group = $ntsec.Group
            $ntsec.Access | 
        
            ForEach-Object {
            
                # Get objecttype name
                $ObjectType = [string]$_.ObjectType
                $ObjectTypeGuid = "'" + "$ObjectType" + "'"
                $ObjectTypeGuidCount = $TableTypes.Select("guidnumber = $ObjectTypeGuid").Count
                if ($ObjectTypeGuidCount -gt 0){
                    [string]$ObjectTypeName = $TableTypes.Select("guidnumber=$ObjectTypeGuid") | select guidname -ExpandProperty guidname -First 1   
                }else{
                    [string]$ObjectTypeName = ""
                }                                

                # Add the results to the data table
                $TableDacl.Rows.Add(
                [string]$OuName,
                [string]$OuDesc,
                [string]$nTSec_owner,
                [string]$nTSec_group,
                [string]$_.IdentityReference,
                [string]$_.ActiveDirectoryRights ,
                [string]$_.InheritanceType,
                [string]$_.ObjectType,
                [string]$_.ObjectTypeName,
                [string]$_.InheritedObjectType,
                [string]$_.ObjectFlags,
                [string]$_.AccessControlType,
                [string]$_.IsInherited,
                [string]$_.InheritanceFlags,
                [string]$_.PropagationFlags) | Out-Null                 
            }
        }

        # Return results
        cd c:
        if ($TableDacl.Rows.Count -gt 0){
            if ($User)
            {
                if (($TableDacl | Where-Object {$_.IdentityReference -like "*$user*"}).Rows.count -gt 0){
                    $TableDacl | Where-Object {$_.IdentityReference -like "*$user*"}
                }else{
                    Write-Host "No matches found."
                }
            }else{
                $TableDacl | Sort-Object IdentityReference
            }
        }else{
            Write-Host "No matches found."
        }
    }

    End
    {
        # Remove mounted ADS drive
        Write-Verbose "Removing temp ADS drive $DriveName..."
        Remove-PSDrive $DriveRandom
    }
}
