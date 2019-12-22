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
         $name = Invoke-Sqlcmd -Query $query -ServerInstance ""
    
        if($check.EmployeeID){
            $id += $check.EmployeeID +"`t`t" + $check.SamAccountName + "`t`t"+ $check.name  
        }
        elseif($name.EMPLOYEE_ID){
            $noID += $name.EMPLOYEE_ID + "`t`t" + $check.SamAccountName + "`t`t" + $check.name 
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

