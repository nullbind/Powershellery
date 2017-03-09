# Based on https://github.com/ChrisTruncer/Egress-Assess
function Generate-SSN
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,
        HelpMessage="Number of ssn to generate.")]
        $Number = 1
    )
        $script:AllSSN = @()
        #determine the number of SSN based on 11 bytes per SSN 
        $num = [math]::Round(($Number * 1MB)/11)
        Write-Output "Generating $Number MB of Social Security Numbers ($num)..."
        $list = New-Object System.Collections.Generic.List[System.String]
        $percentcount = 0
        $quart = [math]::Round($num/4)
        for ($i = 0; $i -lt $num; $i++)
        {
            if ($i%$quart -eq 0)
            {
                $percent = $percentcount * 25
                Write-Output "$percent% Done! $i SSNs Generated"
                $percentcount += 1
                }
                $r = "$(Get-Random -minimum 100 -maximum 999)-$(Get-Random -minimum 10 -maximum 99)-$(Get-Random -minimum 1000 -maximum 9999)"
                $list.Add($r)
        }

        $script:AllSSN  = $list.ToArray()
        $script:AllSSN | Out-File .\SSNs.txt -Append
}

# Generate 1 MB of SSNs 
Generate-SSN -Number 1 
