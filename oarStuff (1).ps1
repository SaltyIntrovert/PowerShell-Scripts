<#===================================================
This function takes in the fitst, last, middle name of the new employee and the variable userName1 by reference to gain a user name that is not user
This function will give a usename for the new use based on Their first, last and middle name. 
userName: 
first 6 letter of last name or less, first letter of first name and then find a valid name 
if not valid add number1-9 and if still not valid and no middle name then add 1 to number until valid name found else add first letter of middle name and try to add 1-9. 
is cant find valid userName then take one off of the last name adds a letter from the first name.
=====================================================#>
function GetName{
    param($last, $first, $middle, [ref]$userName1)
    $userName = ""
    $found = "True"                    #variable to see if user is in AD
    $i = 1                             #number to iterate through if in user name in AD
    $last = $last -replace '[^a-zA-Z]', ''
    $first = $first -replace '[^a-zA-Z]', ''

    $lnum = $last.Length               #length of last name to gather up to 6 char of last name 

    if($lnum -lt 6){                   #if lenght of last name is less than 6  
        $check = $lnum
    } #end if
    else{$check = 6}                   #else last 6 characters gathered are 6



    $userName = $last.Substring(0,$check)      #gather up to last 6 char of last name 
    $userName += $first.Substring(0,1)         #gather first char of first name
    $userName = $userName.replace(' ','')      #remove spaces

    $checkLength = $userName.Length            #get length of number

    if($middle -and $checkLength -lt 3){       #if there is a middle initial and a user first and last is less than 3 characters add middle in
     $userName += $middle.Substring(0,1)       #add middle name to user name
     $userName = $userName.replace(' ','')     #remove spaces 
    }#end if 

    $found = Get-ADUser -LDAPFilter "(sAMAccountName=$userName)"    #see if username is in AD
    #$nonList = NoName($userName)  
    $original = $userName                                           #this is a holder for the origianl user name, if numbers need to be added


    while($found -or $userName.Length -lt 3){                       #if User name is in AD or the lenght of the user name is less than 3 enter loop 


    $userName += $i                                                      #add number to end of user name 
    if($found = Get-ADUser -LDAPFilter "(sAMAccountName=$userName)"){    #check user name in AD
    $userName = $original                                                #if in AD set to original user name 
    } #if user name in AD 
 
    if($i -eq 10 -and !([string]::IsNullOrEmpty($middle))){                                          #if the iteration = 10 and there is a middle name then add middle inital, set iterator back to 0 search for a valid user name
    $userName = $original                                                #set user name to original 
    $userName += $middle.Substring(0,1)                                  #add middle initial 
    $original = $userName                                                #set holder to new user name 
    $i=0                                                                 #set i to 0 
    $found = Get-ADUser -LDAPFilter "(sAMAccountName=$userName)"         #check if new name is in AD 
    }#end if user name 

    $i++                                                                 #add to next number 


    #Check if user name is greater than 8 characters - if greater than 8 remove one letter from the last name
    #If the user name becomes less than three characters check if middle initial and if there is add it. 
    if($userName.Length -gt 8){ 
        $check = $check-1                                         
        $userName = $last.Substring(0,$check)       #gather up to last 6 char of last name 
        $userName += $first.Substring(0,1)          #gather first char of first name
        $userName = $userName.replace(' ','')       # remove spaces
        $i = 1
          if($userName -lt 3 -and $middle){
                $userName+= $middle.Substring(0,1) 
          }#end if for middle name 
    }#end if for name length
    }#end while 

    if(!$found){
      $userName1.value = $userName
    }#end if 
    

}#End GetName Function  

#=============================================================
#this function takes in an String Array of MMD ID and one MMD ID and a number as an iter
#it then looks through the MMD Array to see if the new found MMD ID is already in the Array
#if not return False -- else return true
#==============================================================
function CheckMMD{
    param([string[]]$M, [string]$m1, [string]$count)
    
    for($i=0;$i -lt $count; $i++){       #loop through to see if ID is in the Array 
        if($m1 -eq $M[$i]){              #checks id VS the Array to see if the ID is in Array  and if in Array sets $found to true
            $found = $True               #if $found is true then the ID is in Array 
            break                        # break loop because id is in Array
        }#end if  
    }#end For loop 
    if($found){Return $True}             #if found return True
    Else{$False}                         # else return false
}#end Function 


