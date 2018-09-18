# ---------------------------------
# Get-PublicAwsS3BucketList
# ---------------------------------
#  Author: Scott Sutherland (@_nullbind), NetSPI 2018
# Version: 0.1
# Description: This Function can be used to obtain a list of keys (files) stored in AWS 
# S3 buckets that have been make publically readable.
# Ref: https://docs.aws.amazon.com/AmazonS3/latest/API/v2-RESTBucketGET.html
# Ref: https://docs.aws.amazon.com/AmazonS3/latest/dev/using-with-s3-actions.html#using-with-s3-actions-related-to-buckets
<#

# Todo
# make file output an option
# add option to export to file xml/csv
# update help text - for both functions, and provide blog talking about configuration requirements
# ability to take list of s3 buckets from pipeline or files
# sites often use for images...so its worth searching for in body of sites that are in scope.. maybe taking contents of eye witness?
# switch to outputing psobject instead of data table, big sites may take too long..
# only focused on fully unauthenticated perspective...many of the other tools require creds...


#>
Function Get-PublicAwsS3BucketList  
{
    [CmdletBinding()]
    Param(

        [string]$S3BucketName,
        $S3FileList,
        [string]$LastKey
        )

    begin
    {       
    }

    process
    {
        # Create webclient
        $GetBucket = New-Object net.webclient

        # Ignore cert warning
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

        # Set the s3 url
        if($LastKey){            
            $TargetUrl = "https://$S3BucketName.s3.amazonaws.com/?max-keys=1000&list-type=2&start-after=$LastKey"            
        }else{
            $TargetUrl = "https://$S3BucketName.s3.amazonaws.com/?max-keys=1000&list-type=2"            
            Write-Verbose "Sending initial request to server..."
            Write-Verbose "Please note that enumerating large (>100,000 keys) S3 buckets can take up to 5 minutes..."
        }

        # Perform GET request for batch of 1000 records        
        try{
            [xml]$S3Bucket = $GetBucket.DownloadString($TargetUrl)
        }catch{
            $_.Exception.Message
            return
        }

        # Display bucket information
        $S3BucketInfo = $S3Bucket.ListBucketResult | Select-Object Name,StartAfter,IsTruncated,Keycount
        $BucketName = $S3BucketInfo.Name 
        $BucketStartAfter = $S3BucketInfo.StartAfter 
        $BucketTruncated = $S3BucketInfo.IsTruncated
        $BucketKeyCount = $S3BucketInfo.Keycount
        Write-Verbose "     Base URL:https://$S3BucketName.s3.amazonaws.com/?max-keys=1000&list-type=2&start-after="
        Write-Verbose "     Name: $BucketName"
        Write-Verbose "     StartAfter: $BucketStartAfter"
        Write-Verbose "     IsTruncated: $BucketTruncated"
        Write-Verbose "     KeyCount: $BucketKeyCount"

        # Get file list for current batch
        $S3FileList += $S3Bucket.ListBucketResult.Contents
 
        # Get key count so far
        $KeyCount = $S3FileList.Count

        # If information return is truncated continue to grab batches of 1000 records
        if ($S3BucketInfo.IsTruncated -eq $true){
            
            # Status user
            Write-Verbose "$KeyCount keys (files) found, requesting 1000 more..."

            # Update $LastKey variable
            $LastKey = $S3FileList | Select-Object key -Last 1 -ExpandProperty Key

            # Request more records
            Get-PublicAwsS3BucketList -S3BucketName $S3BucketName -LastKey $LastKey -S3FileList $S3FileList
        }else{
            
            # Return final count in verbose message 
            $FinalKeyCount = $S3FileList.Count
            Write-Verbose "$FinalKeyCount keys (files) were found."
            Write-Verbose "Generating output table..."

            # Flatten table structure                       
            $S3FileList |
            ForEach-Object{

                # Filter out files without extensions
                $CurrentKey = $_.key   
                $CurrentKeyReverse = ([regex]::Matches($CurrentKey,'.','RightToLeft') | ForEach {$_.value}) -join ''
                $CurrentKeyExtReverse = $CurrentKeyReverse.split('.')[0]
                $CurrentKeyExt = ([regex]::Matches($CurrentKeyExtReverse,'.','RightToLeft') | ForEach {$_.value}) -join ''                          

                # Return record
                New-Object PSObject -Property @{                     
                    URL="https://$S3BucketName.s3.amazonaws.com/$CurrentKey";
                    BucketName = $BucketName
                    Key=$_.key; 
                    FileType=$CurrentKeyExt.ToLower()
                    LastModified=$_.LastModified;
                    ETag=$_.ETag;
                    Size=$_.Size;
                    StorageClass=$_.StorageClass;
                }
            }
        }
    }

    end
    {
    }
}


# Command Examples
# Google dork: filetype:pdf .s3.amazonaws.com ; filetype: xls site:s3.amazonaws.com
# can be subdomain or https://s3.amazonaws.com/asn-cdn-remembers or https://asn-cdn-remembers.s3.amazonaws.com/
# add finding notes about required access for this to work; get a lot of 403, and the occational 404
# Examples: cmsdocs, asn-cdn-remembers, forthplatform(bigger)

