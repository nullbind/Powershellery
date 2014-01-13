# Author: Scott Sutherland 2013, NetSPI
# Version: Get-Webconfig v1.0

# Check if appcmd.exe exists
if (Test-Path  ("c:\windows\system32\inetsrv\appcmd.exe"))
{
    # Create data table to house results
    $DataTable = New-Object System.Data.DataTable 

    # Create and name columns in the data table
    $DataTable.Columns.Add("user") | Out-Null
    $DataTable.Columns.Add("pass") | Out-Null  
    $DataTable.Columns.Add("serv") | Out-Null
    $DataTable.Columns.Add("vdir") | Out-Null
    $DataTable.Columns.Add("path") | Out-Null
    $DataTable.Columns.Add("encr") | Out-Null

    # Get list of virtual directories in IIS 
    c:\windows\system32\inetsrv\appcmd.exe list vdir /text:physicalpath | 
    foreach { 
                        
        # Set site  
        $CurrentSite = $_

        # Search for web.config files in each virtual directory
        "$_" | Get-ChildItem -Recurse -Filter web.config | 
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

                Write-Host "Found connectionStrings encrypted!"
            }           
        }
    }

    # Check if any connection strings were found 
    if( $DataTable.rows.Count -gt 0 )
    {

        # Display results in list view that can feed into the pipeline    
        $DataTable |  Sort-Object User,Pass,Serv,Vdir,Path,Encr | select User,Pass,Serv,Vdir,Path,Encr -Unique | Format-Table -AutoSize
    }else{

        # Status user
        Write-Host "No connectionStrings found."
    }     
}else{
    Write-Host "Appcmd.exe does not exist in the default location."
}

 

# http://blogs.msdn.com/b/kalleb/archive/2008/07/19/using-powershell-to-read-xml-files.aspx