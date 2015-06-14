 function Get-DomainUserDacl
{
<#
.SYNOPSIS    

    Description: Report on permissions assigned on domain user accounts to domain users and groups.
    Author: Scott Sutherland (@_nullbind), NetSPI 2015
    Author: Khai Tran (@k_tr4n), NetSPI 2015
 
.DESCRIPTION

    Report on permissions assigned on domain user accounts to domain users and groups.  It requires
    the ActiveDirectory module included in the Remote Server Administration Tools.

.EXAMPLE

    Below is the standard command usage as a domain user.

    PS C:\> Get-DomainComputerDacl -verbose

.EXAMPLE

    Below is the standard command usage as a domain user, but it limits the results to the specific user or group
    provided.

    PS C:\> Get-DomainComputerDacl -Verbose -user demo.com\user

.EXAMPLE

    Below is the standard command usage as a domain user, but it limits the results to the specific user or group
    provided.  It also targets a specific domain controller with alternative domain credentials.  This can be 
    executed from a non domain system.

    PS C:\> Get-DomainComputerDacl -Verbose -DomainController 192.168.1.1 -Credential demo.com\user -user demo.com\user

.LINK
  https://msdn.microsoft.com/en-us/library/ms679006%28v=vs.85%29.aspx

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
        If ($Credential.UserName){
            $TargetDC = "$DomainController"
            New-PSDrive -PSProvider ActiveDirectory -Name $DriveRandom -Root "" -Server $TargetDC -credential $Credential | Out-Null
            cd $DriveName

        }else{
            New-PSDrive -PSProvider ActiveDirectory -Name $DriveRandom -Root "" | Out-Null
            cd $DriveName
        }

        # Create data table for results
        $TableDacl = New-Object System.Data.DataTable 
        $TableDacl.Columns.Add('ComputerAccount')| Out-Null
        $TableDacl.Columns.Add('ComputerName')| Out-Null
        $TableDacl.Columns.Add('Owner')| Out-Null
        $TableDacl.Columns.Add('Group')| Out-Null
        $TableDacl.Columns.Add('IdentityReference')| Out-Null
        $TableDacl.Columns.Add('ActiveDirectoryRights')| Out-Null
        $TableDacl.Columns.Add('InheritanceType')| Out-Null
        $TableDacl.Columns.Add('ObjectType')| Out-Null
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
        Get-ADUser -filter * -Properties * | select samaccountname,nTSecurityDescriptor |
        ForEach-Object{
    
            # Get current computer name
            $ComputerAccount = $_.samaccountname
            $ComputerName = $ComputerAccount.trim("$")
            Write-Verbose "Processing $ComputerName"

            # Get current access controls
            $ntsec = $_.nTSecurityDescriptor
            $nTSec_owner = $ntsec.Owner
            $nTSec_group = $ntsec.Group
            $ntsec.Access | 
        
            ForEach-Object {                                

                # Add the results to the data table
                $TableDacl.Rows.Add($ComputerAccount,
                $ComputerName,
                $nTSec_owner,
                $nTSec_group,
                $_.IdentityReference,
                $_.ActiveDirectoryRights ,
                $_.InheritanceType,
                $_.ObjectType,
                $_.InheritedObjectType,
                $_.ObjectFlags,
                $_.AccessControlType,
                $_.IsInherited,
                $_.InheritanceFlags,
                $_.PropagationFlags) | Out-Null                 
            }
        }

        # Return results
        if ($User)
        {
            $TableDacl | Where-Object {$_.IdentityReference -like "*$user*"}
        }else{
            $TableDacl | Sort-Object IdentityReference
        }
    }

    End
    {
        # Remove mounted ADS drive
        Write-Verbose "Removing temp ADS drive $DriveName..."
        cd c:
        Remove-PSDrive $DriveRandom
    }
}