# Get s3 bucket list
$Output = Get-PublicAwsS3BucketList -Verbose -S3BucketName "asn-cdn-remembers" 
$Output = Get-PublicAwsS3BucketList -Verbose -S3BucketName "forthplatform" 


# View S3 bucket list
$Output | select -First 1

<##
Size         : 82838
ETag         : "fc677f31206e306bfa753856a6528c9a"
LastModified : 2015-08-12T13:15:22.000Z
URL          : https://asn-cdn-remembers.s3.amazonaws.com/001241bd47b1c45e3ea37baf2fcbbb00.pdf
BucketName   : asn-cdn-remembers
StorageClass : STANDARD
Key          : 001241bd47b1c45e3ea37baf2fcbbb00.pdf
FileType     : pdf
##>


# Write s3 bucket list to xml file
Write-Verbose "Exporting results to filelist.xml..."
$Output | Export-Clixml filelist.xml

# Get the file types in s3 bucket list
Write-Verbose "Getting list of file type stored in S3 buckets..."
$Output | Where-Object FileType -NotLike "*/*" | Group-Object FileType | Select Name,Count | Sort-Object count -Descending

<##
PS C:\Users\ssutherland> $Output | Where-Object FileType -NotLike "*/*" | Group-Object FileType | Select Name,Count | Sort-Object count -Descending

Name                             Count
----                             -----
pdf                               2317
jpg                                408
doc                                 73
png                                 57
docx                                30
gif                                 13
mp3                                 11
bmp                                  6
zip                                  5
pptx                                 4
ics                                  3
htm                                  3
jpeg                                 3
ppt                                  3
wav                                  2
wmv                                  2
pdfundefined                         1
xlsx                                 1
xls                                  1
9e1407fc6dff786161a22426adfc9ebe     1  ....canary file?
mp4                                  1

##>

# Select list of file type
$Output | where filetype -like "ics"

<##

PS C:\> $Output | where filetype -like "ics"


Size         : 1966
ETag         : "d917b326fe876d405e7d267cf364a701"
LastModified : 2012-12-12T19:18:34.000Z
URL          : https://asn-cdn-remembers.s3.amazonaws.com/1bf65bfae42fe5a1fd5c1ffa6de32cda.ics
BucketName   : asn-cdn-remembers
StorageClass : STANDARD
Key          : 1bf65bfae42fe5a1fd5c1ffa6de32cda.ics
FileType     : ics

Size         : 1298
ETag         : "44e7833f0fb6fc432e3dc8e3b2373f5d"
LastModified : 2013-05-23T21:02:33.000Z
URL          : https://asn-cdn-remembers.s3.amazonaws.com/424f159dbe883c6f104d46e2a4ccd1d1.ics
BucketName   : asn-cdn-remembers
StorageClass : STANDARD
Key          : 424f159dbe883c6f104d46e2a4ccd1d1.ics
FileType     : ics

...
##>

Function Get-PublicAwsS3Config
{
    [CmdletBinding()]
    Param(

        [string]$S3BucketName
        )

# Create list of taret urls
$MyTargetUrls = New-Object System.Collections.ArrayList
$MyTargetUrls.Add("policy") | Out-Null
$MyTargetUrls.Add("requestPayment") | Out-Null
$MyTargetUrls.Add("tagging") | Out-Null
$MyTargetUrls.Add("versioning") | Out-Null
$MyTargetUrls.Add("website")  | Out-Null
$MyTargetUrls.Add("encryption") | Out-Null
$MyTargetUrls.Add("lifecycle") | Out-Null
$MyTargetUrls.Add("acl") | Out-Null

# Define output table
$TblOutput = New-Object System.Data.DataTable
$TblOutput.Columns.Add("Feature") | Out-Null
$TblOutput.Columns.Add("Accessible") | Out-Null
$TblOutput.Columns.Add("Details") | Out-Null


# Attempt to access each target url
$WebClient = New-Object net.webclient
$webclient.Headers.Add("Host:$S3BucketName.s3.amazonaws.com")
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
Write-Output "Checking access to $S3BucketName AWS S3 Resources..."
$MyTargetUrls | 
ForEach-Object{
    
    $Feature = $_

    Write-Verbose "Trying https://s3.amazonaws.com/$_"

    try{        
        $Record = $WebClient.DownloadString("https://s3.amazonaws.com/$_")        
        $TblOutput.Rows.Add($Feature,"Yes",$record) | Out-Null

    }catch{        
        $ErrorCode = $_.Exception.Message.split("(")[2].replace(")","").replace("`"","")
        $TblOutput.Rows.Add($Feature,"No",$ErrorCode) | Out-Null
    }
}

$TblOutput

}

# Check Access to management features
Get-PublicAwsS3Config -S3BucketName "forthplatform" -Verbose

# Get initial inventory
$results = (Get-PublicAwsS3Config -S3BucketName "rcms3-production"  | Where-Object accessible -Like "Yes" | Select details )
[xml]$Inventory = $results.Details
$Inventory.ListBucketResult.Contents 