<#================================================
This function takes in an Array that will have MMD ID added to its elements
It will look only at users that are not termed and only get ther MMD ID
It wil also check to make sure it does not input the same ID twice. 
#===============================================#>
function getUserMMD([ref]$MMD){
    
#Call to MMD database to queue info about the users with the same first and last name
$query = "SELECT * FROM [].[].[] where FIRST_NAME LIKE '%$fname%' and LAST_NAME = '$lname'"
$sam = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME"

$mCount = 0   #holds the count of iter

#loopes to check all the names that were pulled from MMD Data base - Looks for employees that are not termed
#if not termed takes he MMD ID and stores in Array 
 foreach($sams in $sam){

    [string]$check = ""                                      
    $check = ($sams).TERMINATION_DT            #check if employee is termed
  
    if( $mCount -eq 0 -and $check -eq "" ){    #if not termed and if this is the first user to be cheked, then check the user 
    
        $PTY = ($sams).PTY_ID                  #Place the ID into PTY
        $MMD.value += $PTY                     #PTY_ID placed in MMD Variable
      $mCount++                                #iter inc
      
    }#end IF

    else{                                      #if not first employee
        $holder = ($sams).PTY_ID               #hold ID number
        $newC = checkMMD -M $MMD -m1 $holder -count $mCount  #call function checkMMD to check if ID is already in Array
             
        if(!$newC -and $check -eq ""){         # if new id not in array then add to array 
        $MMD.value += $holder                  #add id to Array 
        $mCount++                              #iter inc
       
        }  #end if
    }#end else
}#end for Each
}#end function



<#===================================================================
This function takes in one Array by reference and then based on the users MMDID in the array 
Pulls information form [].[].[] table that will be used to check if account is already a user 
or to create a new AD account
#===================================================================#>
function getUserInfo([ref]$MMD){
foreach($m in $MMD.value){

#query the MMD data base for the users Assosiated for the MMD ID
$query = "SELECT * FROM [].[].[] where pty_id = '$m'"
$names = Invoke-Sqlcmd -Query $query -ServerInstance "SEVER NAME"
    $usersWithMDM =  $($names | measure-object | select count).count
    write-host "Ammount: " $usersWithMDM
#chekck each account assosiated with MMD ID
 #WRITE-HOST "`n`nThese are the accounts assosiated with $M : `n"
 #this looks for each user that is assosiated with the current MMDID that is called apon
  if($usersWithMDM -eq 1){
    foreach($name in $names){
    $h = ($name).HIRE_DT  
   #This check looks for accounts that are termed
   #if termed gather info
   #this may be used in further scripts, but for new employees not needed
    if($hireDate -ne $h.tostring()){
    <#
    write-host "This account is Term"          #these are accounts that are termed
    write-host ($name).FIRST_NAME              
    write-host ($name).LAST_NAME
    write-host ($name).EMPLOYEE_ID
    write-host ($name).STATUS_CD_DESC
    write-host "`n"#>
    }#end if 

    #If the employee is not termed then gather the following information 
    #this info is checked later to see if the user is in AD or needs to have an account created 
    
    elseif($hireDate -eq $h.tostring()){
    write-host 'newuser'
    #write-host "This account is NOT Term"          #these are accounts that are not termed
    $global:MDMID += $m
    $global:first += ($name).FIRST_NAME
    $global:last += ($name).LAST_NAME
    $global:id += ($name).EMPLOYEE_ID
    $global:middle += ($name).MIDDLE_NAME
    $global:status += ($name).STATUS_CD_DESC
    $global:fullName += ($name).FULL_NAME
    $global:workAddress += ($name).WORK_ADDR_LINE1
    $global:city += ($name).WORK_ADDR_CITY
    $global:state += ($name).WORK_ADDR_STATE
    $global:zip += ($name).WORK_ADDR_ZIP
    $global:county += ($name).WORK_ADDR_COUNTY
    $global:supFirst += ($name).SUPERVISOR_FIRST_NAME
    $global:supLast += ($name).SUPERVISOR_LAST_NAME
    $global:superID += ($name).SUPERVISOR_EID
    $global:company += ($name).COMPANY_DESC
    $global:region += ($name).REGION_DESC
    $global:affiliate += ($name).AFFILIATE_FACILITY
    $global:title += ($name).JOB_CD_FULL_DESC
    $global:dep +=  ($name).DEPT_CD_FULL_DESC
    <#
    if(!($name).WORK_PHONE){
        $global:phoneNumber += ($name).WORK_PHONE                                        #check if ther is a phone number if not then phone number is nUll
    }#end if 
    else{                                                                                #else
        $numnum = ($name).WORK_PHONE                                                     #hold number is vaiable
        $global:phoneNumber += "{0:+1(###)###-####}" -f [int]$numnum                     #format the phone number
    }#end else
    #>
    write-host "`n"
    }#end Else 
    }#end name for each 
    }
}#end mmd for each 
}#end function 

