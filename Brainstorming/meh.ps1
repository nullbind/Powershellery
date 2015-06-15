# This is based on 
# get a list of deligated rights
# http://blogs.technet.com/b/ashleymcglone/archive/2013/03/25/active-directory-ou-permissions-report-free-powershell-script-download.aspx

# Create data table for inventory of object typees
$TableDacl = New-Object System.Data.DataTable 
$TableDacl.Columns.Add('GuidNumber')| Out-Null
$TableDacl.Columns.Add('GuidName')| Out-Null
$TableDacl.Clear| Out-Null

# Get standard rights
Write-Host "Indexing standard rights"
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID |
ForEach-Object {
    $TableDacl.Rows.Add([System.GUID]$_.schemaIDGUID,$_.name) | Out-Null
}

# Get extended rights
Write-Host "Indexing extended rights"
Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID |
ForEach-Object {
   # $TableDacl.Rows.Add([System.GUID]$_.rightsGUID,$_.name)
}

Write-Host "Display results"
$TableDacl | select guidnumber,guidname -Unique | Sort guidname
