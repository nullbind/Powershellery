# Author: Scott Sutherland 2013, NetSPI
# Version: Get-SQLServerAccess v.01
# Requirements: Powershell v.3

# todo
# ----
# fix custom query trunction, and lack of column names after first time
# fix pop up = $credential = New-Object System.Management.Automation.PsCredential(".\administrator", (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force))
# update help

function Get-SQLServerAccess
{	
	<#
	.SYNOPSIS
	   Displays Service Principal Names (SPN) for domain accounts based on SPN service name, domain account, or domain group via LDAP queries.
	   
	.DESCRIPTION
	   Sends LDAP queries to the domain controller to query for SQL Servers on the domain using
       the Service Principal Names (SPN). The list is then used to test if the provided user has
       access to login along with some based configuration information.The script currently supports 
	   trusted connections and provided credentials.
	
	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
       access to.  This is the default output.
	   
	   PS C:\Get-SQLServerAccess.ps1

        [*] ----------------------------------------------------------------------
        [*] Start Time: 04/09/2014 17:02:33
        [*] Domain: mydomain.com
        [*] DC: dc1.mydomain.com
        [*] Getting list of SQL Server instances from DC as mydomain\myuser...
        [*] 59 SQL Server instances found.
        [*] Attempting to login into 59 SQL Server instances as mydomain\myuser...
        [*] ----------------------------------------------------------------------
        [-] Failed   - server1.mydomain.com is not responding to pings
        [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
        [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
        [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
        [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
        [*] ----------------------------------------------------------------------
        [+] 3 of 5 SQL Server instances could be accessed.        
        [*] End Time: 04/03/2014 10:58:00      
        [*] Total Time: 00:03:00
        [*] ----------------------------------------------------------------------

	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain and 
       attempt to authenticate using provides SQL Server credentials.  
       This is the default output.
	   
	   PS C:\Get-SQLServerAccess.ps1 -SQLUser test -SQLPass $up3r$3cur3P@$$w0rd

        [*] ----------------------------------------------------------------------
        [*] Start Time: 04/09/2014 17:02:33
        [*] Domain: mydomain.com
        [*] DC: dc1.mydomain.com
        [*] Getting list of SQL Server instances from DC as mydomain\myuser...
        [*] 59 SQL Server instances found.
        [*] Attempting to login into 59 SQL Server instances as test...
        [*] ----------------------------------------------------------------------
        [-] Failed   - server1.mydomain.com is not responding to pings
        [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
        [+] Failed - server3.mydomain.com,1433 (192.168.1.103) - is up, but authentication/query failed
        [+] Failed - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - is up, but authentication/query failed
        [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
        [*] ----------------------------------------------------------------------
        [+] 3 of 5 SQL Server instances could be accessed.        
        [*] End Time: 04/03/2014 10:58:00      
        [*] Total Time: 00:03:00
        [*] ----------------------------------------------------------------------

	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
       access to.  This also displays a data table object at the end that is pipeable in 
       PowerShell.  You can make it pretty using the format-table syntax example below.
	   
	   PS C:\Get-SQLServerAccess.ps1 -ShowSum | format-table -AutoSize 

        [*] ----------------------------------------------------------------------
        [*] Start Time: 04/09/2014 17:02:33
        [*] Domain: mydomain.com
        [*] DC: dc1.mydomain.com
        [*] Getting list of SQL Server instances from DC as mydomain\myuser...
        [*] 59 SQL Server instances found.
        [*] Attempting to login into 59 SQL Server instances as mydomain\myuser...
        [*] ----------------------------------------------------------------------
        [-] Failed   - server1.mydomain.com is not responding to pings
        [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
        [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
        [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
        [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
        [*] ----------------------------------------------------------------------
        [+] 3 of 5 SQL Server instances could be accessed.        
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
	   
	   PS C:\Get-SQLServerAccess.ps1 -ShowSum | export-csv c:\temp\mysqlaccess.csv

        [*] ----------------------------------------------------------------------
        [*] Start Time: 04/09/2014 17:02:33
        [*] Domain: mydomain.com
        [*] DC: dc1.mydomain.com
        [*] Getting list of SQL Server instances from DC as mydomain\myuser...
        [*] 59 SQL Server instances found.
        [*] Attempting to login into 59 SQL Server instances as mydomain\myuser...
        [*] ----------------------------------------------------------------------
        [-] Failed   - server1.mydomain.com is not responding to pings
        [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
        [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
        [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
        [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes             
        [*] ----------------------------------------------------------------------
        [+] 3 of 5 SQL Server instances could be accessed.        
        [*] End Time: 04/03/2014 10:58:00      
        [*] Total Time: 00:03:00
        [*] ----------------------------------------------------------------------
        
	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
       access to.  This will display the default output, but also display a data table of
       SQL Servers that are accessible every time a successful connection is made.
	   
	   PS C:\Get-SQLServerAccess.ps1 -ShowStatus 

        [*] ----------------------------------------------------------------------
        [*] Start Time: 04/09/2014 17:02:33
        [*] Domain: mydomain.com
        [*] DC: dc1.mydomain.com
        [*] Getting list of SQL Server instances from DC as mydomain\myuser...
        [*] 59 SQL Server instances found.
        [*] Attempting to login into 59 SQL Server instances as mydomain\myuser...
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
        [+] 3 of 5 SQL Server instances could be accessed.        
        [*] End Time: 04/03/2014 10:58:00      
        [*] Total Time: 00:03:00
        [*] ----------------------------------------------------------------------    
        
	.EXAMPLE
	   Returns a list of SQL Server instances on the current user's domain that they have
       access to.  This will display the default output, but also display the results of
       a custom query defined by the user.
	   
	   PS C:\Get-SQLServerAccess.ps1 -query "select @@servername"  

        [*] ----------------------------------------------------------------------
        [*] Start Time: 04/09/2014 17:02:33
        [*] Domain: mydomain.com
        [*] DC: dc1.mydomain.com
        [*] Getting list of SQL Server instances from DC as mydomain\myuser...
        [*] 59 SQL Server instances found.
        [*] Attempting to login into 59 SQL Server instances as mydomain\myuser...
        [*] ----------------------------------------------------------------------
        [-] Failed   - server1.mydomain.com is not responding to pings
        [-] Failed   - server2.mydomain.com (192.168.1.102) is up, but authentication/query failed
        [+] SUCCESS! - server3.mydomain.com,1433 (192.168.1.103) - Sysadmin: No - SvcIsDA: No 
        [+] Query sent: select @@servername
        [+] Query output:
                                                                 
        server3        
          
        [+] SUCCESS! - server3.mydomain.com\SQLEXPRESS (192.168.1.103) - Sysadmin: No - SvcIsDA: No
        [+] Query sent: select @@servername
        [+] Query output:
                                                                 
        server3\SQLEXPRESS                                  
          
        [+] SUCCESS! - server4.mydomain.com\AppData (192.168.1.104) - Sysadmin: Yes - SvcIsDA: Yes       
        [+] Query sent: select @@servername
        [+] Query output:
                                                                 
        server4\AppData                          
             
        [*] ----------------------------------------------------------------------
        [+] 3 of 5 SQL Server instances could be accessed.        
        [*] End Time: 04/03/2014 10:58:00      
        [*] Total Time: 00:03:00
        [*] ----------------------------------------------------------------------                 

	 .LINK
		http://www.netspi.com
        http://support.microsoft.com/?kbid=304721 to figure out workstation vs server
        http://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx
	
	#>
    [CmdletBinding()]
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
        HelpMessage="At the end of the scan display the results in a pipeable datatable format.")]
        [switch]$ShowSum,

        [Parameter(Mandatory=$false,
        HelpMessage="Display a status table after accessing each SQL Server instance successfully.")]
        [switch]$ShowStatus,

        [Parameter(Mandatory=$false,
        HelpMessage="Set SQL Login username.")]
        [string]$SQLUser,

        [Parameter(Mandatory=$false,
        HelpMessage="Set SQL Login password.")]
        [string]$SQLPass,

        [Parameter(Mandatory=$false,
        HelpMessage="Allows users to run a custom query on all accessible SQL Server instances.")]
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

        # ----------------------------------------------------------------
        # Setup data tables
        # ----------------------------------------------------------------
        
        # Create data table to house list of domain admins
        $TableDomainAdmins = New-Object System.Data.DataTable 

        # Create and name columns in the domainadmintable
        $TableDomainAdmins.Columns.Add("Account") | Out-Null
        
        # Create data table to house list of sql servers found in ldap
        $TableLDAP = New-Object System.Data.DataTable 

        # Create and name columns in the TableLDAP data table
        $TableLDAP.Columns.Add("Server") | Out-Null 
        $TableLDAP.Columns.Add("Instance") | Out-Null  

        # Create data table to house info for accessible sql server instances
        $TableSQL = New-Object System.Data.DataTable 

        # Create and name columns in the TableSQL
        $TableSQL.Columns.Add("IpAddress") | Out-Null
        $TableSQL.Columns.Add("Server") | Out-Null
        $TableSQL.Columns.Add("Instance") | Out-Null
        $TableSQL.Columns.Add("SQLVer") | Out-Null  
        $TableSQL.Columns.Add("OsVer") | Out-Null 
        $TableSQL.Columns.Add("Sysadmin") | Out-Null 
        $TableSQL.Columns.Add("SvcAcct") | Out-Null 
        $TableSQL.Columns.Add("SvcIsDA") | Out-Null
        $TableSQL.Columns.Add("IsClustered") | Out-Null
        $TableSQL.Columns.Add("DBLinks") | Out-Null   

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
        $ObjSearcher.Filter = "(ServicePrincipalName=*MSSQLSvc*)"
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
        Write-Host "[*] ----------------------------------------------------------------------"
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
                        $SpnServer =  $item.split("/")[1].split(":")[0]
                        $SpnServerFull = $item.split("/")[1] 	
                        $SpnService =  $item.split("/")[0]  

                        # Filter for only SQL Server instances
                        if ($SpnService -eq "MSSQLsvc"){                                            

                            # Check if a port or named instance is used
                            $ConnectParse = $item.split("/")[1].split(":")[1]                             
                            Add-Type -Assembly Microsoft.VisualBasic
                            $ConType = [Microsoft.VisualBasic.Information]::IsNumeric($ConnectParse)
                            if($Contype -eq "True"){
                                $SpnServerInstance = $SpnServerFull -replace ":", "," 
                            }else{
                                $SpnServerInstance = $SpnServerFull -replace ":", "\"                             
                            } 
                                                        
                            # Add SQL Server instance to list
                            $TableLDAP.Rows.Add($SpnServer, $SpnServerInstance) | Out-Null  
                        }
                    }
                }                                
            } 

            # ------------------------------------------------------------
            # Test access to each SQL Server instance and grab basic info
            # ------------------------------------------------------------          

            # Status user
            if($SQLUser -and $SQLPass){
                $DBUser = $SQLUser
            }else{
                $DBUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            }

            $SQLServerCount = $TableLDAP.Rows.Count
            Write-Host "[*] $SQLServerCount SQL Server instances found."    
            Write-Host "[*] Attempting to login into $SQLServerCount SQL Server instances as $DBUser..."
            Write-Host "[*] ----------------------------------------------------------------------" 

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
                if((Test-Connection -Cn $SQLServer -BufferSize 16 -Count 1 -ea 0 -quiet)) 
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
                        $MyTempTable = new-object “System.Data.DataTable”
                        $MyTempTable.Load($results)

                        # Parse query data from SQL Server and add info to data table
                        foreach ($row in $MyTempTable){                             

                            $Edition = $($MyTempTable.Edition)

                            # Set the SQL Server version
                            $SQLVersioncheck = $MyTempTable.sqlver.split(".")[0]
                            if ( $SQLVersioncheck -eq '7' ){ $SQLVersion = "7 $Edition" }
                            elseif ( $SQLVersioncheck -eq '8' ){ $SQLVersion = "2000 $Edition" }
                            elseif ( $SQLVersioncheck -eq '9' ){ $SQLVersion = "2005 $Edition" }
                            elseif ( $SQLVersioncheck -eq '10' ){ $SQLVersion = "2008 $Edition" }
                            elseif ( $SQLVersioncheck -eq '11' ){ $SQLVersion = "2012 $Edition" }
                            else { $SQLVersion = $MyTempTable.sqlver }

                            # Set the Windows version
                            $OSVersioncheck = $MyTempTable.osver.split(".")[0]+"."+$MyTempTable.osver.split(".")[1]
                            if ( $OSVersioncheck -eq '6.3' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2012" }                            
                            elseif ( $OSVersioncheck -eq '6.3' -and $($MyTempTable.MachineType) -eq "WinNT"){ $OSVersion = "8.1" }  
                            elseif ( $OSVersioncheck -eq '6.2' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2012" }
                            elseif ( $OSVersioncheck -eq '6.2' -and $($MyTempTable.MachineType) -eq "WinNT"){ $OSVersion = "8" }
                            elseif ( $OSVersioncheck -eq '6.1' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2008 R2" }
                            elseif ( $OSVersioncheck -eq '6.1' -and $($MyTempTable.MachineType) -eq "WinNT"){ $OSVersion = "7" }
                            elseif ( $OSVersioncheck -eq '6.0' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2008" }
                            elseif ( $OSVersioncheck -eq '6.0' -and $($MyTempTable.MachineType) -eq "WinNT"){ $OSVersion = "Vista" }
                            elseif ( $OSVersioncheck -eq '5.2' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2003" }
                            elseif ( $OSVersioncheck -eq '5.1' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2003" }
                            elseif ( $OSVersioncheck -eq '5.1' -and $($MyTempTable.MachineType) -eq "WinNT"){ $OSVersion = "XP" }
                            elseif ( $OSVersioncheck -eq '5.0' -and $($MyTempTable.MachineType) -eq "ServerNT"){ $OSVersion = "2000" }
                            else { $OSVersion = $MyTempTable.osver }

                            # Check if user is a sysadmin
                            if ($($MyTempTable.priv) -eq 1){
                                $DBAaccess = "Yes"
                            }else{
                                $DBAaccess = "No"
                            }

                            # Check if server is clustered
                            if ($($MyTempTable.IsClustered) -eq 1){
                                $IsClustered = "Yes"
                            }else{
                                $IsClustered = "No"
                            }

                            # Check if server has database links - removing one, because link to 
                            # the db server always exists without data access
                            if ($($MyTempTable.DBLinks) -le 1){
                                $DBLinks = 0
                            }else{
                                $DBLinks = $MyTempTable.DBLinks-1
                            }

                            # Check if service account is a domain admin
                            $IsDA = "No" 
                            $JustAccount = $($MyTempTable.SvcAcct).split("\")[1]
                            $TableDomainAdmins | ForEach-Object {

                                $DAUser=$_.Account                                
                                if( $DAUser -eq $JustAccount){
                                    $IsDA = "Yes" 
                                }                                                                    
                            }

                            # Set service account
                            $SQLServiceAccount = $($MyTempTable.SvcAcct)

                            # Add the SQL Server information to the data table
                            $TableSQL.Rows.Add($SQLServerIP, $SQLServer, $SQLInstance, $SQLVersion,$OSVersion,$DBAaccess,$($MyTempTable.SvcAcct),$IsDA,$IsClustered,$DBLinks) | Out-Null     
                                                                                                             
                        }                                                  
                        
                        # Set status color   
                        if ( $DBAaccess -eq "Yes"){ $LineColor = "red" }
                        elseif ($IsDA -eq "Yes" ){  $LineColor = "red"  }
                        else{ $LineColor = "green" }
                            
                        # Status user
                        Write-Host "[+] SUCCESS! - $SQLInstance ($SQLServerIP) - Sysadmin: $DBAaccess - SvcIsDA: $IsDA"  -foreground $LineColor                              

                        # Run custom querys                           
                        # Set query
                        if($query){
                         Write-Host "[+] Custom query sent: $query" -foreground $LineColor 
                         Write-Host "[+] Query output:" -foreground $LineColor 
                        $sql= @"

                        -- custom query 
                        $query
"@
                            $cmd = New-Object System.Data.SqlClient.SqlCommand($sql,$conn)
                            $cmd.CommandTimeout = 0
                            $results = $cmd.ExecuteReader()
                            $MyTempTable2 = new-object “System.Data.DataTable”
                            $MyTempTable2.Load($results)
                            Write-Host " "
                            $MyTempTable2 
                            Write-Host " "
                        }

                        # Show status table
                        if($ShowStatus){
                            Write-Host "[+] Status table output:" -foreground $LineColor 
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

            } # End SQL Server instnace foreach loop

            
            #-------------------------
            # Display final results
            #-------------------------
            $EndTime = Get-Date
            $TotalTime = NEW-TIMESPAN –Start $Starttime –End $Endtime   
            $SQLServerLoginCount = $TableSQL.Rows.count
                                            
            #Display total servers and time                
            Write-Host "[*] ----------------------------------------------------------------------"  
            Write-Host "[*] $SQLServerLoginCount of $SQLServerCount SQL Server instances could be accessed."                                             
            Write-Host "[*] End Time: $Endtime"                
            Write-Host "[*] Total Time: $TotalTime" 
            Write-Host "[*] ----------------------------------------------------------------------" 
                
            # Display final results table                
            if($ShowSum){
                $TableSQL 
            }      
                  
        }else{

            # Display fail            
            Write-Host "[-] No SQL Servers were found in Active Directory."            

        } # End database loop

    }  # End process 

} # End function                


#
# Testing commands...
#



# Working


# Get-SQLServerAccess # Default output
# Get-SQLServerAccess -ShowSum | Format-Table -AutoSize # Default output, and pipeable table at end
# Get-SQLServerAccess -ShowSum | Export-Csv c:\temp\mysqlaccess.csv # Default output, and output to csv
# Get-SQLServerAccess -ShowSum -ShowStatus # Default output, summary table at end, and show status table after every successful SQL Server connection
# Get-SQLServerAccess -ShowStatus -showsum # Default output, and show status table after every successful SQL Server connection
# Get-SQLServerAccess -query "select @@servername,@@version"  # Default output with custom query
# Get-SQLServerAccess -Credential demo\user # Default output, but use alternative domain creds to auth to dc
# Get-SQLServerAccess -SQLUser test -SQLPass test # Default output, authenticating with sql creds

# Need to fix bugs
# Get-SQLServerAccess -ShowSum -ShowStatus -query "select @@servername"  # output starts out fine, but then order gets out of whack

# Not really tested
# Get-SQLServerAccess -DomainController 192.168.1.100 -Credential demo\user password -sqluser sa -sqlpass Password1 #Supplied Domain Creds and SQL Creds                                      
# runas /netonly /user:mydomain\myuser "Powershell ./Get-SQLServerAccess.ps1" #run as another user


