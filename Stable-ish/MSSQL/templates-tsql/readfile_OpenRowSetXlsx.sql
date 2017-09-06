
-- Read text file from disk
SELECT column1 FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0', 'Excel 12.0;Database=C:\windows\temp\Book1.xlsx;', 'SELECT * FROM [Targets$]')

-- Read text file from unc path
SELECT column1 FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0', 'Excel 12.0;Database=\\server\folder\Book1.xlsx;', 'SELECT * FROM [Targets$]')
