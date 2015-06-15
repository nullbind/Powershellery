# This is based on 
# get a list of deligated rights
# http://blogs.technet.com/b/ashleymcglone/archive/2013/03/25/active-directory-ou-permissions-report-free-powershell-script-download.aspx

# Create data table for inventory of object typees
$TableTypes = New-Object System.Data.DataTable 
$TableTypes.Columns.Add('GuidNumber')| Out-Null
$TableTypes.Columns.Add('GuidName')| Out-Null
$TableTypes.Clear| Out-Null

# Get standard rights
Write-Host "Getting standard rights"
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID |
ForEach-Object {
    $TableTypes.Rows.Add([System.GUID]$_.schemaIDGUID,$_.name) | Out-Null
}

# Get extended rights
Write-Host "Getting extended rights"
Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID |
ForEach-Object {
   $TableTypes.Rows.Add([System.GUID]$_.rightsGUID,$_.name) | Out-Null
}

# Get objecttype name
$ObjectType = "bf967a7f-0de6-11d0-a285-00aa003049e2"
$ObjectTypeGuid = "'" + "$ObjectType" + "'"
$ObjectTypeGuidCount = $TableTypes.Select("guidnumber = $ObjectTypeGuid").Count
if ($ObjectTypeGuidCount -gt 0){
    [string]$ObjectTypeName = $TableTypes.Select("guidnumber=$ObjectTypeGuid") | select guidname -ExpandProperty guidname -First 1   
}else{
    [string]$ObjectTypeName = ""
}

$ObjectTypeName


