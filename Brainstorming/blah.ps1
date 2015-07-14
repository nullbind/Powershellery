1..100 | ForEach-Object{

# Request 1
  $remoteFileLocation = "https://raw.githubusercontent.com/nullbind/Powershellery/master/Brainstorming/runme.ps1"  
  $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession    
  $cookie = New-Object System.Net.Cookie     
  $cookie.Name = "cookieName"
  $cookie.Value = "valueOfCookie"
  $cookie.Domain = "domain.for.cookie.com"
  $Request1_postParams = @{username='me';moredata='qwerty'}
  $session.Cookies.Add($cookie); 
  $Request1_Response = Invoke-WebRequest "$remoteFileLocation" -WebSession $session -TimeoutSec 900 -Method POST -Body $postParams 
  $Request1_Response.Content
  $Request1_Number = $Request1_Response.Content.split("'")[1] 
  [string]$Request1_Number 


# Request 2
  $remoteFileLocation2 = "https://raw.githubusercontent.com/nullbind/Powershellery/master/Brainstorming/runme.ps1"  
  $session2 = New-Object Microsoft.PowerShell.Commands.WebRequestSession    
  $cookie2 = New-Object System.Net.Cookie     
  $cookie2.Name = "cookieName"
  $cookie2.Value = "valueOfCookie"
  $cookie2.Domain = "domain.for.cookie.com"
  $Request2_postParams2 = @{username="$_";moredata="$Request1_Number"}
  $session2.Cookies.Add($cookie2); 
  $Request2_Response = Invoke-WebRequest "$remoteFileLocation2" -WebSession $session2 -TimeoutSec 900 -Method POST -Body $postParams2 
  $Request2_Response.Content
  $Request2_Number = $Request1_Response.Content.split("'")[1] 
  $Request2_Number2

  }
