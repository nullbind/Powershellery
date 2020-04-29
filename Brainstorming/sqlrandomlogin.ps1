Generate fails login attempts:

1. Import PowerUpSQL

IEX(New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/NetSPI/PowerUpSQL/master/PowerUpSQL.ps1")

2. Set target SQL Server instance
$instancename = "server\instance"

3. Generate random user name
$user = (-join ((65..90) + (97..122) | Get-Random -Count 15 | % {[char]$_}))

4. Loop 10 times and attempt to login with random user name and password.

1..10 | foreach {
Write-Output "Username: $user Password: $password"
$password = (-join ((65..90) + (97..122) | Get-Random -Count 15 | % {[char]$_}))
Get-SQLQuery -Verbose -Username "$user" -Password "$password" -Query "select @@version" -Instance "$instancename" -ReturnError
} 
