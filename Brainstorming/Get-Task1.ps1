$schedule = new-object -com("Schedule.Service") 
$schedule.connect() 
$tasks = $schedule.getfolder("\").gettasks(0)
$entries = New-Object System.Collections.Generic.List[System.Management.Automation.PSObject]

$tasks | 
ForEach-Object {

    # Get task information
    $TaskEnabled = $_.enabled
    $TaskState = $_.state
    $TaskName = $_.name
    $TaskPath = $_.path
    [xml]$TaskXML = $_.xml
    $TaskComputer = $env:USERDNSDOMAIN
    $TaskAuthor = $TaskXML.task.RegistrationInfo.Author
    $TaskUserContext = $TaskXML.task.Actions.context
    [string]$TaskTrigger = $TaskXML.$stuff.task.Triggers
    $TaskCommand = $TaskXML.Task.Actions.exec.Command    
    $TaskCommandArgs = $TaskXML.Task.Actions.exec.Arguments   
    
    # Create ps object
    
    $object = New-Object psobject -Property @{
        TaskEnabled = $_.enabled
        TaskState = $_.state
        TaskName = $_.name
        TaskPath = $_.path
        TaskXML = [xml]$_.xml
        TaskComputer = $env:COMPUTERNAME
        TaskAuthor = $TaskXML.task.RegistrationInfo.Author
        TaskUserContext = $TaskXML.task.Actions.context
        TaskTrigger = [string]$TaskXML.$stuff.task.Triggers
        TaskCommand = $TaskXML.Task.Actions.exec.Command    
        TaskCommandArgs = $TaskXML.Task.Actions.exec.Arguments  
    }
    $entries.add($object)

        
     
}
$entries
