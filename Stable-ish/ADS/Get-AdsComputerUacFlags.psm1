<#
	.Synopsis
	   This module will query Active Directory for the computer accounts and parse out the flags
	   in each of their User Account Control property.

	.DESCRIPTION
	   This module will query Active Directory for the computer accounts and parse out the flags
	   in each of their User Account Control property.

	.EXAMPLE
	   The example below uses integrated authentication to show all User Account Control flags.      

	   PS C:\>Get-AdsComputerUacFlags

	.EXAMPLE
	   The example below uses alternative domain credentials to authenticate to a remote domain controller
 	   and show all User Account Control flags.      

	   PS C:\>Get-AdsComputerUacFlags -DomainController 192.168.1.1 -Credential demo\user

	.EXAMPLE
	   The example below uses integrated authentication to select disabled computers.      

	   PS C:\>Get-AdsComputerUacFlags | where { $_.SERVER_TRUST_ACCOUNT -eq 1} | select ComputerName

	.EXAMPLE
	   The example below uses integrated authentication to select domain controllers.      

	   PS C:\>Get-AdsComputerUacFlags | where { $_.SERVER_TRUST_ACCOUNT -eq 1} | select ComputerName

	 .LINK
	   http://www.netspi.com
	   http://blogs.technet.com/b/askpfeplat/archive/2014/01/15/understanding-the-useraccountcontrol-attribute-in-active-directory.aspx
	   https://msdn.microsoft.com/en-us/library/ms680987%28v=vs.85%29.aspx#windows_server_2003
	   http://support.microsoft.com/en-us/kb/305144
	   
	 .NOTES
	   Author: Scott Sutherland - 2015, NetSPI
	   Version: Get-AdsComputerUacFlags.psm1 v1.0
	   Comments: The technique used to query LDAP was based on the "Get-AuditDSComputerAccount" 
	   function found in Carols Perez's PoshSec-Mod project.  The general idea is based off of  
	   Will Schroeder's "Invoke-FindVulnSystems" function from the PowerView toolkit.
