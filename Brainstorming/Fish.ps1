# Generates 10 fish for fun 
1..10 | 
ForEach-Object{       

    # Set random number of spaces
    $Spaces = " "* (Get-Random -Maximum 50)
    
    # Bubbles object 1
    $Bubbles1 = "       
    $Spaces       o
    $Spaces      o" 
    
    # Bubbles object 2
    $Bubbles2 = "       
    $Spaces         o"             

    # Fish 1 object
    $Fish1 = "       
    $Spaces     <o)))><"  
    
    # Fish 2 object
    $Fish2 = "       
    $Spaces     ><(((o>" 
    
    # Choose random bubbles
    $myBubbles = New-Object System.Collections.ArrayList
    $myBubbles.Add("$Bubbles1") | Out-Null
    $myBubbles.Add("$Bubbles2") | Out-Null
    $RandomBubbles = Get-Random -Maximum 3
    $DisplayBubbles = $myBubbles[$RandomBubbles]

    # Choose random fish
    $myFish = New-Object System.Collections.ArrayList
    $myFish.Add("$Fish1") | Out-Null
    $myFish.Add("$Fish2") | Out-Null
    $RandomFish = Get-Random -Maximum 3
    $DisplayFish = $myFish[$RandomFish]

    Write-Output "$DisplayBubbles"
    Write-Output "$DisplayFish"

    # Delay the print
    sleep 1
}
