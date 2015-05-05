function Get-FileServers
{
    <#
        .Synopsis
           This module will enumerate file servers from Active Directory.  It can be run as the current
           user or alternative credentials can be provided to authenticate to a domain controller that the
           current user/computer isn't associated with.
        .DESCRIPTION
           This module will enumerate file servers from Active Directory.  It enumerates file servers from
           Active Directory by querying the "homeDirectory" and "ScriptPath" user properties in Active Directory.  
           It also parses file servers from the "drives.xml" files found on the domain controller's "sysvol" 
           share.  It can be run as the current user or alternative credentials can be provided to authenticate to 
           a domain controller that the current user/computer isn't associated with.  Finally, the script can also 
           be used to list the shares found on the file servers.
        .EXAMPLE
           The example below shows the standard command usage with the current user.     
           PS C:\> Get-FileServers
           ComputerName
           ------------
           homedirs
           homedirs.demo.com
           fileserver1
           fileserver1.demo.com
           fileserver2
           fileserver2.demo.com
        .EXAMPLE
           The example below shows the standard command usage with the current user and output to a
           CSV file.     
           PS C:\> Get-FileServers | Export-Csv c:\temp\fileservers.csv -NoTypeInformation
        .EXAMPLE
           The example below shows the standard command usage with alternative domain credentials and verbose
           output.     
           PS C:\> Get-FileServers -DomainController 192.168.1.1 -Credential demo.com\user -verbose
           VERBOSE: [*] Grabbing file server list from homeDirectory user attribute via LDAP...
           VERBOSE: [*] Grabbing file server list from drives.xml files on DC sysvol share...
           ComputerName
           ------------
           homedirs
           homedirs.demo.com
           fileserver1
           fileserver1.demo.com
           fileserver2
           fileserver2.demo.com
        .EXAMPLE
           The example below shows the command usage to list shares found on servers using with 
           alternative domain credentials.     
           PS C:\> Get-FileServers -DomainController 192.168.1.1 -Credential demo.com\user -ShowShares
            ComputerName                                                 SharePath                                       ShareDrive                                      ShareLabel                                                   
            ------------                                                 ---------                                       ----------                                      ----------                                                   
            homedirs                                                     \\homedirs\HomeDirs$\user1                      U:
            homedirs                                                     \\homedirs\HomeDirs$\user2                      U:
            fileserver1                                                  \\fileserver1\Public                            P:                                              Public Folder
            fileserver2                                                  \\fileserver2\ITShare                           I:                                              IT documents
            homedirs.demo.com                                            \\homedirs.demo.com\HomeDirs$\user1             U:
            homedirs.demo.com                                            \\homedirs.demo.com\HomeDirs$\user2             U:
            fileserver1.demo.com                                         \\fileserver1.demo.com\Public                   P:                                              Public Folder
            fileserver2.demo.com                                         \\fileserver2.demo.com\ITShare                  I:                                              IT documents
         .LINK
           http://www.netspi.com
           https://msdn.microsoft.com/en-us/library/windows/desktop/bb525387%28v=vs.85%29.aspx
           https://github.com/nullbind/Powershellery/blob/master/Stable-ish/ADS/Get-ExploitableSystems.psm1
           
         .NOTES
           Author: Scott Sutherland - 2015, NetSPI
           Version: Get-FileServers.psm1 v1.0
           Comments: The technique used to query LDAP was based on the "Get-AuditDSComputerAccount" 
           function found in Carols Perez's PoshSec-Mod project.  The general idea is based off of  
           Will Schroeder's "Get-NetFileServers" function from the PowerView toolkit.
           Todo: Add try/catch on file share access,remove dups caused by FQDN.
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
        HelpMessage="Show shares that are associated with the file servers.")]
        [switch]$ShowShares
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
        # ----------------------------------------------------------------
        # Setup data table to store file servers
        # ----------------------------------------------------------------
        $TableFileServers = New-Object System.Data.DataTable 
        $TableFileServers.Columns.Add('ComputerName') | Out-Null
        $TableFileServers.Columns.Add('SharePath') | Out-Null
        $TableFileServers.Columns.Add('ShareDrive') | Out-Null
        $TableFileServers.Columns.Add('ShareLabel') | Out-Null


        # ----------------------------------------------------------------
        # Grab file servers from the AD homeDirectory property
        # ----------------------------------------------------------------
        
        # Status user        
        Write-Verbose "[*] Grabbing file servers from homeDirectory & ScriptPath user properties via LDAP..."

        $SAMAccountFilter = "(sAMAccountType=805306368)"
        
        # Search parameters
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = "(&(objectCategory=Person))"
        $ObjSearcher.SearchScope = $SearchScope

        if ($SearchDN)
        {
            $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }
        
        $ObjSearcher.FindAll() | 

        # Add fileservers from homedirectory property
        ForEach-Object {                
            if ($_.properties.homedirectory){           
                [string]$HomeFileServer = $_.properties.homedirectory.split("\\")[2];
                [string]$HomeSharePath =  $_.properties.homedirectory
                [string]$HomeDrive = $_.properties.homedrive
                
                if ($HomeDrive) {
                    $HomeShareDrive = $HomeDrive
                }else{
                    $HomeShareDrive = ""
                }
                              
                $TableFileServers.Rows.Add($HomeFileServer,$HomeSharePath,$HomeShareDrive) | Out-Null
            }
        }
 
        # Add fileservers from scriptpath property
        ForEach-Object {                
            if ($_.properties.scriptpath){           
                [string]$ScriptFileServer = $_.properties.scriptpath.split("\\")[2];
                [string]$ScriptSharePath =  $_.properties.scriptpath
              
                $TableFileServers.Rows.Add($ScriptFileServer,$ScriptSharePath) | Out-Null
            }
        }


        # ----------------------------------------------------------------
        # Grab file servers from drives.xml on DC sysvol share
        # ----------------------------------------------------------------

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

        # Map a temp drive to the DC
        If ($Credential.UserName){

            # Status user        
            Write-Verbose "[*] Creating temp share $DriveName to $DrivePath..." 
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath -Credential $Credential | Out-Null

        }else{
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath | Out-Null
        }

        # Status user        
        Write-Verbose "[*] Grabbing and parsing drives.xml files from $DrivePath..."

        # Parse out drives.xml files into the data table
        $TempDrive = $DriveName+":"
        CD $TempDrive        
        Get-ChildItem -Recurse -filter "drives.xml" -ErrorAction Ignore | 
        Select fullname | 
        ForEach-Object {
            $DriveFile=$_.FullName;
            [xml]$xmlfile=gc $Drivefile;
            [string]$FileServer = $xmlfile| Select-xml "/Drives/Drive/Properties/@path" | Select-object -expand node | ForEach-Object {$_.Value.split("\\")[2];}             
            [string]$SharePath = $xmlfile| Select-xml "/Drives/Drive/Properties/@path" | Select-object -expand node | ForEach-Object {$_.Value}             
            [string]$ShareDrive = $xmlfile| Select-xml "/Drives/Drive/@name" | Select-object -expand node | ForEach-Object {$_.Value} 
            [string]$ShareLabel = $xmlfile| Select-xml "/Drives/Drive/Properties/@label" | Select-object -expand node | ForEach-Object {$_.Value}
                        
            $TableFileServers.Rows.Add($FileServer,$SharePath,$ShareDrive,$ShareLabel) | Out-Null            
        } 

        # Remove temp drive
        # Status user        
        Write-Verbose "[*] Removing temp share $DriveName..."         
        cd C:
        Remove-PSDrive $DriveName


        # ----------------------------------------------------------------
        # Display file servers
        # ----------------------------------------------------------------
        if($ShowShares){
            $TableFileServers 
        }else{
            $TableFileServers | Select-Object ComputerName | Sort-Object ComputerName | Get-Unique -asstring
        }
    }
}
