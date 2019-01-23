# ---------------------------------
# Get-PublicAwsS3BucketList
# ---------------------------------
#  Author: Scott Sutherland (@_nullbind), NetSPI 2018
# Version: 0.6
# Description: This Function can be used to obtain a list of keys (files) stored in AWS s3 buckets.
# it also supports feed guessing s3 buckets based on a list of domains which is can perform permutations on.
# S3 buckets that have been make publically readable.
# Ref: https://docs.aws.amazon.com/AmazonS3/latest/API/v2-RESTBucketGET.html
# Ref: https://docs.aws.amazon.com/AmazonS3/latest/dev/using-with-s3-actions.html#using-with-s3-actions-related-to-buckets
<#

# Todo
# make file output an option
# add option to export to file xml/csv
# update help text - for both functions, and provide blog talking about configuration requirements
# ability to take list of s3 buckets from pipeline or files
# search for keywords and regex in file name and file contents
# switch to outputing psobject instead of data table, big sites may take too long..
# only focused on fully unauthenticated perspective...many of the other tools require creds...
# region support and look for user enumeration based on api options
# consider adding tie ins to services like cert stream and buckhacker
# consider noting s3 bucket enumeration for burp/eyewitness etc
# determine if account is associated with federatation
# consider adding threading
# add file download option
# note that access denied means it exists, but listings are not possible from an unauthenticated perspective, 
#  - however, other attacks may be possible so there should be a list only option. non there, access denied, list, list/write etc

#>
Function Get-PublicAwsS3BucketList  
{
    [CmdletBinding()]
    Param(

        [string]$S3BucketName,
        $S3FileList,
        [string]$LastKey,
        [switch]$SuppressVerbose
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
            
            if(-not $SuppressVerbose){       
                Write-Verbose "Sending initial request to server..."
                Write-Verbose "Please note that enumerating large (>100,000 keys) S3 buckets can take up to 5 minutes..."
            }
        }

        # Perform GET request for batch of 1000 records        
        try{
            [xml]$S3Bucket = $GetBucket.DownloadString($TargetUrl)            
        }catch{
            
            
                #$_.Exception.Message
                $ErrorCode = $_.Exception.Message.split("(")[2].replace(")","").replace("`"","")
                write-verbose "$ErrorCode - $TargetUrl"

                # Return record
                if ($ErrorCode -like "*403*"){
                    New-Object PSObject -Property @{                     
                        URL="$TargetUrl";
                        BucketName = "$S3BucketName"
                        Key="NA"; 
                        FileType="NA"
                        LastModified="NA";
                        ETag="NA";
                        Size="NA";
                        StorageClass="NA"
                        Comment="Access Forbidden"
                    }
                }
                return
            
        }        

        # Display bucket information
        $S3BucketInfo = $S3Bucket.ListBucketResult | Select-Object Name,StartAfter,IsTruncated,Keycount
        $BucketName = $S3BucketInfo.Name 
        $BucketStartAfter = $S3BucketInfo.StartAfter 
        $BucketTruncated = $S3BucketInfo.IsTruncated
        $BucketKeyCount = $S3BucketInfo.Keycount

        if(-not $SuppressVerbose){  
            Write-Verbose "     Base URL:https://$S3BucketName.s3.amazonaws.com/?max-keys=1000&list-type=2&start-after="
            Write-Verbose "     Name: $BucketName"
            Write-Verbose "     StartAfter: $BucketStartAfter"
            Write-Verbose "     IsTruncated: $BucketTruncated"
            Write-Verbose "     KeyCount: $BucketKeyCount"
        }

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
            Write-Verbose "$FinalKeyCount keys (files) were found. - https://$S3BucketName.s3.amazonaws.com/?max-keys=1000&list-type=2"
            if(-not $SuppressVerbose){                 
                Write-Verbose "$S3BucketName - Generating output table..."
            }

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
                    Comment="List Permission Granted to Everyone";
                }
            }
        }
    }

    end
    {
    }
}

#


# Command Examples
# Google dork: filetype:pdf .s3.amazonaws.com ; filetype: xls site:s3.amazonaws.com
# can be subdomain or https://s3.amazonaws.com/thethingfromthatplace or https://thethingfromthatplace.s3.amazonaws.com/
# add finding notes about required access for this to work; get a lot of 403, and the occational 404

