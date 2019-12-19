#This function checks to see if the group is a valid group in AD
#If it is valid then it will return True - else False
Function CheckGroupName($checkGroup){

    $checkGroup = Get-ADGroup -Identity $checkGroup #check if the group is is in AD 

    #check if group in in AD 
    if($checkGroup -eq $NULL){           
        return $False                                #if in AD return false
    }#endIf 
    else{              
        return $True                                 #if in AD return true
    }#end else 
}#end CheckGroupName Function 

#this Function checks to see if the users are valid in AD
#if they are valid then they will leave the user name in the Array
#if they are not valid it will take them out of the Array and place then an Array for not valid users
Function CheckUsers([ref]$users, [ref]$usersNotFound){ 
    #check if only one user is validated 
   if($users.value.count -eq 1){

   $name = $users.Value             #pass use into name 

   $checkName = Get-ADUser -LDAPFilter "(sAMAccountName=$name)" #check if name is a valid user name in AD 

   If ($checkName  -eq $Null)                                   #if Not a valid name then enter
   {
   $usersNotFound.value += (" $name")                           #Add user name to not valid use name array 
   $users.value.remove($name)                                   #Remove the user from the array of users
   }#end if for not valid name 

   }#end if for one user 

   else{                                                        #if more than one user to check 
   for($i = 0; $i -lt $users.value.count;$i++){   

    $name = $users.value[$i]                                     #user name to name 

   $checkName = Get-ADUser -LDAPFilter "(sAMAccountName=$name)"  #check if name is in AD
                  
   If ($checkName  -eq $Null)                                    #if user name not a valid AD user 
   {
   $usersNotFound.value += (" $name")                            #Add user name to not valid use name array 
   $users.value.remove($name)                                    #Remove the user from the array of users
    $i--                                                         # set iterate down one to look a current array element 
   }#end not valid user if  
   
    }#end For loop 
    }#end else 
}#end CheckUsers Function 

#this Function takes in the user names and the group name and then removes the users from the group in AD
Function RemoveUsers{

    param([string[]]$usersRemove, [string]$groupRemove)   #paramaters 
   
    foreach($user in $usersRemove){                       #Loops through "users" to individauly remove user from group 
     Remove-ADGroupMember -Identity $groupRemove -Members $user -Confirm:$False  #removes user form grou 
    }  #end foreach loop
} #end RemoveUsers function 

#This function calls 
function UpdateGroupMembers(){
    [System.Collections.ArrayList]$users = "arments","sammsamm"
    $group = "AB.samtest.CH"
    $notFound =""

    if(CheckGroupName($group)){                         #Check that the group is valid in AD, if valid all to check users 
  
    CheckUsers ([ref]$users) ([ref]$notFound)           #check if user names are valid and filter ones out that are not 

    RemoveUsers -usersRemove $users -groupRemove $group #remove users from group 

    }# End if loop for checking group 
    
} #end UpdateGroupMembers Function 


UpdateGroupMembers



