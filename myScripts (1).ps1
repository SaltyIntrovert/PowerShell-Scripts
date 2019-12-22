This is a Tool kit to help with everyday work flow

<#==================================
add users to group 
==================================#>

function addUserToGroup(){
$group = ""
$members= @()

$group = read-host "Please enter the group name (no spaces)"
$members = read-host "please enter the user names (Place place a , or ; between user names)"
$members = $members -replace"`n|`t|`r",""
$members = $members.split(' ')
$members = $members.split(",").trim(" ")
$members = $members.split(";").trim(" ")

$i = 0
while($i -lt $members.count){
Add-ADGroupMember -Identity $group -Members $members[$i]
$i++
}
}
<#================================
Check employee ID
=================================#>
function checkIdInAD{
$members= @()
$members = read-host "please enter the user names (Place place a , or ; between user names)"
$members = $members -replace"`n|`t|`r",""
$members = $members.split(" ").trim("")
$members = $members.split(",").trim(" ")
$members = $members.split(";").trim(" ")
$id = @()
$noID = @()
$userNot = @()
$first = @()
$last = @()
$samName = @()
$addId = @()
$addUser = @()

$i = 0 
while($i -lt $members.count){
    $check = ""
    $check = Get-ADUser -Identity $members[$i] -properties employeeid

    $f = $check.givenname
    $l = $check.surname

    if(!$check){
        $userNot += $members[$i]
    }
    else{
         $query = "SELECT EMPLOYEE_ID FROM [].[].[] where STATUS_CD_DESC NOT LIKE '%term%' and FIRST_NAME LIKE '%$f%' and LAST_NAME = '$l'"
         $name = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME"
        if($check.EmployeeID){
            $id += $check.EmployeeID +"`t`t" + $check.SamAccountName + "`t`t"+ $check.name  
        }
        elseif($name.EMPLOYEE_ID){
            $noID += $name.EMPLOYEE_ID + "`t`t" + $check.SamAccountName + "`t`t" + $check.name
            $addId += $name.EMPLOYEE_ID
            $addUser += $check.SamAccountName
        }
        else{ $userNot += $userName}
    }
    $i++
}

write-host "`n`nUsers with ID in AD : "
$i = 0 
while( $i -lt $id.count){
    write-host $id[$i]
    $i++
}

write-host "`n`nUsers with no ID in AD and ID from Lawson: "
$i = 0 
while( $i -lt $noID.count){
    write-host $noID[$i]
    $i++
}

write-host "`n`nUsers Not found: "
$i = 0 
while( $i -lt $userNot.count){
    write-host $userNot[$i]
    $i++
}

$yesNo = read-host "Would you like to add the lawson employeeID numbers to AD? (yes) or (no)"
if($yesNo -eq "yes"){
    $desc = read-host "please input (TICKET NUMBER) (TODAYS DATE) (YOUR USER NAME) for sutter tab" 
    if($addUser.count -eq 1){
        set-aduser -Identity $addUser -EmployeeID $addId -description $desc
        write-host $addId " has been added to " $addUser
    }
    else{
        $i = 0
        while($i -lt $addUser.count){
        set-aduser -Identity $addUser[$i] -EmployeeID $addId[$i] -description $desc
        write-host $addId[$i] " has been added to " $addUser[$i]
        $i++
    }
}
}
else{write-host "Did not add employee id to AD"}

}
<#================================
#update employee id
==================================#>
function updateID#(){
$user= @()
$id = @()

$user = read-host "please enter the user names (Place place a  ,or ; between user names)"
$members = $members -replace"`n|`t|`r",""
$user = $user.split(' ')
$user = $user.split(",").trim(" ")
$user = $user.split(";").trim(" ")

$id  = read-host "please enter the id # (Place place a , or ; between id #)"
$members = $members -replace"`n|`t|`r",""
$id  = $id.split(' ')
$id  = $id.split(",").trim(" ")
$id  = $id.split(";").trim(" ")

$desc = read-host "please input (TICKET NUMBER) (TODAYS DATE) (YOUR USER NAME) for sutter tab" 
$i = 0
while($i -lt $user.count){
set-aduser -Identity $user[$i] -EmployeeID $id[$i] -description $desc

$i++
}
}

