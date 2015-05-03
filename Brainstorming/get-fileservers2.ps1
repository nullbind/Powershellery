#this is based on carlos,will,and gruber's work. todo:try/catch blocks on share, and dedupon FQDN etc.
# this worked in the first round of tests, on domain with alt creds.... Get-FileServers2 | Get-NetShare.. 
# netshare doesnt show hostname,or perms, may want to mod to level 2
#https://msdn.microsoft.com/en-us/library/windows/desktop/bb525387%28v=vs.85%29.aspx
function Get-FileServers2
{
    [CmdletBinding(DefaultParametersetName="Default")]
    Param(
        [Parameter(ParameterSetName='Modified')]
        [Parameter(ParameterSetName='Created')]
        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(ParameterSetName='Modified')]
        [Parameter(ParameterSetName='Created')]
        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(ParameterSetName='Modified')]
        [Parameter(ParameterSetName='Created')]
        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(ParameterSetName='Modified')]
        [Parameter(ParameterSetName='Created')]
        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(ParameterSetName='Modified')]
        [Parameter(ParameterSetName='Created')]
        [Parameter(ParameterSetName='Default')]
        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]
        [string]$SearchDN,

        [Parameter(ParameterSetName='Modified',
        HelpMessage="Date to search for users mofied on or after this date.")]
        [datetime]$ModifiedAfter,

        [Parameter(ParameterSetName='Modified',
        HelpMessage="Date to search for users mofied on or before this date.")]
        [datetime]$ModifiedBefore,

        [Parameter(ParameterSetName='Created',
        HelpMessage="Date to search for users created on or after this date.")]
        [datetime]$CreatedAfter,

        [Parameter(ParameterSetName='Created',
        HelpMessage="Date to search for users created on or after this date.")]
        [datetime]$CreatedBefore
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
        $TableFileServers.Columns.Add('HostName') | Out-Null


        # ----------------------------------------------------------------
        # Grab file servers from the AD homeDirectory property
        # ----------------------------------------------------------------
        
        # Status user        
        Write-Verbose "[*] Grabbing file server list from homeDirectory user attribute via LDAP..."

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
        
        ForEach-Object {                
            if ($_.properties.homedirectory){           
                $FileServer = $_.properties.homedirectory.split("\\")[2];                
                $TableFileServers.Rows.Add($FileServer) | Out-Null
            }
        }


        # ----------------------------------------------------------------
        # Grab file servers from drives.xml on DC sysvol share
        # ----------------------------------------------------------------

        # Grab DC
        if($DomainController){
            $TargetDC = $DomainController
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
            Write-Verbose "[*] Authenticating to DC for access to sysvol share..."
            
            $ShareUser = $Credential.UserName
            $SharePass = $Credential.GetNetworkCredential().Password|ConvertTo-SecureString -AsPlainText -Force
            $ShareCred = New-Object System.Management.Automation.PsCredential("$ShareUser",$SharePass)
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath -Credential $ShareCred | Out-Null
        }else{
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath | Out-Null
        }

        # Status user        
        Write-Verbose "[*] Grabbing file server list from drives.xml files on DC sysvol share..."

        # Parse out drives.xml files into the data table
        $TempDrive = $DriveName+":"
        CD $TempDrive        
        Get-ChildItem -Recurse -filter "drives.xml" -ErrorAction Ignore | 
        Select fullname | 
        ForEach-Object {
            $DriveFile=$_.FullName;
            [xml]$xmlfile=gc $Drivefile;
            $FileServer = $xmlfile| Select-xml "/Drives/Drive/Properties/@path" | Select-object -expand node | ForEach-Object {$_.Value.split("\\")[2];}             
            $TableFileServers.Rows.Add($FileServer) | Out-Null            
        } 

        # Remove temp drive        
        cd C:
        Remove-PSDrive $DriveName
        

        # ----------------------------------------------------------------
        # Display file servers
        # ----------------------------------------------------------------
        $TableFileServers | sort computername | uniq
    }
}
