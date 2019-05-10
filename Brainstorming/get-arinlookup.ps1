 # Get list of networks
 $MyIPs = gc C:\temp\networks.txt
     
 # IP info table
$TblIPInfo = new-object System.Data.DataTable
$TblIPInfo.Columns.Add("IpDest") | Out-Null
$TblIPInfo.Columns.Add("IpSrc") | Out-Null
$TblIPInfo.Columns.Add("Owner") | Out-Null
$TblIPInfo.Columns.Add("StartRange") | Out-Null
$TblIPInfo.Columns.Add("EndRange") | Out-Null
$TblIPInfo.Columns.Add("Country") | Out-Null
$TblIPInfo.Columns.Add("City") | Out-Null
$TblIPInfo.Columns.Add("Zip") | Out-Null
$TblIPInfo.Columns.Add("ISP") | Out-Null 

# Lookup source IP owner 
$MyIPs | ForEach-Object {

    # Get source IP
    $IpAddress = $_ -split(" ")    

    # Send whois request to arin via restful api
    $targetip = $IpAddress[0]

    # arin lookup
    $web = new-object system.net.webclient
    [xml]$results = $web.DownloadString("http://whois.arin.net/rest/ip/$targetip")

    # Send location query to http://ip-api.com via xml api
    if ($IpAddress){
        $web2 = new-object system.net.webclient
        [xml]$results2 = $web2.DownloadString("http://ip-api.com/xml/$targetip")
    }

    # Parse data from responses    
    $IpOwner = $results.net.name 
    $IpStart = $results.net.startAddress
    $IpEnd = $results.net.endaddress  
    $IpCountry = $results2.query.country.'#cdata-section'
    $IpCity = $results2.query.city.'#cdata-section'
    $IpZip = $results2.query.zip.'#cdata-section'
    $IpISP = $results2.query.isp.'#cdata-section'

    # Put results in the data table   
    $TblIPInfo.Rows.Add("$CurrentDest",
      "$IpAddress",
      "$IpOwner",
      "$IpStart",
      "$IpEnd",
      "$IpCountry",
      "$IpCity",
      "$IpZip",
      "$IpISP") | Out-Null

    # status the user
    Write-Output "Dest:$CurrentDest Src:$IpAddress Owner: $IpOwner ($IpCountry) ($IpStart -$IpEnd)"
    
}

# Display results
$TblIPInfo | Out-GridView