# Get s3 bucket list
# $Output = Get-PublicAwsS3BucketList -Verbose -S3BucketName "thethingfromthatplace" 

# View S3 bucket list
# $Output | select -First 1


<##
Size         : 82838
ETag         : "fc677f31206e306bfa753856a6528c9a"
LastModified : 2015-08-12T13:15:22.000Z
URL          : https://thethingfromthatplace.s3.amazonaws.com/001241bd47b1c45e3ea37baf2fccbb00.pdf
BucketName   : thethingfromthatplace
StorageClass : STANDARD
Key          : 001241bd47b1c45e3ea37baf2fccbb00.pdf
FileType     : pdf
##>


Function Get-PublicAwsS3BucketListFromDomains
{
    [CmdletBinding()]
    Param(

        [Parameter(Mandatory = $false, 
        HelpMessage = 'Provide a file containing domain names or desired S3 bucket names.')]
        [string]$BucketList,

        [Parameter(Mandatory = $false, 
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Provide the base S3Bucket name.')]
        [string]$S3Bucket,

        [Parameter(Mandatory = $false, 
        HelpMessage = 'Perform enumeration using basic permutations.')]
        [switch]$Permutate
    )

    <#
    Get-PublicAwsS3BucketListFromDomains -Verbose -FilePath C:\temp\list.txt    
    Get-PublicAwsS3BucketListFromDomains -Verbose -FilePath C:\temp\list.txt -S3Bucket "testing"
    "test.com","testing.com" | Get-PublicAwsS3BucketListFromDomains -Verbose 
    GC Domains.txt | Get-PublicAwsS3BucketListFromDomains -Verbose 
    GC Domains.txt | Get-PublicAwsS3BucketListFromDomains -Verbose -FilePath C:\temp\list.txt
    $Results = Get-PublicAwsS3BucketListFromDomains -Verbose -FilePath C:\temp\list.txt   
    $Results
    #>

    begin{

            # Create a list of words to be used for permutations
            $Permutations = New-Object System.Collections.ArrayList               
            [void]$Permutations.Add("www")
            [void]$Permutations.Add("web")
            [void]$Permutations.Add("backup")
            [void]$Permutations.Add("logs")             
            [void]$Permutations.Add("dev")
            [void]$Permutations.Add("qa")
            [void]$Permutations.Add("uat")
            [void]$Permutations.Add("staging")
            [void]$Permutations.Add("prod")
            [void]$Permutations.Add("api")            
            [void]$Permutations.Add("test")
            [void]$Permutations.Add("test123")
            [void]$Permutations.Add("images")
            [void]$Permutations.Add("data")            
            [void]$Permutations.Add("public")            
            [void]$Permutations.Add("private")    
            [void]$Permutations.Add("internal")            
            [void]$Permutations.Add("secret")            
            [void]$Permutations.Add("files")   
            [void]$Permutations.Add("tmp")                      
            [void]$Permutations.Add("temp")   
            [void]$Permutations.Add("key") 
            [void]$Permutations.Add("keys")               
            [void]$Permutations.Add("site")   
            [void]$Permutations.Add("test123")            
            [void]$Permutations.Add("test123")
            [void]$Permutations.Add("123")
            [void]$Permutations.Add("12")
            [void]$Permutations.Add("asdf")

            # Create list to conduct permutations against
            $List_PrePerm = New-Object System.Collections.ArrayList

            # Create list for storing S3 buckets to test
            $List_PostPerm = New-Object System.Collections.ArrayList

            # Load the file contents into preperm
            if($BucketList){
                
                # Check if file exists                    
                if(Test-Path $BucketList){                                   

                Write-Verbose "Importing domains from $BucketList."

                # Load contents of file
                GC $BucketList | 
                ForEach-Object{

                    # Get domain
                    $Domain = $_

                    # Remove domain extenstion
                    $DomainNoExt = $Domain.Replace("mail.", "").Replace("www.", "").split('.')[0] 

                    # Add to preperm list
                    $List_PrePerm.Add("$DomainNoExt") | Out-Null

                    # Standalone word
                    $List_PostPerm.Add("$DomainNoExt")| Out-Null
                }
            
                }else{
                    Write-Verbose "Importing domains from $BucketList Failed. File does not exist."
                }
            }
            Write-Verbose "Importing domains from pipeline and provided parameters."
    }

    process{

        # Process domain names provided as a parameter or pipeline item
        if($S3Bucket){
            $CleanBucket = $S3Bucket.Replace("mail.", "").Replace("www.", "").split('.')[0] 
            $List_PrePerm.Add("$CleanBucket") | Out-Null
            
            # Standalone word
            $List_PostPerm.Add("$CleanBucket")| Out-Null
        }            
    }

    end{

        # Get count of List_PrePerm
        $ListPrePerm_Count = $List_PrePerm.count

        if($ListPrePerm_Count -eq 0){
            Write-Verbose "No files or S3 bucket names were provided for processing."
            return
        }

        if($Permutate){

            # Generate permutations
            Write-Verbose "$ListPrePerm_Count domains provided."
        
            # Create permutations for each domain
            $List_PrePerm |
            ForEach-Object{

                $S3Name = $_

                # Create permutation for s3 bucket
                $Permutations |
                ForEach-Object{ 
                
                    # Concat to front                              
                    $List_PostPerm.Add("$_$S3Name")| Out-Null

                    # Add to front with dash
                    $List_PostPerm.Add("$_-$S3Name")| Out-Null

                    # Add to back with dash
                    $List_PostPerm.Add("$S3Name-$_") | Out-Null
                }                        
            }
        }

        # Perform requests if there is anything to process
        if($List_PostPerm){

            # Check if each permutation exists as s3 bucket
            $S3CheckCount = $List_PostPerm.count
            $MyCount = 0
            Write-Verbose "$S3CheckCount permutations (S3 buckets) will be checked."
            $List_PostPerm | Get-Unique |
            ForEach-Object {
                $MyCount = $MyCount + 1
                Write-Verbose "Testing $MyCount of $S3CheckCount "
                Get-PublicAwsS3BucketList -S3BucketName $_ -SuppressVerbose           
            }
        }
    }
}

Function Get-PublicAwsS3BucketListFromS3List
{
    [CmdletBinding()]
    Param(

        [string]$FilePath
        )
}

<#
# Write s3 bucket list to xml file - add function for export
Write-Verbose "Exporting results to filelist.xml..."
$Output | Export-Clixml filelist.xml

# Get the file types in s3 bucket list - add function for summary data
Write-Verbose "Getting list of file type stored in S3 buckets..."
$Output | Where-Object FileType -NotLike "*/*" | Group-Object FileType | Select Name,Count | Sort-Object count -Descending
#>

<##
PS C:\> $Output | Where-Object FileType -NotLike "*/*" | Group-Object FileType | Select Name,Count | Sort-Object count -Descending

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
9e1407fc6dff786161a22426adfc9ebe     1  ....canary file or just randomly gen name?
mp4                                  1

##>

# Select list of file type
# $Output | where filetype -like "ics"

<##

PS C:\> $Output | where filetype -like "ics"


Size         : 1966
ETag         : "d917b326fe876d405e7d267cf364a701"
LastModified : 2012-12-12T19:18:34.000Z
URL          : https://thethingfromthatplace.s3.amazonaws.com/1bf65bfae42fe5a1fd5c1afa6de32cda.ics
BucketName   : thethingfromthatplace
StorageClass : STANDARD
Key          : 1bf65bfae42fe5a1fd5c1ffa6de32ada.ics
FileType     : ics

Size         : 1298
ETag         : "44e7833f0fb6fc432e3dc8e3b2373f5d"
LastModified : 2013-05-23T21:02:33.000Z
URL          : https://thethingfromthatplace.s3.amazonaws.com/424f159dbe883c6f104d46e2a4cbd1d1.ics
BucketName   : thethingfromthatplace
StorageClass : STANDARD
Key          : 424f159dbe883c6f104d46e2a4cbd1d1.ics
FileType     : ics

...
##>

Function Get-PublicAwsS3Config
{
    [CmdletBinding()]
    Param(

        [string]$S3BucketName
        )

    <#
    # Check Access to management features
    Get-PublicAwsS3Config -S3BucketName "thethingfromthatplace" -Verbose

    # Get initial inventory
    $results = (Get-PublicAwsS3Config -S3BucketName "thethingfromthatplace"  | Where-Object accessible -Like "Yes" | Select details )
    [xml]$Inventory = $results.Details
    $Inventory.ListBucketResult.Contents 
    #>

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
