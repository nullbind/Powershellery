Function Get-BingoNumbers
{
    # Create array for tracking called numbers
    $CalledNumbers = New-Object System.Collections.ArrayList
    $CalledCount = 0

    # Generate called numbers
    while($CalledCount -ne 75){

        # Generate random number
        $RandomNumber = Get-Random -Maximum 76 -Minimum 1

        # Check if random number has already been called
        if (($CalledNumbers.Contains($RandomNumber)) -like "False"){

            # Display called number if new        
            if($RandomNumber -gt 0 -and $RandomNumber -le 14) {"B$RandomNumber"}
            if($RandomNumber -gt 14 -and $RandomNumber -le 29) {"I$RandomNumber"}
            if($RandomNumber -gt 29 -and $RandomNumber -le 44) {"N$RandomNumber"}
            if($RandomNumber -gt 44 -and $RandomNumber -le 59) {"G$RandomNumber"}
            if($RandomNumber -gt 59 -and $RandomNumber -le 75) {"O$RandomNumber"}
                
            # Add called number to list if new
            $CalledNumbers.Add($RandomNumber) | Out-Null

            # Update count of numbers called
            $CalledCount = $CalledNumbers.Count                

        }
    }
}

# Call numbers
Get-BingoNumbers
