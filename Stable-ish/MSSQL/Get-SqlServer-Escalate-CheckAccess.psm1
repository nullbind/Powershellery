function Get-SqlServer-Escalate-CheckAccess
{	
	<#
	.SYNOPSIS
	   This script obtains a list of all of the SQL Server instances registered on
	   the domain by querying a domain controller for MSSQLsvc Service Principle
	   Names.  Then it checks if the current or provided user has access to the SQL
	   Server instances found. Finally, it queries accessible SQL Server instances 
	   for basic information that could be used to escalate privileges on the server 
	   such as sysadmin privileges, shared service accounts, service 
	   accounts configured with Domain Admin privileges, and database links. 

	.DESCRIPTION
	   This module obtains a list of all of the SQL Server instances registered on
	   the domain by querying a domain controller for MSSQLsvc Service Principle
	   Names.  Then it checks if the current or provided user has access to the SQL
	   Server instances found. Finally, it queries accessible SQL Server instances 
	   for basic information that could be used to escalate privileges on the server 
	   such as sysadmin privileges, shared service accounts, service 
	   accounts configured with Domain Admin privileges, and database links.  
	   An option has also been added so a custom query can be defined by the user.
	   The module allows users authenticate to the SQL Server instances as the 
	   current domain user or a provided SQL user.  Alternative domain credentials 
	   can also be used via the Windows RunAs command.

	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
	   access to.  This is the default output.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] Attempting to login into 5 SQL Server instances as mydomain\myuser...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
	   [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
	   [*] ----------------------------------------------------------------------
	   [*] 3 of 5 SQL Server instances could be accessed.        
	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------

    .EXAMPLE
	   Returns a list of SQL Server instances imported from a file and on the current 
	   user's domain that they have access to.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -File c:\Temp\Servers.txt
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 2 SQL Server instances found in LDAP.
	   [*] 3 SQL Server instances found in c:\Temp\Servers.txt.
	   [*] Attempting to login into 5 SQL Server instances as mydomain\myuser...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
	   [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
	   [*] ----------------------------------------------------------------------
	   [*] 3 of 5 SQL Server instances could be accessed.        
	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------

	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain and 
	   attempts to authenticate to them using provided SQL Server credentials.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -SQLUser test -SQLPass $up3r$3cur3P@$$w0rd
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] Attempting to login into 5 SQL Server instances as test...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] Failed   - server3.mydomain.com,1433 (192.168.1.103) - is up, but authentication/query failed
	   [+] Failed   - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - is up, but authentication/query failed
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
	   [*] ----------------------------------------------------------------------
	   [*] 1 of 5 SQL Server instances could be accessed.        
	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------

	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
	   access to.  This also displays a data table object at the end that can feed the 
	   pipeline.  You can make it pretty using the format-table syntax example below.
	   
	   PS C:Get-SqlServer-Escalate-CheckAccess -ShowSum | format-table -AutoSize 
 	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
 	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] Attempting to login into 5 SQL Server instances as mydomain\myuser...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
	   [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
	   [*] ----------------------------------------------------------------------
 	   [*] 3 of 5 SQL Server instances could be accessed.        
 	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------

	   IpAddress      Server                      Instance                                   SQLVer                 OsVer      Sysadmin SvcAcct                     SvcIsDA IsClustered DBLinks
	   ---------      ------                      --------                                   ------                 -----      -------- -------                     ------- ----------- -------           
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com,1433                  2008 Express Edition   7/2008     No       NT AUTHORITY\NETWORKSERVICE No      No          4      
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com\SQLEXPRESS            2008 Express Edition   7/2008     No       NT AUTHORITY\LocalSystem    No      No          1      
	   192.168.1.104  server4.mydomain.com        server4.mydomain.com\AppData               2005 Standard Edition  2003       Yes      NT AUTHORITY\sql_svc        Yes     No          0   

	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
	   access to.  This will display the default output, but also write the results to a 
	   CSV file.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -ShowSum | export-csv c:\temp\mysqlaccess.csv
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] Attempting to login into 5 SQL Server instances as mydomain\myuser...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
	   [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
	   [*] ----------------------------------------------------------------------
	   [*] 3 of 5 SQL Server instances could be accessed.        
	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------
        
	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
	   access to.  This will display the default output, but also display a data table of
	   SQL Servers that are accessible every time a successful connection is made.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -ShowStatus 
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] Attempting to login into 5 SQL Server instances as mydomain\myuser...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 

	   IpAddress      Server                      Instance                                   SQLVer                 OsVer      Sysadmin SvcAcct                     SvcIsDA IsClustered DBLinks
	   ---------      ------                      --------                                   ------                 -----      -------- -------                     ------- ----------- -------           
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com,1433                  2008 Express Edition   7/2008     No       NT AUTHORITY\NETWORKSERVICE No      No          4                
        
	   [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No

	   IpAddress      Server                      Instance                                   SQLVer                 OsVer      Sysadmin SvcAcct                     SvcIsDA IsClustered DBLinks
	   ---------      ------                      --------                                   ------                 -----      -------- -------                     ------- ----------- -------           
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com,1433                  2008 Express Edition   7/2008     No       NT AUTHORITY\NETWORKSERVICE No      No          4      
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com\SQLEXPRESS            2008 Express Edition   7/2008     No       NT AUTHORITY\LocalSystem    No      No          1                                 
          
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes       
        
	   IpAddress      Server                      Instance                                   SQLVer                 OsVer      Sysadmin SvcAcct                     SvcIsDA IsClustered DBLinks
	   ---------      ------                      --------                                   ------                 -----      -------- -------                     ------- ----------- -------           
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com,1433                  2008 Express Edition   7/2008     No       NT AUTHORITY\NETWORKSERVICE No      No          4      
	   192.168.1.103  server3.mydomain.com        server3.mydomain.com\SQLEXPRESS            2008 Express Edition   7/2008     No       NT AUTHORITY\LocalSystem    No      No          1      
	   192.168.1.104  server4.mydomain.com        server4.mydomain.com\AppData               2005 Standard Edition  2003       Yes      NT AUTHORITY\sql_svc        Yes     No          0                              
             
	   [*] ----------------------------------------------------------------------
	   [*] 3 of 5 SQL Server instances could be accessed.        
	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------    
        
	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
	   access to.  This will display the default output, but also display the results of
	   a custom query defined by the user.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -query "select name as 'Databases' from master..sysdatabases where HAS_DBACCESS(name) = 1"
 	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] Attempting to login into 5 SQL Server instances as mydomain\myuser...
	   [*] ----------------------------------------------------------------------
	   [-] Failed   - server1.mydomain.com is not responding to pings
	   [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
	   [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
	   [+] Query sent: select name as 'Databases' from master..sysdatabases where HAS_DBACCESS(name) = 1
	   [+] Query output:
       
	   Databases
	   ---------                                                          
	   master
	   tempdb
	   msdb      
          
	   [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
	   [+] Query sent: select name as 'Databases' from master..sysdatabases where HAS_DBACCESS(name) = 1
	   [+] Query output:
                                                                 
	   Databases
	   ---------                                                          
	   master
	   tempdb
	   msdb                                 
          
	   [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes       
	   [+] Query sent: select name as 'Databases' from master..sysdatabases where HAS_DBACCESS(name) = 1
	   [+] Query output:
                                                                 
	   Databases
	   ---------                                                          
	   master
	   tempdb
	   msdb
	   PCIDataDB
	   ApplicationDB
	   CompanySecrects                      
             
	   [*] ----------------------------------------------------------------------
	   [*] 3 of 5 SQL Server instances could be accessed.        
	   [*] End Time: 04/03/2014 10:58:00      
	   [*] Total Time: 00:03:00
	   [*] ----------------------------------------------------------------------  

	.EXAMPLE
	   Only return a list of SQL Servers found in Active Directory.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -listonly 
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] listing SQL Server instances...
	   Server                                  Instance
	   ------                                  --------
	   server1.mydomain.com                    server1.mydomain.com,1433
	   server2.mydomain.com                    server2.mydomain.com,1433
	   server3.mydomain.com                    server3.mydomain.com,1433
	   server3.mydomain.com                    server3.mydomain.com\SQLEXPRESS
	   server4.mydomain.com                    server4.mydomain.com\AppData

	.EXAMPLE
	   Only return a list of SQL Servers found in Active Directory and write them to a csv file.
	   
	   PS C:\Get-SqlServer-Escalate-CheckAccess -listonly | export-csv c:\temp\SQLServers.csv
	   [*] ----------------------------------------------------------------------
	   [*] Start Time: 04/09/2014 17:02:33
	   [*] Domain: mydomain.com
	   [*] DC: dc1.mydomain.com
	   [*] Getting list of SQL Server instances from DC as mydomain\myuser...
	   [*] 5 SQL Server instances found in LDAP.
	   [*] listing SQL Server instances...
	   PS C:\

	 .LINK
	   http://www.netspi.com
	   http://support.microsoft.com/?kbid=304721 to figure out workstation vs server
	   http://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx
	   
	 .NOTES
	   Author: Scott Sutherland - 2014, NetSPI
	   Version: Get-SqlServer-Escalate-CheckAccess.psm1 v1.0
	   Comments: Should work on SQL Server 2005 and Above.   Requires PowerShell v3.
	
	#>
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$false,
    HelpMessage='Credentials to use when connecting to a Domain Controller.')]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Domain controller for Domain and Site that you want to query against.')]
    [string]$DomainController,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Maximum number of Objects to pull from AD, limit is 1,000 .')]
    [int]$Limit = 1000,
    
    [Parameter(Mandatory=$false,
    HelpMessage='scope of a search as either a base, one-level, or subtree search, default is subtree.')]
    [ValidateSet('Subtree','OneLevel','Base')]
    [string]$SearchScope = 'Subtree',
    
    [Parameter(Mandatory=$false,
    HelpMessage='Distinguished Name Path to limit search to.')]
    [string]$SearchDN,
	
	[Parameter(Mandatory=$false,
    HelpMessage='Only display a list of SQL Servers found in Active Directory.')]
    [switch]$ListOnly,
    
    [Parameter(Mandatory=$false,
    HelpMessage='At the end of the scan display the results in a pipeable datatable format.')]
    [switch]$ShowSum,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Display a status table after accessing each SQL Server instance successfully.')]
    [switch]$ShowStatus,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login username.')]
    [string]$SQLUser,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login password.')]
    [string]$SQLPass,
    
    [Parameter(Mandatory=$false,
    HelpMessage='File containing list of SQL servers. Accepts formats: 192.168.1.100 192.168.1.100,1433 192.168.1.100\CVM')]
    [string]$File,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Allows users to run a custom query on all accessible SQL Server instances.')]
    [string]$Query
  )
  
  Begin
  {        
    # Setup domain user and domain controller (if provided)
    if ($DomainController -and $Credential.GetNetworkCredential().Password)
    {
      $ObjDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
      $ObjSearcher = New-Object System.DirectoryServices.DirectorySearcher $ObjDomain
    }
    else
    {
      $ObjDomain = [ADSI]""  
      $ObjSearcher = New-Object System.DirectoryServices.DirectorySearcher $ObjDomain
    }
  }
  
  Process
  {	
    
    # Setup the user that will be used to connect to the SQL Servers found
    if($SQLUser -and $SQLPass){
      $DBUser = $SQLUser
    }else{
      $DBUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    
    # ----------------------------------------------------------------
    # Setup data tables
    # ----------------------------------------------------------------
    
    # Create data table to house list of Domain Admins
    $TableDomainAdmins = New-Object System.Data.DataTable 
    $TableDomainAdmins.Columns.Add('Account') | Out-Null
    
    # Create data table to house list of SQL Server found in LDAP
    $TableLDAP = New-Object System.Data.DataTable 
    $TableLDAP.Columns.Add('Server') | Out-Null 
    $TableLDAP.Columns.Add('Instance') | Out-Null  
    
    # Create data table to house sql server query data
    $TableSQL = New-Object System.Data.DataTable      
    $TableSQL.Columns.Add('IpAddress') | Out-Null
    $TableSQL.Columns.Add('Server') | Out-Null
    $TableSQL.Columns.Add('Instance') | Out-Null
    $TableSQL.Columns.Add('SQLVer') | Out-Null  
    $TableSQL.Columns.Add('OsVer') | Out-Null 
    $TableSQL.Columns.Add('Sysadmin') | Out-Null 
    $TableSQL.Columns.Add('SvcAcct') | Out-Null 
    $TableSQL.Columns.Add('SvcIsDA') | Out-Null
    $TableSQL.Columns.Add('IsClustered') | Out-Null
    $TableSQL.Columns.Add('DBLinks') | Out-Null   
    
    # ----------------------------------------------------------------
    # Get list of Domain Admins from domain controller via LDAP
    # ----------------------------------------------------------------
    
    $CurrentDomain = $ObjDomain.distinguishedName
    $ObjSearcher.PageSize = $Limit
    $ObjSearcher.Filter = "(&(objectCategory=user)(memberOf=CN=Domain Admins,CN=Users,$CurrentDomain))"
    $ObjSearcher.SearchScope = $SearchScope
    $CurrentUser = $Credential.UserName
    
    if ($SearchDN)
    {
      $ObjSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
    }
    
    
    # Place a list of domain admin in data table
    $ObjSearcher.FindAll() | ForEach-Object {
      $TableDomainAdmins.Rows.Add($($_.properties.samaccountname)) | Out-Null                                          
    } 
    
    # ----------------------------------------------------------------
    # Get list of SQL Server instances from domain controller via LDAP
    # ----------------------------------------------------------------
    
    # Setup LDAP query parameters
    $CurrentDomain = $ObjDomain.distinguishedName
    $ObjSearcher.PageSize = $Limit
    $ObjSearcher.Filter = '(ServicePrincipalName=*MSSQLSvc*)'
    $ObjSearcher.SearchScope = $SearchScope        
    
    if ($SearchDN)
    {
      $ObjSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
    }        
    
    # Status user
    [string]$CurrentUser = $Credential.UserName
    if ($CurrentUser -eq ""){
      $LDAPUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }else{
      $LDAPUser = $Credential.UserName            
    }
    $StatusDomain = [system.directoryservices.activedirectory.domain]::GetCurrentDomain().PdcRoleOwner.Domain.Name
    $StatusDC = [system.directoryservices.activedirectory.domain]::GetCurrentDomain().PdcRoleOwner.Name        
    $StartTime = Get-Date
    Write-Host '[*] ----------------------------------------------------------------------'
    Write-Host "[*] Start Time: $StartTime"        
    Write-Host "[*] Domain: $StatusDomain"
    Write-Host "[*] DC: $StatusDC"
    Write-Host "[*] Getting list of SQL Server instances from DC as $LDAPUser..."         
    
    # Get a count of the number of accounts that match the LDAP query
    $Records = $ObjSearcher.FindAll()
    $RecordCount = $Records.count
    
    # Check if any SQL Servers were found in Active Directory
    if ($RecordCount -gt 0){              
      
      # Process LDAP query results                
      $ObjSearcher.FindAll() | ForEach-Object {               
        
        # Start processing
        $SPN_Count = $_.properties['ServicePrincipalName'].count
        if ($SPN_Count -gt 0)
        {
          # Parse records from ldap
          foreach ($item in $_.properties['ServicePrincipalName'])
          {
            # Grab hostname and service type
            $SpnServer =  $item.split('/')[1].split(':')[0]
            $SpnServerFull = $item.split('/')[1] 	
            $SpnService =  $item.split('/')[0]  
            
            # Filter for only SQL Server instances
            if ($SpnService -eq 'MSSQLsvc'){                                            
              
              # Check if a port or named instance is used
              $ConnectParse = $item.split("/")[1].split(":")[1]                             
              Add-Type -Assembly Microsoft.VisualBasic
              $ConType = [Microsoft.VisualBasic.Information]::IsNumeric($ConnectParse)
              if($Contype -eq 'True'){
                $SpnServerInstance = $SpnServerFull -replace ':', ',' 
              }else{
                $SpnServerInstance = $SpnServerFull -replace ':', '\'                             
              } 
              
              # Add SQL Server instance to list
              $TableLDAP.Rows.Add($SpnServer, $SpnServerInstance) | Out-Null  
            }
          }
        }                                
      } 
      
      # Status user
      $SQLServerCount = $TableLDAP.Rows.Count
      Write-Host "[*] $SQLServerCount SQL Server instances found in LDAP."      	  
      
      # ------------------------------------------------------------
      # Get list of SQL Servers from a file (if one was provided)
      # ------------------------------------------------------------  
      if($File){
        
        # Check if file exists
        [string]$FileExist = Test-Path $File
        
        if ($FileExist -eq 'True'){
          
          # Import list of SQL Server instances from file to TableLDAP
          Get-Content $File | ForEach-Object {
            
            # Test current item
            $TheInstance = $_
            
            # Parse server and instance 
            If($TheInstance.Contains(',') -eq 'True'){
              $TheServer = $TheInstance.split(',')[0]
            }elseif($TheInstance.Contains('\') -eq 'True'){
              $TheServer = $TheInstance.split('\')[0]
            }else{
              $TheServer = $TheInstance
            }                                
            
            # Add server and instance to TableLDAP datatable
            $TableLDAP.Rows.Add($TheServer,$TheInstance) | Out-Null                           
          }
          
          # Update counters
          $SQLServerFinalCount = $TableLDAP.Rows.Count
          $SQLServerList = $SQLServerFinalCount-$SQLServerCount
          
          Write-Host "[*] $SQLServerList SQL Server instances found in $File"
          
        }else{
          
          # Status user
          Write-host '[-] The file provided does not exist.'
        }
      }else{
        $SQLServerFinalCount = $TableLDAP.Rows.Count
      }

      # ------------------------------------------------------------
      # Only List SQL Servers Found
      # ------------------------------------------------------------
	  if ($ListOnly) {
		Write-Host "[*] Listing SQL Server instances..."		
		$TableLDAP | sort server,instance
        Break
	  }
      
      # ------------------------------------------------------------
      # Test access to each SQL Server instance and grab basic info
      # ------------------------------------------------------------ 
      
      # Status user
      Write-Host "[*] Attempting to login into $SQLServerFinalCount SQL Server instances as $DBUser..."
      Write-Host '[*] ----------------------------------------------------------------------'  
      
      # Display results in list view that can feed into the pipeline
      $TableLDAP |  Sort-Object server,instance| select server,instance -unique | foreach {
        
        #------------------------
        # Setup connection string
        #------------------------
        
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $SQLServer = $_.server
        $SQLInstance = $_.instance       
        
        # Set authentication type      
        if($SQLUser -and $SQLPass){   
          
          # SQL login
          $conn.ConnectionString = "Server=$SQLInstance;Database=master;User ID='$SQLUser';Password='$SQLPass';" 
        }else{
          
          # Trusted connection
          $conn.ConnectionString = "Server=$SQLInstance;Database=master;Integrated Security=SSPI;"                     
        }
        
        #-------------------------
        # Test database conection
        #-------------------------
        
        # Check if the server is up via ping
        if((Test-Connection -Cn $SQLServer -BufferSize 32 -Count 2 -ea 0 -quiet)) 
        {
          
          # Attempt to authenticate and query remote SQL Server instance
          Try 
          {
            
            # Get host ip address for SQL Server
            $SQLServerIP = [Net.Dns]::GetHostEntry($SQLServer).AddressList.IPAddressToString.split(" ")[0]
            
            # Create connection to system and issue query 
            $conn.Open()                        
            $sql= @"

                        -- Setup reg path 
                        DECLARE @SQLServerInstance varchar(250)  
                        if @@SERVICENAME = 'MSSQLSERVER'
                        BEGIN											
                            set @SQLServerInstance = 'SYSTEM\CurrentControlSet\Services\MSSQLSERVER'
                        END						
                        ELSE
                        BEGIN
                            set @SQLServerInstance = 'SYSTEM\CurrentControlSet\Services\MSSQL$'+cast(@@SERVICENAME as varchar(250))		
                        END

                        -- Grab service account from service's reg path
                        DECLARE @ServiceaccountName varchar(250)  
                        EXECUTE master.dbo.xp_instance_regread  
                        N'HKEY_LOCAL_MACHINE', @SQLServerInstance,  
                        N'ObjectName',@ServiceAccountName OUTPUT, N'no_output' 

                        DECLARE @MachineType  SYSNAME
                        EXECUTE master.dbo.xp_regread
                        @rootkey      = N'HKEY_LOCAL_MACHINE',
                        @key          = N'SYSTEM\CurrentControlSet\Control\ProductOptions',
                        @value_name   = N'ProductType', 
                        @value        = @MachineType output
                        
                        -- Grab more info about the server
                        SELECT @@servername as server,
                        @MachineType as MachineType,
                        serverproperty('edition') as Edition,
                        SERVERPROPERTY('productversion') as sqlver,
                        RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Windows NT', @@VERSION), 14), 3) as osver,
                        is_srvrolemember('sysadmin') as priv, 
                        (select SERVERPROPERTY('IsClustered')) as IsClustered,
                        (select count(srvname) from master..sysservers) as DBLinks,
                        @ServiceAccountName as SvcAcct
"@
            
            $cmd = New-Object System.Data.SqlClient.SqlCommand($sql,$conn)
            $cmd.CommandTimeout = 0
            $results = $cmd.ExecuteReader()
            $MyTempTable = new-object 'System.Data.DataTable'
            $MyTempTable.Load($results)
            
            # Parse query data from SQL Server and add info to data table
            foreach ($row in $MyTempTable){                             
              
              $Edition = $($MyTempTable.Edition)
              
              # Set the SQL Server version
              $SQLVersioncheck = $MyTempTable.sqlver.split('.')[0]
              if ( $SQLVersioncheck -eq '7' ){ $SQLVersion = "7 $Edition" }
              elseif ( $SQLVersioncheck -eq '8' ){ $SQLVersion = "2000 $Edition" }
              elseif ( $SQLVersioncheck -eq '9' ){ $SQLVersion = "2005 $Edition" }
              elseif ( $SQLVersioncheck -eq '10' ){ $SQLVersion = "2008 $Edition" }
              elseif ( $SQLVersioncheck -eq '11' ){ $SQLVersion = "2012 $Edition" }
              else { $SQLVersion = $MyTempTable.sqlver }
              
              # Set the Windows version
              $OSVersioncheck = $MyTempTable.osver.split('.')[0]+'.'+$MyTempTable.osver.split(".")[1]
              if ( $OSVersioncheck -eq '6.3' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2012' }                            
              elseif ( $OSVersioncheck -eq '6.3' -and $($MyTempTable.MachineType) -eq 'WinNT'){ $OSVersion = '8.1' }  
              elseif ( $OSVersioncheck -eq '6.2' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2012' }
              elseif ( $OSVersioncheck -eq '6.2' -and $($MyTempTable.MachineType) -eq 'WinNT'){ $OSVersion = '8' }
              elseif ( $OSVersioncheck -eq '6.1' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2008 R2' }
              elseif ( $OSVersioncheck -eq '6.1' -and $($MyTempTable.MachineType) -eq 'WinNT'){ $OSVersion = '7' }
              elseif ( $OSVersioncheck -eq '6.0' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2008' }
              elseif ( $OSVersioncheck -eq '6.0' -and $($MyTempTable.MachineType) -eq 'WinNT'){ $OSVersion = 'Vista' }
              elseif ( $OSVersioncheck -eq '5.2' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2003' }
              elseif ( $OSVersioncheck -eq '5.1' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2003' }
              elseif ( $OSVersioncheck -eq '5.1' -and $($MyTempTable.MachineType) -eq 'WinNT'){ $OSVersion = 'XP' }
              elseif ( $OSVersioncheck -eq '5.0' -and $($MyTempTable.MachineType) -eq 'ServerNT'){ $OSVersion = '2000' }
              else { $OSVersion = $MyTempTable.osver }
              
              # Check if user is a sysadmin
              if ($($MyTempTable.priv) -eq 1){
                $DBAaccess = 'Yes'
              }else{
                $DBAaccess = 'No'
              }
              
              # Check if server is clustered
              if ($($MyTempTable.IsClustered) -eq 1){
                $IsClustered = 'Yes'
              }else{
                $IsClustered = 'No' 
              }
              
              # Check if server has database links - removing one, because a link to 
              # always exists to itself without data access
              if ($($MyTempTable.DBLinks) -le 1){
                $DBLinks = 0
              }else{
                $DBLinks = $MyTempTable.DBLinks-1
              }
              
              # Check if service account is a domain admin
              $IsDA = 'No' 
              $JustAccount = $($MyTempTable.SvcAcct).split('\')[1]
              $TableDomainAdmins | ForEach-Object {
                
                $DAUser=$_.Account                                
                if( $DAUser.toLower() -eq $JustAccount.toLower()){
                  $IsDA = 'Yes' 
                }                                                                    
              }
              
              # Set service account
              $SQLServiceAccount = $($MyTempTable.SvcAcct)
              
              # Add the SQL Server information to the data table
              $TableSQL.Rows.Add($SQLServerIP, $SQLServer, $SQLInstance, $SQLVersion,$OSVersion,$DBAaccess,$($MyTempTable.SvcAcct),$IsDA,$IsClustered,$DBLinks) | Out-Null     
              
            }                                                  
            
            # Set status color   
            if ( $DBAaccess -eq 'Yes'){ $LineColor = 'red' }
            elseif ($IsDA -eq 'Yes' ){  $LineColor = 'red'  }
            else{ $LineColor = 'green' }
            
            # Status user
            Write-Host "[+] SUCCESS! - $SQLInstance ($SQLServerIP) - Sysadmin: $DBAaccess - SvcIsDA: $IsDA"  -foreground $LineColor                              
            
            # Run custom querys                           
            if($query){
              
              # Status user
              Write-Host "[+] Custom query sent: $query" -foreground $LineColor 
              Write-Host '[+] Query output:' -foreground $LineColor 
              
              # Set custom SQL query
              $sql= @"

                          -- custom query 
                          $query
"@
              $cmd = New-Object System.Data.SqlClient.SqlCommand($sql,$conn)
              $cmd.CommandTimeout = 0
              $results = $cmd.ExecuteReader()
              $MyTempTable2 = new-object 'System.Data.DataTable'
              $MyTempTable2.Load($results)
              
              # Display custom query results                  
              $MyTempTable2 
            }                        
            
            # Show status table
            if($ShowStatus){                            
              $TableSQL | Format-Table -Autosize
            }
            
            # close connection                            
            $conn.Close();                           
            
          }
          Catch {
            
            # Status user
            Write-Host "[-] Failed   - $SQLInstance ($SQLServerIP) is up, but authentication/query failed"                        
          }
          
        }else{
          
          # Status user
          Write-Host "[-] Failed   - $SQLInstance is not responding to pings"
        }
        
      } # End SQL Server ping loop
      
      #-------------------------
      # Display final results
      #-------------------------
      $EndTime = Get-Date
      $TotalTime = NEW-TIMESPAN Start $Starttime End $Endtime   
      $SQLServerLoginCount = $TableSQL.Rows.count
      
      #Display total servers and time                
      Write-Host '[*] ----------------------------------------------------------------------'  
      Write-Host "[*] $SQLServerLoginCount of $SQLServerCount SQL Server instances could be accessed."                                             
      Write-Host "[*] End Time: $Endtime"                
      Write-Host "[*] Total Time: $TotalTime" 
      Write-Host '[*] ----------------------------------------------------------------------' 
      
      # Display final results table                
      if($ShowSum){
        $TableSQL 
      }      
      
    }else{
      
      # Display fail            
      Write-Host '[-] No SQL Servers were found in Active Directory.'            
      
    } # End database loop
    
  }  # End process 
  
} # End function                      





