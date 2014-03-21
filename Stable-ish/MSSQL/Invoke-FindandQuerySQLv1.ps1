# Author: Scott Sutherland 2013, NetSPI
# Version: Invoke-FindandQuerySQL version .01
# Requirements: Powershell v.3

# todo
# ----
# add authentication as option (sql server, trusted connection, alternative Windows credentials)
# seperate custom and default info gather query
# write full info gather query
# update default output - add colors and remove query output...
# add custom query option
# finalize table option
# update help
# make pretty

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
	   Return a list of SQL Servers that have registered SPNs in LDAP on the current user's domain.
	   
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
        HelpMessage="View minimal information that includes the accounts,affected systems,and registered services.  Nice for getting quick list of DAs.")]
        [string]$List
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
        $TableSQL.Columns.Add("Server") | Out-Null
        $TableSQL.Columns.Add("Instance") | Out-Null
        $TableSQL.Columns.Add("Query") | Out-Null  
        $TableSQL.Columns.Add("User") | Out-Null 
        $TableSQL.Columns.Add("Sysadmin") | Out-Null 
        $TableSQL.Columns.Add("SvcAcct") | Out-Null 
        $TableSQL.Columns.Add("DBLinks") | Out-Null

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
        Write-Output "[ ] -----------------------------------------------------------"
        Write-Output "[ ] Sending LDAP query to $DomainController as $CurrentUser ..." 

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

            # Only display lines for detailed view
            If ($list){

                # This should be the table only view....by default...show the other view in verbose mode
                                                  
            }else{

                # Status user
                $SQLServerCount = $TableLDAP.Rows.Count
                Write-Output "[ ] -----------------------------------------------------------"
                Write-Output "[ ] $SQLServerCount SQL Server instances will be tested..."    
                Write-Output "[ ] -----------------------------------------------------------"

                # Display results in list view that can feed into the pipeline
                $TableLDAP |  Sort-Object server,instance| select server,instance -unique | foreach {
                
                    #------------------------
                    # Setup connection string
                    #------------------------

                    $SQLServer = $_.server
                    $SQLInstance = $_.instance
                    $conn = New-Object System.Data.SqlClient.SqlConnection

                    # Set authentication type
                    #$connection = New-Object-TypeName System.Data.OleDb.OleDbConnection  #ODBC              
                    #$conn.ConnectionString = "Server=$SQLServer;Database=master;User ID=superadmin;Password=superpassword;" #SQL Creds
                    $conn.ConnectionString = "Server=$SQLInstance;Database=master;Trusted_Connection=True;" #CurrentwinCreds aka TrustedConnection - uses typed in creds?

                    #-------------------------
                    # Test database conections
                    #-------------------------

                    # Check if the server is up via ping
                    if((Test-Connection -Cn $SQLServer -BufferSize 16 -Count 1 -ea 0 -quiet))               
                    {

                        Try
                        {
                            # Create connection to system and issue query 
                            $conn.Open()
                            $sql = "SELECT name from master..sysdatabases"
                            $cmd = New-Object System.Data.SqlClient.SqlCommand($sql,$conn)
                            #$cmd.CommandTimeout = 2
                            $rdr = $cmd.ExecuteReader()
                            $QueryOutput = @()
                            while($rdr.Read())
                            {
                                $QueryOutput += ($rdr["name"].ToString())
                            }

                            # Status user
                            Write-Output "[+] $SQLInstance is up - authentication successful"
                            Write-Output "    Query Data: $QueryOutput"

                            # Add record to list
                            $TableSQL.Rows.Add($SQLServer, $SQLInstance, $QueryOutput,'user','sysadmin','svcacct','dblinks') | Out-Null 
                        }
                        Catch
                        {
                            write-host "[-] $SQLInstance is up - authentication failed or bad query"
                        }

                    }else{
                        write-host "[-] $SQLInstance is down!"
                    }
                }

                # Status user
                $SQLServerLoginCount = $TableSQL.Rows.count
                Write-Output "[ ] -----------------------------------------------------------"   
                Write-Output "[+] $SQLServerLoginCount SQL Server instances could be accessed as $CurrentUser"    
                Write-Output "[ ] -----------------------------------------------------------"
            }
        }else{

            # Display fail
            Write-Output "[ ] -----------------------------------------------------------"
            Write-Output "[-] No SQL Servers were found in Active Directory."
            Write-Output "[ ] -----------------------------------------------------------"
        }        
    }
}

Invoke-FindandQuerySQL -DomainController 10.2.3.3 -Credential netspi\ssutherland 