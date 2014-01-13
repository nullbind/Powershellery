# Author: Scott Sutherland 2013, NetSPI
# Version: Get-Webconfig v.-37

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

        $TheSite = $_

        # Fix default site path 
        if ($_ -like "*%SystemDrive%*")
        {
            $TheDriveVar = $env:SystemDrive
            $TheSite  = $_.replace("%SystemDrive%",$TheDriveVar)
        }

        # Set site  clear
        $CurrentSite = $TheSite

        # Search for web.config files in each virtual directory
        $TheSite | Get-ChildItem -Recurse -Filter web.config | 
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
                    $ConfVdir = $CurrentSite
                    $ConfPath = $CurrentPath
                    $ConfEnc = "No"
                    $DataTable.Rows.Add($ConfUser, $ConfPass, $ConfServ,$ConfVdir,$CurrentPath, $ConfEnc) | Out-Null                    
                }  

            }else{

                # Check if appcmd.exe exists
                if (Test-Path  ("c:\Windows\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe"))
                {

                    # Remove existing temp web.config
                    if (Test-Path  ("c:\TEMP\web.config")) 
                    { 
                        Del C:\TEMP\web.config 
                    }
                    
                    # Copy web.config for decryption
                    Copy $CurrentPath C:\TEMP\web.config

                    #Decrypt web.config                    
                    C:\Windows\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe -pdf "connectionStrings" "C:\TEMP" | Out-Null

                    # Read the data from the web.config xml file
                    [xml]$TMPConfigFile = Get-Content C:\TEMP\web.config

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
                            $ConfVdir = $CurrentSite
                            $ConfPath = $CurrentPath
                            $ConfEnc = "Yes"
                            $DataTable.Rows.Add($ConfUser, $ConfPass, $ConfServ,$ConfVdir,$CurrentPath, $ConfEnc) | Out-Null                    
                        }  

                    }else{
                        Write-Host "Decryption of $CurrentPath failed."                        
                    }
                }else{
                    Write-Host "aspnet_regiis.exe does not exist in the default location."
                }
            }           
        }
    }

    # Check if any connection strings were found 
    if( $DataTable.rows.Count -gt 0 )
    {

        # Display results in list view that can feed into the pipeline    
        $DataTable |  Sort-Object user,pass,dbserv,vdir,path,encr | select user,pass,dbserv,vdir,path,encr -Unique | Format-Table -AutoSize
    }else{

        # Status user
        Write-Host "No connectionStrings found."
    }     
}else{
    Write-Host "Appcmd.exe does not exist in the default location."
}

# Bugs / Todo
# ---------------
# needs a little qa
# Sample output
# PS C:\> C:\Powershellery\Brainstorming\get-webconfig.ps1
#
# user    pass       dbserv                vdir               path                          encr
# ----    ----       ------                ----               ----                          ----
# s1admin s1password 192.168.1.103\server1 C:\test2           C:\test2\web.config           No  
# s1user  s1password 192.168.1.103\server1 C:\inetpub\wwwroot C:\inetpub\wwwroot\web.config No  
# s2user  s2password 192.168.1.103\server2 C:\App1            C:\App1\test\web.config       No  
# s2user  s2password 192.168.1.103\server2 C:\App1            C:\App1\web.config            Yes 
# s3user  s3password 192.168.1.103\server3 C:\wamp\www        C:\wamp\www\web.config        No  

# Quick and dirty method and doesn't do any decryption 
# for /f "tokens=*" %i in ('%systemroot%\system32\inetsrv\appcmd.exe list sites /text:name') do %systemroot%\system32\inetsrv\appcmd.exe list config "%i" -section:connectionstrings