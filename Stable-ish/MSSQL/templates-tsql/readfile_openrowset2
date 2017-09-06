-- Note: Requires the driver to be installed ahead of time.
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'AllowInProcess', 1 
EXEC sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0', N'DynamicParameters', 1
EXEC master..xp_regwrite 'HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\Jet\4.0\Engines','SandBoxMode','REG_DWORD',1;
SELECT * FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0','Text;Database=c:\temp\;HDR=Yes;FORMAT=text', 'SELECT * FROM [file.txt]')
