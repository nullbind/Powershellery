$taskPath = "\*\"
$Tasks = Get-ScheduledTask -TaskPath $taskPath 
$Tasks |
ForEach-Object { 

    [pscustomobject]@{
     Name = $_.TaskName
     Path = $_.TaskPath
     #LastResult = $(($_ | Get-ScheduledTaskInfo).LastTaskResult)
     #NextRun = $(($_ | Get-ScheduledTaskInfo).NextRunTime)
     Status = $_.State
     Author = $_.Author
     UserId  = $_.principal.UserId
     Command = $_.Actions.execute
     Arguments = $_.Actions.Arguments }
} 
