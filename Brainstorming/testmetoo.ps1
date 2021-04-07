$i = New-Object -COMObject InternetExplorer.Application -Property @{Navigate2="www.google.com"; Visible = $False}; Start-Sleep 5;Write-Host $i.Document.Body.InnerHTML
