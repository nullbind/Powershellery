<#

SCRIPT
Get-DomainFileServers.ps1

AUTHOR
Will Schoeder (@harmj0y)

MOD AUTHOR
Scott Sutherland (@_nullbind), NetSPI 2015

DESCRIPTION
This script will enumerate file servers from Active Directory user properties, DFS, and group policy
preferences configuration files.  It can be run as the current user or alternative credentials can 
be provided to authenticate to a domain controller that the current user/computer isn't associated with.
Below is a summary of the modifications to Will's script:
- Added support for the use of alternative credentials so users can connect to domain controllers 
  that their computer is not associated with.
- Replaced recursive directory search with list of default file locations to speed up file search.

USAGE EXAMPLES
Get-DomainFileServers 
Get-DomainFileServers -Verbose
Get-DomainFileServers -Verbose -DomainController ip -username domain\user -password 'passwordhere'

REFERENCES
Most of the code here is based on the PowerView functions written by Will Schoeder (@harmj0y).
https://github.com/PowerShellEmpire/PowerTools/tree/master/PowerView

#>


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

            # Create temp drive variables
            $TempDrive = $DriveName+":"
            cd $TempDrive  
        
            # Get a list of drives.xml files from the dc
            $TableDrivefiles = New-Object System.Data.DataTable 
            $TableDrivefiles.Columns.Add('FullName') | Out-Null
            $GpoDomain = Get-ChildItem $DrivePath | Select-Object name -First 1 -ExpandProperty name
            $GpoPath = "$DrivePath\$GpoDomain\Policies"
            Get-ChildItem $GpoPath | Select-Object fullname -ExpandProperty fullname |
            ForEach-Object {
                $DrivesBase = $_
                $DrivesPath = "$DrivesBase\User\Preferences\Drives\Drives.xml"
                if(Test-Path $DrivesPath -ErrorAction SilentlyContinue)
                {
                    $TableDrivefiles.Rows.Add($DrivesPath) | Out-Null
                }
            }
        
            # Parse identified Drives.xml files
            $TableDrivefiles | 
            ForEach-Object {
                [string]$DriveFile = $_.FullName
                [xml]$XmlFile = Get-Content $Drivefile
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
        $TableFileServersCount = $TableFileServers | Where-Object {$_.ComputerName -like "*.*"} | Select-Object ComputerName | Sort-Object ComputerName -Unique | Measure-Object | Select-Object Count -ExpandProperty Count
        if ($TableFileServersCount -gt 0)
        {
            $TableFileServersRows = $TableFileServers.Rows.Count 
            Write-Verbose "$TableFileServersCount domain file servers and $TableFileServersRows shares found."    
            Return $TableFileServers 
        }else{
            Write-Verbose "0 domain file servers found."
        }
    }
}

