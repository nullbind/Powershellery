# Function: Get-LocalSqlSvcs
function Get-SqlSvcs{
    
    Write-Host "Getting list of SQL Server Instances..."

    $TableInstances = New-Object System.Data.DataTable 
    $TableInstances.Columns.Add('Hostname') | Out-Null
    $TableInstances.Columns.Add('Instance') | Out-Null
    $TableInstances.Columns.Add('Version') | Out-Null
    $TableInstances.Columns.Add('Service') | Out-Null

    Get-WmiObject -Class win32_service | 
    where {$_.pathname -like "*sqlservr.exe*"} | 
    ForEach-Object {        
        $ServiceInstance = $_.displayname.split('(')[1].split(')')[0]
        $ServiceAccount = $_.startName                 
        $srv = new-object ('Microsoft.SqlServer.Management.Smo.Server')
        $ServiceVersion = $srv.PingSqlServerVersion("$env:COMPUTERNAME\$ServiceInstance") | Select-Object Major -ExpandProperty Major        
        $TableInstances.Rows.Add($env:COMPUTERNAME,$ServiceInstance,$ServiceVersion,$ServiceAccount) | Out-Null              
    }

    $TableInstances   
 }

Get-LocalSqlSvcs
