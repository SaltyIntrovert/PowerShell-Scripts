function insertEmail{
    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter the recipient's email address.")]$userEmail,
        [Parameter(Mandatory=$False,HelpMessage="Enter the CC's email address.")]$cc,
        [Parameter(Mandatory=$True,HelpMessage="Enter the message.")]$message,
        [Parameter(HelpMessage="Enter type of email (Success, Error, Information).")]$type,
        [Parameter(HelpMessage="Enter the ticket number.")]$TicketNumber
    )
    
    $message += "</table>"
    $bcc = "eaa@sutterhealth.org"
    $sentDate = $(Get-Date -Format "MM/dd/yyyy")
    $subject = "Cherwell Request # $TicketNumber - $type"
    $userEmail = $userEmail
    $query = "INSERT INTO Terminations.dbo.emailData (recipientEmail,ccEmail,bccEmail,subject,messageEmail,sentDate,typeEmail) VALUES ('$userEmail','$CC','$bcc','$subject','$message','$sentDate','$type')"
    Invoke-Sqlcmd -Query $query -ServerInstance "(serverName)"
}

Function CheckGroupName([ref]$checkGroup, [ref]$noAdGroup){
  if($checkGroup.value.count -eq 1){
    $name = $checkGroup.Value             #pass group into holder variable
    $checkName = Get-ADUser -LDAPFilter "(sAMAccountName=$name)" #check if group is a valid group name in AD 
    If (!$checkName)                                             #if Not a valid Group then enter
    {
      $noAdGroup.value += ("$name")                                #Add Group name to not valid use name array 
      $checkGroup.value.remove($name)                              #Remove the group from the array of groups
    }#end if for not valid name 
  }#end "if" for one user 
  else{                                                            #if more than one group in array 
    for($i = 0; $i -lt $checkGroup.value.count;$i++){   
    $name = $checkGroup.value[$i]                                   #pass group name to holder variable  
    $checkName = Get-ADGroup -LDAPFilter "(SAMAccountName=$name)"   #check if group is in AD
      If (!$checkName)                                    #if group name not a valid AD group add to not valid group array 
      {
        $noAdGroup.value += ("$name   ")                    #Add group name to not valid group name array 
        $checkGroup.value.Remove("$name")                   #Remove the group from the array of group
        $i--                                                # set iterate down one to look a current array element 
      }#end not valid user if  
    }#end For loop 
  }#end else     
}#end CheckUsers Function 
#this Function takes in the user names and the group name and then removes the users from the group in AD
Function addManager{
  param([string]$user, [string[]]$groupAdd)   #paramaters 
  foreach($add in $groupAdd){        #Loops through "users" to individauly remove user from group 
    Set-ADGroup -identity $add -ManagedBy (Get-ADUser "$user")
  }  #end foreach loop
} #end RemoveUsers function 

<#
This function calls all other function. 
1. checkGroupName -> check the group name is Valid
2. CheckUsers -> takes user names is valid
3. addManager -> add user as manager to the groups that are requested
Then it sets the table column remoceConfired to Yes
Then sends email to the user and admin
#>
function updateManager(){
  #input information from database
  $query = "SELECT * FROM [Provisioning].[dbo].[AddUserAsManager] WHERE createConfirmed ='Null'"
  $groups= Invoke-Sqlcmd -Query $query -ServerInstance "serverName"

  foreach($checkGroup in $groups){                #add variables from table to the variables.
    $noGroup = ""
    [System.Collections.ArrayList]$group = $($($checkGroup).groups).split(";")    #group that is going to have users removed from 
    $user = $($checkGroup).owner                   #users to be removed. 
    CheckGroupName([ref]$group) ([ref]$noGroup)     #check if the group is valid in AD 
    addManager -user $user -groupAdd $group         #Add manager to the groups 
    #if there are groups that where not found in AD then it will send an email to the admin informing  that the groups were not found so the user could not be added as owner
    if($noGroup){
      $ticket = ($checkGroup).ticketNumber
      $completionEmailMessageUser ="For the request $ticket the following Groups where not found in AD: <br><br><table><tr><th>$noGroup</th>"
      insertEmail -userEmail $($checkGroup).adminUID -cc $($checkGroup).adminUID -message $completionEmailMessageUser -type "Groups not found to add manager" -TicketNumber $($checkGroup).ticketNumber
    }
    #Change null to Yes in createConfirmed column on server  -MUST TURN ON WHEN SENT TO TEST AND PROD. 
    $query = "UPDATE [Provisioning].[dbo].[AddUserAsManager] SET createConfirmed = 'Yes' WHERE id = '$($($checkGroup).id)'"
    Invoke-Sqlcmd -Query $query -ServerInstance "DCPWDBS1053"
    #send completion Email 
    $completionEmailMessageUser ="This email serves as confirmation that your request to add a  user as the owner of a group has been successfully created! See below for user information.<br><br><table><tr><th>Username</th><th>group</th><tr><td>$user</td><td>$group</td></tr>"
    insertEmail -userEmail $($checkGroup).owner -cc $($checkGroup).adminUID -message $completionEmailMessageUser -type "Add user as Owner of Groups" -TicketNumber $($checkGroup).ticketNumber
  }#end foreach in loop     
} #end UpdateGroupMembers Function 
updateManager