#>
function Get-AdsComputerUacFlags
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory = $false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory = $false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000.")]
        [int]$Limit = 1000,

        [Parameter(Mandatory = $false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory = $false,
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

        # Status user
        Write-Host "[*] Grabbing computer account information from Active Directory..."


        # ----------------------------------------------------------------
        # Setup data table for domain computer information
        # ----------------------------------------------------------------
    
        # Create data table for hostnames, os, and service packs from LDAP
        $TableAdsComputers = New-Object System.Data.DataTable 
        $TableAdsComputers.Columns.Add('ComputerName') | Out-Null
        $TableAdsComputers.Columns.Add('SCRIPT') | Out-Null
        $TableAdsComputers.Columns.Add('ACCOUNTDISABLE') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_3') | Out-Null
        $TableAdsComputers.Columns.Add('HOMEDIR_REQUIRED') | Out-Null
        $TableAdsComputers.Columns.Add('LOCKOUT') | Out-Null
        $TableAdsComputers.Columns.Add('PASSWD_NOTREQD') | Out-Null
        $TableAdsComputers.Columns.Add('PASSWD_CANT_CHANGE') | Out-Null
        $TableAdsComputers.Columns.Add('ENCRYPTED_TEXT_PWD_ALLOWED') | Out-Null
        $TableAdsComputers.Columns.Add('TEMP_DUPLICATE_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('NORMAL_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_11') | Out-Null
        $TableAdsComputers.Columns.Add('INTERDOMAIN_TRUST_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('WORKSTATION_TRUST_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('SERVER_TRUST_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_15') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_16') | Out-Null
        $TableAdsComputers.Columns.Add('DONT_EXPIRE_PASSWORD') | Out-Null
        $TableAdsComputers.Columns.Add('MNS_LOGON_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('SMARTCARD_REQUIRED') | Out-Null
        $TableAdsComputers.Columns.Add('TRUSTED_FOR_DELEGATION') | Out-Null
        $TableAdsComputers.Columns.Add('NOT_DELEGATED') | Out-Null
        $TableAdsComputers.Columns.Add('USE_DES_KEY_ONLY') | Out-Null
        $TableAdsComputers.Columns.Add('DONT_REQ_PREAUTH') | Out-Null
        $TableAdsComputers.Columns.Add('PASSWORD_EXPIRED') | Out-Null
        $TableAdsComputers.Columns.Add('TRUSTED_TO_AUTH_FOR_DELEGATION') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_26') | Out-Null
        $TableAdsComputers.Columns.Add('PARTIAL_SECRETS_ACCOUNT') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_28') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_29') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_30') | Out-Null
        $TableAdsComputers.Columns.Add('UNKNOWN_OFFSET_31') | Out-Null

        # ----------------------------------------------------------------
        # Grab computer account information from Active Directory via LDAP
        # ----------------------------------------------------------------

        $CompFilter = "(&(objectCategory=Computer))"
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = $CompFilter
        $ObjSearcher.SearchScope = "Subtree"

        if ($SearchDN)
        {
            $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        $ObjSearcher.FindAll() | ForEach-Object {

            # Sources for parsing the useraccountcontrol property
            # http://support.microsoft.com/en-us/kb/305144
            # http://blogs.technet.com/b/askpfeplat/archive/2014/01/15/understanding-the-useraccountcontrol-attribute-in-active-directory.aspx

            # Setup fields
            $CurrentHost = $($_.properties['dnshostname'])
            $CurrentUac = $($_.properties['useraccountcontrol'])               

            # Convert useraccountcontrol dec number to binary so flags can be checked
            $CurrentUacBin = [convert]::ToString($CurrentUac,2)
            #$CurrentUacBinLen = $CurrentUacBin | Measure-Object -Character | select characters -ExpandProperty characters
            $CurrentUacBinPadNum = 31 - ($CurrentUacBin | Measure-Object -Character | select characters -ExpandProperty characters) 
            $CurrentUacBinPadding = "0" * $CurrentUacBinPadNum
            $CurrentUacBinFull = "$CurrentUacBinPadding$CurrentUacBin"
            
			# Parse out the UAC flags
            $UAC_SCRIPT = $CurrentUacBinFull.Substring(1,1)
            $UAC_ACCOUNTDISABLE = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 2),1)
            $UAC_UNKNOWN_OFFSET_3 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 3),1)
            $UAC_HOMEDIR_REQUIRED = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 4),1)
            $UAC_LOCKOUT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 5),1)
            $UAC_PASSWD_NOTREQD = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 6),1)
            $UAC_PASSWD_CANT_CHANGE = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 7),1)
            $UAC_ENCRYPTED_TEXT_PWD_ALLOWED = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 8),1)
            $UAC_TEMP_DUPLICATE_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 9),1)
            $UAC_NORMAL_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 10),1)
            $UAC_UNKNOWN_OFFSET_11 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 11),1)
            $UAC_INTERDOMAIN_TRUST_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 12),1)
            $UAC_WORKSTATION_TRUST_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 13),1)
            $UAC_SERVER_TRUST_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 14),1)           
            $UAC_UNKNOWN_OFFSET_15 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 15),1)            
            $UAC_UNKNOWN_OFFSET_16 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 16),1)
            $UAC_DONT_EXPIRE_PASSWORD = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 17),1)
            $UAC_MNS_LOGON_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 18),1); 
            $UAC_SMARTCARD_REQUIRED = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 19),1)
            $UAC_TRUSTED_FOR_DELEGATION = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 20),1)
            $UAC_NOT_DELEGATED = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 21),1)
            $UAC_USE_DES_KEY_ONLY = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 22),1)
            $UAC_DONT_REQ_PREAUTH = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 23),1)
            $UAC_PASSWORD_EXPIRED = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 24),1)
            $UAC_TRUSTED_TO_AUTH_FOR_DELEGATION = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 25),1)
            $UAC_UNKNOWN_OFFSET_26 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 26),1)
            $UAC_PARTIAL_SECRETS_ACCOUNT = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 27),1)
            $UAC_UNKNOWN_OFFSET_28 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 28),1)
            $UAC_UNKNOWN_OFFSET_29 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 29),1)
            $UAC_UNKNOWN_OFFSET_30 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 30),1)
            $UAC_UNKNOWN_OFFSET_31 = $CurrentUacBinFull.Substring(($CurrentUacBinFull.Length - 31),1)

            # Add results to the data table
            $TableAdsComputers.Rows.Add($CurrentHost,$UAC_SCRIPT,$UAC_ACCOUNTDISABLE,$UAC_UNKNOWN_OFFSET_3,$UAC_HOMEDIR_REQUIRED,$UAC_LOCKOUT,$UAC_PASSWD_NOTREQD,$UAC_PASSWD_CANT_CHANGE,$UAC_ENCRYPTED_TEXT_PWD_ALLOWED,$UAC_TEMP_DUPLICATE_ACCOUNT,$UAC_NORMAL_ACCOUNT,$UAC_UNKNOWN_OFFSET_11,$UAC_INTERDOMAIN_TRUST_ACCOUNT,$UAC_WORKSTATION_TRUST_ACCOUNT,$UAC_SERVER_TRUST_ACCOUNT,$UAC_UNKNOWN_OFFSET_15,$UAC_UNKNOWN_OFFSET_16,$UAC_DONT_EXPIRE_PASSWORD,$UAC_MNS_LOGON_ACCOUNT,$UAC_SMARTCARD_REQUIRED,$UAC_TRUSTED_FOR_DELEGATION,$UAC_NOT_DELEGATED,$UAC_USE_DES_KEY_ONLY,$UAC_DONT_REQ_PREAUTH,$UAC_PASSWORD_EXPIRED,$UAC_TRUSTED_TO_AUTH_FOR_DELEGATION,$UAC_UNKNOWN_OFFSET_26,$UAC_PARTIAL_SECRETS_ACCOUNT,$UAC_UNKNOWN_OFFSET_28,$UAC_UNKNOWN_OFFSET_29,$UAC_UNKNOWN_OFFSET_30,$UAC_UNKNOWN_OFFSET_31) | Out-Null             
 
         }  
         
         # Display UAC results for each computer        
         $TableAdsComputers
    }

    End
    {

    }
}
