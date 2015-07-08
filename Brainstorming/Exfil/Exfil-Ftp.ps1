# create the FtpWebRequest and configure it
$ftp = [System.Net.FtpWebRequest]::Create("ftp://10.1.1.1/data.txt")
$ftp = [System.Net.FtpWebRequest]$ftp
$ftp.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
$ftp.Credentials = new-object System.Net.NetworkCredential("anonymous","anonymous@localhost")
$ftp.UseBinary = $true
$ftp.UsePassive = $true
# read in the file to upload as a byte array
$content = [System.IO.File]::ReadAllBytes("data.txt")
$ftp.ContentLength = $content.Length
# get the request stream, and write the bytes into it
$rs = $ftp.GetRequestStream()
$rs.Write($content, 0, $content.Length)
# be sure to clean up after ourselves
$rs.Close()
$rs.Dispose()
