$yesDr = $false
$yesFull = $flase
# ============================================
#This information will be input from the name change Table
$fname = read-host 'Please enter first name'
$lname = read-host 'Please enter last name'

$Drcheck = read-host "Is this for a Dr yes no?"
if($Drcheck -eq "yes"){
    $yesDr = $true
}

if($yesDr){
    $getNpi =  read-host "Please enter NPI"
}

$fullCheck = read-host "If this a full time employee yes no?"
if($fullCheck -eq "yes"){
    $yesFull = $true
}

if($yesFull){
    $getId =  read-host "Please enter ID#"
}
#==========================================

#global Variables to collect user info 
#these Variables can be userd through out the Script. 
#=================
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
#===================

<#================================================
This function takes in a variable that contains an employee id number
it will queue the MDM data base and place the MMD id into the variable that was passed in 
#===============================================#>
function getUserMMD([ref]$empID){
    $m = $empID.Value                                #hold id number
    
    $query = "SELECT * FROM [].[].[] where employee_id = '$m'"  #queue data base for user 
    $pty = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME"

    $empID.Value = $pty.PTY_ID                       #palce MMD id into variable 
    
}#end function



<#===================================================================
This function takes in one Array by reference and then based on the users MMDID in the array 
Pulls information form [].[].[] table that will be used to check if account is already a user 
or to create a new AD account
#===================================================================#>
function getUserInfo([ref]$MMD){
$m  = $MMD.value

#query the MMD data base for the users Assosiated for the MMD ID
$query = "SELECT * FROM [].[].[] where pty_id = '$m'"
$name = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME"

#chekck each account assosiated with MMD ID
 WRITE-HOST "`n`nThese are the accounts assosiated with $m : `n"
 #this looks for each user that is assosiated with the current MMDID that is called apon 
    
    #If the employee is not termed then gather the following information 
    #this info is checked later to see if the user is in AD or needs to have an account created 
   
    write-host "This account is NOT Term"          #these are accounts that are not termed
    write-host $global:first += ($name).FIRST_NAME
    write-host $global:last += ($name).LAST_NAME
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
   <# if(!($name).WORK_PHONE){
        $global:phoneNumber += ($name).WORK_PHONE                                        #check if ther is a phone number if not then phone number is nUll
    }#end if 
    else{                                                                                #else
        $numnum = ($name).WORK_PHONE                                                     #hold number is vaiable
        $global:phoneNumber += "{0:+1(###)###-####}" -f [int]$numnum                     #format the phone number
    }#end else#>
    write-host "`n"
   
    write-host "Pulled all info"
}#end function 

<#==============================
This function takes in the uses NPI number and variable that is bull that will let the function know if the user is a full time employee
Then the function queries the data base for the user with the NPI number and then gets the MMD number, first name, and last name
Checks to make sure the names from the data base match the names input into the script
if same user then MMD ID is passed back if not same user send email
if the user is the same and they are not a full time employee they will have info pulled from echo or right source 
==============================#>
function npi{
    param([ref]$NPI, [ref]$check)
    $number = $NPI.value                               #hold NPI number 
    $query = "SELECT * FROM [].[].[] where NPI_NUMBER = '$number'" #queries data base for user with npi number
    $names = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME"
    
    $NPI.value = $names.PTY_ID                         #NPI vales is now MMD ID
    
    $global:first = $names.FIRST_NAME                  #get first name 
    $global:last = $names.LAST_NAME                    #get last name 
    
    #check if the first and last name that were input were the same as the first and last name found with the NPI number assosiated in the data base. 
    if(($global:first -ne $fname) -or ($global:last -ne $lname)){
        $check.value = $false                          #if they are not the same set check($yesFull) to false prevent from entering next stage
        write-host "sorry name for " $number " is" $first $last " you entered " $fname $lname        #Send email to admin that user was not found 

    }#end if 
    elseif(!$yesFull){                                #if input name and NPI name are valid and the user is not a full time employee pull the information form echo
        write-host "pull in info from echo"
    }#end else
}#end npi function 


<#==============================
This function takes in the MMD number and employee number
then queries the the data base with the MMD id and the employee id
checks if the id number found and id number provided are the same
if same checkse input name and name found assosiated with MMD and ID#
if same then calls getUserInfo()
else email admin info does not match 
==============================#>
function checkId{
    param([ref]$mmd, [ref]$empID)
    $num = $mmd.value       #MDM id HOLDER
    $idNum = $empID.Value   #Enp ID holder
    
    $query = "SELECT * FROM [].[].[] where pty_id = '$num' and employee_id ='$idNum'"  #query database 
    $names = Invoke-Sqlcmd -Query $query -ServerInstance "SERVER NAME"

    #check if the ID# input is the same as the ID found in the data base
    if($idNum -eq $names.EMPLOYEE_ID){                  
       
        $global:first = $names.FIRST_NAME      #get first name from database
        $global:last = $names.LAST_NAME        #get last name from database
            #check that the last and first name input is the same as the first and last name in found in Database
            if($first -eq $fname -and $last -eq $lname){
                getUserInfo([ref]$num)         #Call function 
            }#end if    
            else{                             #if names do not match send email to admin 
                write-host "The ID number " $idNum " is assosiated with " $first $last " not " $fname $lname     
            }#end else
    }#end if 
}#end checkId function 


if($yesDr){                                     #if DR
    npi([ref]$getNpi) ([ref]$yesDr)             #get MDM based on NPI
    if($yesFull -and $yesDr){                   # if dr and full time
        checkId([ref]$getNpi) ([ref]$getId)     #pass id number and MDM number to check user
}#end id
}#end if 
elseif($yesFull){                              #if a full time employee
    $holderID = $getId                         
    getUserMMD([ref]$holderID)                 #get MDM number
    checkId([ref]$holderID) ([ref]$getId)      #pass id number and MDM number to check user
}#end else if 
else{
    write-host "Just change????"

}