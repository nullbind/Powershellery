# Author: ktaranov
function Get-LuhnChecksum {
    <#
        .SYNOPSIS
            Calculate the Luhn checksum of a number.
        .DESCRIPTION
            The Luhn algorithm or Luhn formula, also known as the "modulus 10" or "mod 10" algorithm, 
            is a simple checksum formula used to validate a variety of identification numbers, such as 
            credit card numbers, IMEI numbers, National Provider Identifier numbers in the US, and 
            Canadian Social Insurance Numbers. It was created by IBM scientist Hans Peter Luhn.
        .EXAMPLE
            Get-LuhnChecksum -Number 1234567890123452
            Calculate the Luch checksum of the number. The result should be 60.
        .INPUTS
            System.UInt64
        .NOTES
            Author: Øyvind Kallstad
            Date: 19.02.2016
            Version: 1.0
            Dependencies: ConvertTo-Digits
        .LINKS
            https://en.wikipedia.org/wiki/Luhn_algorithm
            https://communary.wordpress.com/
            https://github.com/gravejester/Communary.ToolBox
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [uint64] $Number
    )

    $digitsArray = ConvertTo-Digits -Number $Number
    [array]::Reverse($digitsArray)

    $sum = 0
    $index = 0

    foreach ($digit in $digitsArray) {
        if (($index % 2) -eq 0) {
            $doubledDigit = $digit * 2
            if (-not($doubledDigit -eq 0)) {
                $doubleDigitArray = ConvertTo-Digits -Number $doubledDigit
                $sum += ($doubleDigitArray | Measure-Object -Sum | Select-Object -ExpandProperty Sum)
            }
        }
        else {
            $sum += $digit
        }
        $index++
    }
    Write-Output $sum
}

function New-LuhnChecksumDigit {
    <#
        .SYNOPSIS
            Calculate the Luhn checksum digit for a number.
        .DESCRIPTION
            This function uses the Luhn algorithm to calculate the
            Luhn checksum digit for a (partial) number.
        .EXAMPLE
            New-LuhnChecksumDigit -PartialNumber 123456789012345
            This will get the checksum digit for the number. The result should be 2.
        .INPUTS
            System.UInt64
        .NOTES
            Author: Øyvind Kallstad
            Date: 19.02.2016
            Version: 1.0
            Dependencies: Get-LuhnCheckSum
        .LINKS
            https://en.wikipedia.org/wiki/Luhn_algorithm
            https://communary.wordpress.com/
            https://github.com/gravejester/Communary.ToolBox
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [uint64] $PartialNumber
    )

    $checksum = Get-LuhnCheckSum -Number $PartialNumber
    Write-Output (($checksum * 9) % 10)
}

function Test-IsLuhnValid {
    <#
        .SYNOPSIS
            Valdidate a number based on the Luhn Algorithm.
        .DESCRIPTION
            This function uses the Luhn algorithm to validate a number that includes
            the Luhn checksum digit.
        .EXAMPLE
            Test-IsLuhnValid -Number 1234567890123452
            This will validate whether the number is valid according to the Luhn Algorithm.
        .INPUTS
            System.UInt64
        .OUTPUTS
            System.Boolean
        .NOTES
            Author: Øyvind Kallstad
            Date: 19.02.2016
            Version: 1.0
            Dependencies: Get-LuhnCheckSum, ConvertTo-Digits
        .LINKS
            https://en.wikipedia.org/wiki/Luhn_algorithm
            https://communary.wordpress.com/
            https://github.com/gravejester/Communary.ToolBox
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [uint64] $Number
    )

    $numberDigits = ConvertTo-Digits -Number $Number
    $checksumDigit = $numberDigits[-1]
    $numberWithoutChecksumDigit = $numberDigits[0..($numberDigits.Count - 2)] -join ''
    $checksum = Get-LuhnCheckSum -Number $numberWithoutChecksumDigit

    if ((($checksum + $checksumDigit) % 10) -eq 0) {
        Write-Output $true
    }
    else {
        Write-Output $false
    }
}

# Author: ktaranov
function ConvertTo-Digits
{
    <#
            .SYNOPSIS
            Convert an integer into an array of bytes of its individual digits.
            .DESCRIPTION
            Convert an integer into an array of bytes of its individual digits.
            .EXAMPLE
            ConvertTo-Digits 145
            .INPUTS
            System.UInt64
            .LINK
            https://communary.wordpress.com/
            https://github.com/gravejester/Communary.ToolBox
            .NOTES           
            Date: 09.05.2015
            Version: 1.0
    #>
    [OutputType([System.Byte[]])]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [uint64]$Number
    )
    $n = $Number
    $numberOfDigits = 1 + [convert]::ToUInt64([math]::Floor(([math]::Log10($n))))
    $digits = New-Object -TypeName Byte[] -ArgumentList $numberOfDigits
    for ($i = ($numberOfDigits - 1); $i -ge 0; $i--)
    {
        $digit = $n % 10
        $digits[$i] = $digit
        $n = [math]::Floor($n / 10)
    }
    Write-Output -InputObject $digits
}

# Based on https://github.com/ChrisTruncer/Egress-Assess
function Generate-CreditCards
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,
        HelpMessage="Number of cc to generate.")]
        $Number = 1
    )
            $script:AllCC = @()
            $stringBuilder = New-Object System.Text.StringBuilder
            $script:list = New-Object System.Collections.Generic.List[System.String]
            Write-Output "[*] Generating Credit Cards............."
            function New-Visa
            {
                #generate a single random visa number, format 4xxx-xxxx-xxxx-xxxx
                $r = "4$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)"
                $script:list.Add($r)
            }
            function New-MasterCard
            {
                # generate a single random mastercard number
                $r = "5$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)"
                $script:list.Add($r)
            }
            function New-Discover
            {
                # generate a single random discover number
                $r = "6011-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)-$(Get-Random -minimum 1000 -maximum 9999)"
                $script:list.Add($r)
            }
            function New-Amex
            {
                # generate a single random amex number
                $script:AllCC += "3$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 100000 -maximum 999999)-$(Get-Random -minimum 10000 -maximum 99999)"
                $r = "3$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 100000 -maximum 999999)-$(Get-Random -minimum 10000 -maximum 99999)"
                $script:list.Add($r)
            }
            $num = [math]::Round($Number * 1MB)/19
            $percentcount = 0
            $quart = [math]::Round($num/4)
            for ($i = 0; $i -lt $num; $i++)
            {
                if ($i%$quart -eq 0)
                {
                    $percent = $percentcount * 25
                    Write-Output "$percent% Done! $i CCs Generated"
                    $percentcount += 1
                }
                $r = Get-Random -Minimum 1 -Maximum 5
                switch ($r) # Use switch statement to
                {
                    1 { New-Visa }
                    2 { New-MasterCard }
                    3 { New-Discover }
                    4 { New-Amex }
                    default { New-Visa }
                }
            }
            $script:AllCC = $list.ToArray()

            Write-Output "Selecting Luhn Matches..."
            $script:AllCC | 
            foreach{
                
                $testthis = $_ -replace("-","")                
                if(Test-IsLuhnValid -Number $testthis){
                    $testthis
                }else{
                    #"INVALID $testthis"
                }
            } | Out-File .\CCs.txt -Append

            Write-Output "CCs write to CCs.txt."
}



# Generate 1 MB of CCs di
Generate-CreditCards -Number 1 