<#====================================================
This function does not take in any variables. 
It does check if the user is in AD - if it finds a user in AD with the same first, last name and EMployee id number then it will send a email user has been made. 
If A user is not found in AD then it will create a user in AD with information gathered in earlier functions
#====================================================#>
function createAccount(){
$i = 0 #iter to loop through the NON TERM accounts Assosiated with the MMD ID

#Look therough the NON TERN accounts Assosiated with The MMD ID and check and see if the first name, last name, and ID# is assosiated with an Account in AD
#IF the user is not found in AD then if will create a new account-> if it finds a user then the account is alread create and the user might be a double request
While($i -lt $first.count){
#========================
#variables used to look for users in ad
$user = ""
$newID = ""
$fAD = $first[$i]
$lAD = $last[$i]
$idAD = $id[$i]

#=======================
$user = (Get-ADUser -Filter ({givenName -eq $fAD -and surname -eq $lAD  -and employeeid -eq $idAD}))   #query AD for user that might have same first name last name and ID#

$newID = (Get-ADUser ($user).SamAccountName -Properties EmployeeID).EmployeeID                           #get the ID number
                                                            
#if the id that was assosiated with the MMD id and the ID was found in AD then the account is created -> send emai account created or have Admin look at account                                                                                                
if($id[$i] -eq $newID){
  #send an email have account checked
  write-host "this user is already in AD" $fAD $lAD $idAD
}#end IF

elseif($status[$i] -ne "TA- Terminated") {                   #else make sure the account is set for pending employement and make a new account 
 $supfAD = $supFirst[$i]
 $suplAD = $supLast[$i]
 $supidAD = $superID[$i]

#look for Manager in AD 
$user = (Get-ADUser -Filter ({givenName -eq $supfAD -and surname -eq $suplAD -and employeeid -eq $supidAD}))   #query AD for user that might have same first name last name and ID#
#get managers OU 
$replaceInfo = "SEtUpOUInfo,"
$ouAD = $($user) -replace $replaceInfo,""  

    $mmdid = $MDMID[$i]
    $aff = $affiliate[$i]
    $userNameAD = ""            
    GetName -last $last[$i] -first $first[$i] -middle $middle[$i] ([ref]$userNameAD)       #call get name function which makes a valid account name for the user and will be used as the username for employee 
    $mAD  = $middle[$i]   
    $statusAD = $status[$i]
    $fullAD = $fullName[$i]
    $addressAD = $workAddress[$i]
    $cityAD = $city[$i] 
    $stateAD = $state[$i] 
    $zipAD = $zip[$i] 
    $countyAD = $county[$i] 
    $supFullAD = "$suplAD, $supfAD"
    $supSamAD = $($user).samaccountname
    $compAD = $company[$i]
    $regionAD = $region[$i]
    $ouAD
    $emailAD = "$usernameAD@domainName"
    $homeDAD ="ouAddon\$userNameAD"
    $titleAD = $title[$i]
    $phoneAD = $phoneNumber[$i]
    $pw = "setpassword"
    $pw1 = ConvertTo-SecureString "setPW" -AsPlainText -Force
    $depAD = $dep[$i].split('-')[1].split(' ')
    [string]$depNew = $depAD
    $depNew = $depNew.trim()
    #write-host $phoneAD

    $query = "INSERT INTO [OAR].[dbo].[newUsers] VALUES ('$mmdid','$userNameAD','$fAD','$lAD','$mAD','$idAD','$fullAD','$supfAD','$suplAD','$supidAD','$addressAD','$cityAD','$stateAD','$zipAD','$countyAD','$compAD','$regionAD','$aff','$titleAD','$depAD','$ouAD','$emailAD','','','','','','','','')"
    Invoke-Sqlcmd -Query $query -ServerInstance "serverName"

    WRITE-HOST "new users info" $userNameAD $fAD $lAD $idAD
    #write-host $ouAD  $fAD $lAD $mAD $idAD $statusAD $fullAD $addressAD $cityAD $stateAD $zipAD $countyAD $supfAD $suplAD $supFullAD $supSamAD $compAD $regionAD $ouAD $emailAD $homeDAD $titleNewAD
   
    
  # New-ADUser -Name $fullAD -GivenName $fAD -Surname $lAD -SamAccountName $userNameAD -Initials $mAD -OfficePhone $phoneAD -title $titleAD -Department $depNew -DisplayName $fullAD -UserPrincipalName $emailAD -Path $ouAD -Description $titleAD -AccountPassword $pw1 -PasswordNeverExpires $false -CannotChangePassword $false -Company $compAD -City $cityAD -ChangePasswordAtLogon $true -AccountExpirationDate $flase  -EmailAddress $emailAD -EmployeeID $idAD -HomeDrive "I:" -HomeDirectory $homeDAD -manager $supSamAD -PostalCode $zipAD -State $stateAD -StreetAddress $addressAD -Enabled $true
   #createHomeFolder -Username $userNameAD        #call createHomeFolder function to create the folder of a new user with the user name made.
}#end elseif

$i++   #iter inc
}#end while looop
}#end function 

