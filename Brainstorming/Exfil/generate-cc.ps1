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
            $script:AllCC | Out-File .\CCs.txt -Append
}

# Generate 1 MB of CCs di
Generate-CreditCards -Number 1 
