# Author: scott sutherland
# This script uses tshark to parse the src.ip, dst.ip, and dst.port from a provided .cap file. It then looks up owner information.
# Todo: add ports grouping, add src/port filters, add threading (its super slow).

Function Get-IpInfoFromCap{

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True, ValueFromPipeline = $true, HelpMessage="Cap file path.")]
        [string]$capPath,
        [string]$OutputPath,
        [string]$SrcIp,
        [string]$DstIp,
        [int]$Port,
        [string]$TsharkPath 
    )
       
    Begin
    {
        # Set tshark path
        if( -not $TsharkPath){           
            $TsharkPath = 'C:\Program Files\Wireshark\tshark.exe'
        }

        # Verify tshark path
        $CheckTshark = Test-Path $TsharkPath 
        If ($CheckTshark -eq $True) {
            Write-Verbose "The tshark path is valid: $TsharkPath"
        }else{
            Write-Host "The tshark path is invalid: $TsharkPath"
            return
        }

        # Set output path
        if( -not $OutputPath){           
            $OutputPath = 'c:\temp\'
        }

        # Verify output path
        $OutputFileTest = $OutputPath + 'file.txt'
        Try{ 
            [io.file]::OpenWrite($OutputFileTest).close() 
            Write-Verbose "Write access to the output directory: $OutputPath" 
        }Catch{ 
            Write-Host "No write access to the output: $OutputPath"
            return 
        }                

        # Create table to store input
        $ImportDataTbl = New-Object System.Data.DataTable
        $ImportDataTbl.Columns.Add("SrcIp") | Out-Null
        $ImportDataTbl.Columns.Add("DstIp") | Out-Null
        $ImportDataTbl.Columns.Add("Port") | Out-Null
     
        # Create table to store output
        $OutputTbl = new-object System.Data.DataTable
        $OutputTbl.Columns.Add("IpDest") | Out-Null
        $OutputTbl.Columns.Add("IpSrc") | Out-Null
        $OutputTbl.Columns.Add("Owner") | Out-Null
        $OutputTbl.Columns.Add("StartRange") | Out-Null
        $OutputTbl.Columns.Add("EndRange") | Out-Null
        $OutputTbl.Columns.Add("Country") | Out-Null
        $OutputTbl.Columns.Add("City") | Out-Null
        $OutputTbl.Columns.Add("Zip") | Out-Null
        $OutputTbl.Columns.Add("ISP") | Out-Null
        # $OutputTbl.Columns.Add("Ports") | Out-Null             
    }

    Process
    {
        # Set cap file path
        if( -not $capPath){           
            Write-Host "No cap file provided."
            return
        }

        # Verify cap path
        $Checkcap = Test-Path $capPath 
        If ($Checkcap -eq $True) {
            Write-Verbose "The cap path is valid: $capPath"
        }else{
            Write-Host "The cap path is invalid: $capPath"
            return
        }                                  
            
        # Set DstIp filter
        if(-not $DstIp){           
            $DstIpFilter = ""
        }else{
            $DstIpFilter = " -Y ip.dst==$DstIp "
        }

        # Create tshark command  
        $TsharkTemp = ""
        $set = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
        $TsharkTemp += -join ($set | Get-Random -Count 10)
        $TsharkCmd = 'c:\windows\system32\cmd.exe /c "' + $TsharkPath + '" -r c:\temp\packetcapture.cap -T fields -e ip.src -e ip.dst -e tcp.dstport ' + $DstIpFilter + ' -E header=y -E separator=`, -E occurrence=f  > ' + $TsharkTemp + '.csv' 

        # Execute tshark command (parse cap)
        Write-Verbose "Parsing cap file to temp file: $OutputPath$TsharkTemp.csv"
        $TsharkCmdOutput = invoke-expression $TsharkCmd 
        
        # Import data tshark parsed
        $CapDataFile = "$OutputPath$TsharkTemp.csv"
        $CapData = Import-Csv $CapDataFile 
        $RemoveTsharkTemp = "del $CapDataFile"
        Invoke-Expression $RemoveTsharkTemp

        # Import all parsed data (SrcIp, DstIp, Port) into $ImportDataTbl
        $capDataIpOnly = $CapData | select ip.src, ip.dst   

        # Consolidate port into temp table from $ImportDataTbl

        # Lookup source IP owner and location
        $capDataIpOnly | ForEach-Object {

            # Get source IP
            $IpAddress = $_.'ip.src'        
            $CurrentDest = $_.'ip.dst' 

            # Get ports for source IP

            # Send whois request to arin via restful api
            $web = new-object system.net.webclient
            [xml]$results = $web.DownloadString("http://whois.arin.net/rest/ip/$IpAddress")

            # Send location query to http://ip-api.com via xml api
            $web2 = new-object system.net.webclient
            [xml]$results2 = $web2.DownloadString("http://ip-api.com/xml/$IpAddress")

            # Parse data from responses    
            $IpOwner = $results.net.name 
            $IpStart = $results.net.startAddress
            $IpEnd = $results.net.endaddress  
            $IpCountry = $results2.query.country.'#cdata-section'
            $IpCity = $results2.query.city.'#cdata-section'
            $IpZip = $results2.query.zip.'#cdata-section'
            $IpISP = $results2.query.isp.'#cdata-section'
            # $IpPorts = $IpPorts

            # Put results in the data table   
            $OutputTbl.Rows.Add("$CurrentDest",
                              "$IpAddress",
                              "$IpOwner",
                              "$IpStart",
                              "$IpEnd",
                              "$IpCountry",
                              "$IpCity",
                              "$IpZip",
                              "$IpISP") | Out-Null

            # status the user
            Write-Verbose "Dest:$CurrentDest Src:$IpAddress Owner: $IpOwner ($IpCountry) ($IpStart -$IpEnd)"
    
        }

    }

    End
    {
        # Return the full result set
        $OutputTbl | Sort-Object Owner -Unique
    }
}

# Example command
Get-IpInfoFromCap -capPath "c:\temp\packetcapture.cap" -Verbose -DstIp [IP] | Out-GridView