<#================================
get users of a group 
==================================#>
function getUsersofGroup(){
$group = ""
$group = read-host "please enter group name"
$users = Get-ADGroupMember -Identity $group

$i = 0 
while($i -lt $users.count){
$user = $users[$i].samaccountname +"`t`t"+  $users[$i].name 
write-host $user
$i++
}

}


<#================================
#get owner of a group 
==================================#>

function getOwnerOfGroup(){
$manager = @()
$group = @()
$groups = @()

$group = read-host "please enter the grop names (Place place a  ,or ; between group names)"
$group = $group -replace"`n|`t|`r",""
#$group = $group.split(' ')
$group = $group.split(",").trim(" ")
$group = $group.split(";").trim(" ")



if($group.count -ne 1){
$i = 0 
while($i -lt $group.count){
write-host "account checked" $group[$i]
$m = Get-ADGroup -Identity $group[$i] -Properties ManagedBy

$n = Get-ADUser -Identity $m.ManagedBy
write-host "`ngroup:" $m.samaccountname "   " "Manager:" $n.samaccountname "`n"

$name = $n.samaccountname


if($i -eq 0){
    
    $manager += $name
    $groups += "`n"+$group[$i] + "`n" 
    

}

elseif(!$manager.contains($name)){
    
     $manager += $name 
     $groups += "`n"+ $group[$i] + "`n" 

}
else{
$j=0
    foreach($man in $manager){

        if($name -eq $man){
            $groups[$j] += $group[$i]+ "`n" 
        }
        $j++
    }
}
$i++
}

$k = 0
while($k -lt $manager.count){
    write-host "This is the manager" $manager[$k] "of these groups: " $groups[$k]
    $k++

}
}
else{
    write-host "account checked" $group
$m = Get-ADGroup -Identity $group -Properties ManagedBy

$n = Get-ADUser -Identity $m.ManagedBy
write-host "`ngroup:" $m.samaccountname "   " "Manager:" $n.samaccountname "`n"

$name = $n.samaccountname
}
}

Function InputPermissionGroupToOU(){
    #param([string] $permissionGroup, [string]$owner, [string[]]$coOwners,[string[]]$members, [string]$description,  [string]$notes,[string]$chRd)  #parameters input into function 
     $members =@()
     $permissionGroup = read-host "please enter group name"
     $owner = read-host "please enter the owner user name"
     $members = read-host "please enter the members userNames or press enter if there are none"
     $members = $members -replace"`n|`t|`r",""
     $members = $members.split(' ')
     $members = $members.split(",").trim(" ")
     $members = $members.split(";").trim(" ")
     $description = read-host "please enter a description"
     $notes = read-host "Pleae enter - ticket# date and admin userName - This is for sutter tab"
    
    #create group 
    New-ADGroup -Name $permissionGroup -DisplayName $permissionGroup -GroupScope Global -GroupCategory Security -Path "OU=" -ManagedBy $owner -Description $description -Confirm:$false
    #add notes
    Set-ADGroup -Identity $permissionGroup -Replace @{info="$notes"}

                                                                   #check if needs to add owner and co-owner as members 
    Add-ADGroupMember -Identity $permissionGroup -Members $owner         #add owner to group
    
    if( $members -ne $NULL){                                                            #check if members
        foreach($user in $members){  
            write-host $user                                               #add members to members of permission group
            Add-ADGroupMember -Identity $permissionGroup -Members $user
        } #end foreach in for members
    }  #end if for members   
          
}#end of function 


$again = $true

While($again){
$option = read-host "Please pick an option`n1.Add Users to group`n2.Check if user has employeeID in AD if not get from lawson`n3.Update employeeid in AD#`n4.Get Users of Group`n5.Get owner of group`n6.Create Group`nChoice:"

switch ($option) {
   "1"  {addUserToGroup; break}
   "2"  {checkIdInAD; break}
   "3"  {updateID#; break}
   "4"  {getUsersofGroup; break}
   "5"  {getOwnerOfGroup; break}
   "6"  {InputPermissionGroupToOU; break}
   default {"You did not choose an option"; break}
}
    $input = read-host "Would you like to pick another option (yes) or (no)"
    if($input -ne 'yes'){
        $again = $false
    }
}