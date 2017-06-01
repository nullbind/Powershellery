# Generates 5 fish
1..5| 
ForEach-Object{       

    # Set random number of spaces
    $Spaces = " "* (Get-Random -Maximum 80)
    
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

    # Fish 3 object
    $Fish3 = "        
    $Spaces       _____
    $Spaces     /       \
    $Spaces     | O .   |
    $Spaces     \ .     /  
    $Spaces      |     |
    $Spaces      ( O O )
    $Spaces      / / \ \__  
    $Spaces    )/ /|||\ \( 
    $Spaces  _(( /(( ))\ ))(("    
    
    # Fish 4 object
    $Fish4 = "        
    $Spaces      ^
    $Spaces    -----
    $Spaces  <--o-0-->
    $Spaces   -------  
    $Spaces    -----"        
    
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
    $myFish.Add("$Fish3") | Out-Null
    $myFish.Add("$Fish4") | Out-Null
    $RandomFish = Get-Random -Maximum 4
    $DisplayFish = $myFish[$RandomFish]

    Write-Output "$DisplayBubbles"
    Write-Output "$DisplayFish"

    # Delay the print
    sleep .75
}