#=====================
#call all other functions
#====================

$month = 12
$day = 18
$year = 2019
$total = 1

 while($total -lt 30){
    if($day -gt 31){
        $day = 1
        $month++
        if($month -gt 12){
        $month = 1 
        $year++   
    }
    }
    else{$day++}

    write-host $year $month $day
    $query = "SELECT * FROM [].[].[] where HIRE_DT = '$year-$month-$day 00:00:00.000' and STATUS_CD_DESC NOT LIKE '%Term%'"
    $name = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME" 
    
    foreach($mmdUser in $name){
        write-host "`n`n user checked: "
        $fname = $mmdUser.FIRST_NAME
        $lname = $mmdUser.LAST_NAME
        write-host $mmdUser.FIRST_NAME $mmdUser.LAST_NAME
        write-host $fname $lname
        $mmd = @()
    $global:hireDate = @()
    $global:MDMID = @()       
    $global:id = @()
    $global:first = @()
    $global:last = @()
    $global:middle = @()
    $global:fullName = @()
    $global:workAddress = @()
    $global:city = @()
    $global:state = @()
    $global:zip = @()
    $global:county = @()
    $global:supFirst = @()
    $global:supLast = @()
    $global:company = @()
    $global:region = @()
    $global:affiliate = @()
    $global:superID = @()
    $global:status = @()
    $global:title =@()
    $global:dep =@()
    $global:phoneNumber =@()
    $global:hireDate = $month.tostring()+'/'+$day.tostring()+'/'+$year.tostring()+' 12:00:00 AM'
#===================
       getUserMMD ([ref]$mmd)
       getUserInfo ([ref]$mmd)
       createAccount 
    }
    
$total++
}


