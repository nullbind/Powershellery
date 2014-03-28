# Author: Scott Sutherland 2013, NetSPI
# Version: Invoke-FindandQuerySQL version .01
# Requirements: Powershell v.3

# todo
# ----
# add help to show how to runas as alternative windows user # powershell.exe -Credential "TestDomain\Me" -NoNewWindow
# add switch to connect to database as sql user
# add other fields dblinks,svcacct,clustered - also grad das via ldap and check if svcacct is domain admin
# update help
# Make it all pretty
# get number sql sessions/users into sql server - SELECT login_name ,COUNT(session_id) AS session_count FROM sys.dm_exec_sessions GROUP BY login_name;
# get list of connected hosts - should reveal app/web servers - select hostname from sys.sysprocesses 
# fix pop up = $credential = New-Object System.Management.Automation.PsCredential(".\administrator", (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force))

function Invoke-FindandQuerySQL
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
	   Return a list of SQL Servers that have registered SPNs in LDAP on the current user's domain using the trusted connection (current user).
	   
	   PS C:\Invoke-FindandQuerySQL.ps1 -DomainController 192.168.1.100 -Credential domain\user	   

        [ ] Sending LDAP query to 192.168.1.100 as demo\user...
        [ ] ---------------------------------------------------
        [ ] 4 SQL Servers will be tested...
        [ ] ---------------------------------------------------	   
        [-] server1.acme.local,58697 is down!
        [-] server2.acme.local is up - authentication failed or bad query
        [+] server3.acme.local,1433 is up - authentication successful
        [+] server4.acme.local\SQLEXPRESS is up - authentication successful
        [ ] ---------------------------------------------------
        [ ] Testing of access to SQL Server complete.
        [+] 6 SQL Servers could be accessed by demo\user
        [ ] ---------------------------------------------------
        	   
	.EXAMPLE
	   Return a list of SQL Servers that have registered SPNs in LDAP on the current user's domain using a provided set of domain cedentials.
	   
	   PS C:\Invoke-FindandQuerySQL.ps1 -DomainController 192.168.1.100 -Credential domain\user	   

        [ ] Sending LDAP query to 192.168.1.100 as demo\user...
        [ ] ---------------------------------------------------
        [ ] 4 SQL Servers will be tested...
        [ ] ---------------------------------------------------	   
        [-] server1.acme.local,58697 is down!
        [-] server2.acme.local is up - authentication failed or bad query
        [+] server3.acme.local,1433 is up - authentication successful
        [+] server4.acme.local\SQLEXPRESS is up - authentication successful
        [ ] ---------------------------------------------------
        [ ] Testing of access to SQL Server complete.
        [+] 6 SQL Servers could be accessed by demo\user
        [ ] ---------------------------------------------------
	   
	.EXAMPLE
	   Return a list of SQL Servers that the user can log into.
	   PS C:\Invoke-FindandQuerySQL.ps1 -table yes -DomainController 192.168.1.100 -Credential domain\user
	   
	   Server        Version      User      Sysadmin   SvcAcct     DBLinks
	   -------       ------       -------   --------   -------     -----
	   sqladmin      DB1.demo.com MSSQLSvc	  1        LocalSystem   5

	.EXAMPLE
	   Return a list of SQL Servers that have registered SPNs in LDAP on the current user's domain.
	   
	   PS C:\Invoke-FindandQuerySQL.ps1 -query "select name from master..sysdatabases" -DomainController 192.168.1.100 -Credential domain\user	   

        [ ] Sending LDAP query to 192.168.1.100 as demo\user...
        [ ] ---------------------------------------------------
        [ ] 4 SQL Servers will be tested...
        [ ] ---------------------------------------------------	      
        [-] server1.acme.local,58697 is down!
        [-] server2.acme.local is up - authentication failed or bad query
        [+] server3.acme.local,1433 is up - authentication successful
            Query Data: master tempdb model msdb 
        [+] server4.acme.local\SQLEXPRESS is up - authentication successful
            Query Data: master tempdb model msdb 
        [ ] ---------------------------------------------------
        [ ] Testing of access to SQL Server complete.
        [+] 6 SQL Servers could be accessed by demo\user
        [ ] ---------------------------------------------------

	 .LINK
		http://www.netspi.com
	
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
        HelpMessage="View additional information during discovery.")]
        [string]$ShowTable
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

        #----------------------------
        # Setup data tables
        #----------------------------
        
        # Create data table to house initial ldap query results
        $TableLDAP = New-Object System.Data.DataTable 

        # Create and name columns in the TableLDAP data table
        $TableLDAP.Columns.Add("Server") | Out-Null 
        $TableLDAP.Columns.Add("Instance") | Out-Null  

        # Create data table to house database access results
        $TableSQL = New-Object System.Data.DataTable 

        # Create and name columns in the data table
        $TableSQL.Columns.Add("ipaddress") | Out-Null
        $TableSQL.Columns.Add("server") | Out-Null
        $TableSQL.Columns.Add("instance") | Out-Null
        $TableSQL.Columns.Add("sqlver") | Out-Null  
        $TableSQL.Columns.Add("osver") | Out-Null 
        $TableSQL.Columns.Add("sysadmin") | Out-Null 
        #$TableSQL.Columns.Add("svcacct") | Out-Null 
        #$TableSQL.Columns.Add("dblinks") | Out-Null # (select count(srvname) from master..sysservers)
        ##$TableSQL.Columns.Add("IsClustered") | Out-Null # (select SERVERPROPERTY('IsClustered')) 

        #----------------------------
        # Setup LDAP query parameters
        #----------------------------
        $CurrentDomain = $ObjDomain.distinguishedName
        $ObjSearcher.PageSize = $Limit
        $ObjSearcher.Filter = "(ServicePrincipalName=*MSSQLSvc*)"
        $ObjSearcher.SearchScope = $SearchScope
        $CurrentUser = $Credential.UserName

        if ($SearchDN)
        {
            $ObjSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")
        }

        # Status user
        $StartTime = Get-Date
        Write-Host "[*] ----------------------------------------------------------------------"
        Write-Host "[*] Start Time: $StartTime"        
        Write-Host "[*] Getting a list of SQL Server instances from the domain controller..."         


        # --------------------------------------------------------
        # Get list of SQL Server instances from domain controller
        # --------------------------------------------------------

        # Get a count of the number of accounts that match the LDAP query
        $Records = $ObjSearcher.FindAll()
        $RecordCount = $Records.count

        # Check if any SQL Servers were found in Active Directory
        if ($RecordCount -gt 0){              

            # Process LDAP query results                
            $ObjSearcher.FindAll() | ForEach-Object {

                # Fill hash array with results                    
                $UserProps = [ordered]@{}                    
                $UserProps.Add('SPN Count', "$($_.properties['ServicePrincipalName'].count)")                 

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
                                     
                            #$SpnServer       

                            # Check if a port or named instance is used
                            $ConnectParse = $item.split("/")[1].split(":")[1]                             
                            Add-Type -Assembly Microsoft.VisualBasic
                            $ConType = [Microsoft.VisualBasic.Information]::IsNumeric($ConnectParse)
                            if($Contype -eq "True"){
                                $SpnServerInstance = $SpnServerFull -replace ":", "," 
                            }else{
                                $SpnServerInstance = $SpnServerFull -replace ":", "\"                             
                            } 
                                                        
                            # Add record to list
                            $TableLDAP.Rows.Add($SpnServer, $SpnServerInstance) | Out-Null  
                        }
                    }
                }                                
            } 

            # ------------------------------------------------------------
            # Test access to each SQL Server instance and grab basic info
            # ------------------------------------------------------------          

            # Status user
            $SQLServerCount = $TableLDAP.Rows.Count
            Write-Host "[+] $SQLServerCount SQL Server instances found."    
            Write-Host "[*] Attempting to login into $SQLServerCount SQL Server instances..."
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
                    #$conn.ConnectionString = "Server=$SQLInstance;Database=master;User ID=superadmin;Password=superpassword;" # Provided SQL Credentials
                    $conn.ConnectionString = "Server=$SQLInstance;Database=master;Integrated Security=SSPI;" # Trusted Connection                    

                    #-------------------------
                    # Test database conection
                    #-------------------------

                    # Check if the server is up via ping
                    if((Test-Connection -Cn $SQLServer -BufferSize 16 -Count 1 -ea 0 -quiet))               
                    {

                        Try
                        {
                            # Get host ip address
                            $SQLServerIP = [Net.Dns]::GetHostEntry($SQLServer).AddressList.IPAddressToString.split(" ")[0]

                            # Create connection to system and issue query 
                            $conn.Open()
                            $sql = "SELECT @@servername as server,SERVERPROPERTY('productversion') as sqlver,RIGHT(SUBSTRING(@@VERSION, CHARINDEX('Windows NT', @@VERSION), 14), 3) as osver,is_srvrolemember('sysadmin') as priv"
                            $cmd = New-Object System.Data.SqlClient.SqlCommand($sql,$conn)
                            $cmd.CommandTimeout = 0
                            $results = $cmd.ExecuteReader()
                            $MyTempTable = new-object “System.Data.DataTable”
                            $MyTempTable.Load($results)

                            # Add entry to sql server data table
                            foreach ($row in $MyTempTable){  
                            
                                # Get SQL Server Version
                                $SQLVersioncheck = $MyTempTable.sqlver.split(".")[0]
                                if ( $SQLVersioncheck -eq '7' ){ $SQLVersion = "7" }
                                    elseif ( $SQLVersioncheck -eq '8' ){ $SQLVersion = "2000" }
                                    elseif ( $SQLVersioncheck -eq '9' ){ $SQLVersion = "2005" }
                                    elseif ( $SQLVersioncheck -eq '10' ){ $SQLVersion = "2008" }
                                    elseif ( $SQLVersioncheck -eq '11' ){ $SQLVersion = "2012" }
                                else { $SQLVersion = $MyTempTable.sqlver }

                                # Get OS Server Version
                                # Use http://support.microsoft.com/?kbid=304721 to figure out workstation vs server
                                # http://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx
                                $OSVersioncheck = $MyTempTable.osver.split(".")[0]+"."+$MyTempTable.osver.split(".")[1]
                                if ( $OSVersioncheck -eq '7' ){ $OSVersion = "7" }
                                    elseif ( $OSVersioncheck -eq '6.3' ){ $OSVersion = "8.1/2012" }
                                    elseif ( $OSVersioncheck -eq '6.2' ){ $OSVersion = "8/2012" }
                                    elseif ( $OSVersioncheck -eq '6.1' ){ $OSVersion = "7/2008 R2" }
                                    elseif ( $OSVersioncheck -eq '6.0' ){ $OSVersion = "Vista/2008" }
                                    elseif ( $OSVersioncheck -eq '5.2' ){ $OSVersion = "2003" }
                                    elseif ( $OSVersioncheck -eq '5.1' ){ $OSVersion = "XP/2003" }
                                    elseif ( $OSVersioncheck -eq '5.0' ){ $OSVersion = "2000" }
                                else { $OSVersion = $MyTempTable.osver }

                                    # set sysadmin status
                                    if ($($MyTempTable.priv) -eq 1){
                                        $DBAaccess = "Yes"
                                    }else{
                                        $DBAaccess = "No"
                                    }

                                    # Get the service account
                                    #SELECT @@SERVICENAME -- returns name for regread
                                    #DECLARE @ServiceaccountName varchar(250)  
                                    #EXECUTE master.dbo.xp_instance_regread  
                                    #N'HKEY_LOCAL_MACHINE', N'SYSTEM\CurrentControlSet\Services\MSSQLSERVER',  
                                    #N'ObjectName',@ServiceAccountName OUTPUT, N'no_output'  
                                    #SELECT @ServiceAccountName
                                                                                                                      
                                    $TableSQL.Rows.Add($SQLServerIP, $SQLServer, $SQLInstance, $SQLVersion,$OSVersion,$DBAaccess) | Out-Null                                 
                                }                                                  
                            
                            # Status user
                            write-host "[+] SUCCESS! - $SQLInstance ($SQLServerIP) - SQL Server $SQLVersion - Sysadmin: $DBAaccess"                                
                            
                            if($ShowTable){
                                $TableSQL | Format-Table -Autosize
                            }

                            # close connection                            
                            $connection.Close();
                        }
                        Catch
                        {
                            write-host "[-] Failed   - $SQLInstance ($SQLServerIP) is up, but authentication failed"
                        }

                    }else{
                        write-host "[-] Failed   - $SQLServer is not responding to pings"
                    }
                }

                #-------------------------
                # Display final results
                #-------------------------

                $EndTime = Get-Date
                $TotalTime = NEW-TIMESPAN –Start $Starttime –End $Endtime   
                $SQLServerLoginCount = $TableSQL.Rows.count
                if ($SQLServerLoginCount -gt 0) {                                        
                    Write-Host "[*] ----------------------------------------------------------------------"  
                    Write-Host "[+] $SQLServerLoginCount of $SQLServerCount SQL Server instances could be accessed."                             
                    Write-Host "[*] ----------------------------------------------------------------------" 
                    Write-Host "[*] End Time: $Endtime"
                    Write-Host "[*] ----------------------------------------------------------------------" 
                    Write-Host "[*] Total Time: $TotalTime" 
                    Write-Host "[*] ----------------------------------------------------------------------" 

                    # Display final results table
                    $TableSQL | format-table -AutoSize

                }else{
                    Write-Output "[-] No SQL Server instances could be accessed as $CurrentUser" 
                }                                 
            
        }else{

            # Display fail            
            Write-Output "[-] No SQL Servers were found in Active Directory."            
        }   
    }   
}



#Invoke-FindandQuerySQL -DomainController 192.168.1.100 -Credential demo\user #Supplied Domain Creds and SQL Creds
#Invoke-FindandQuerySQL -ShowTable yes
Invoke-FindandQuerySQL 
