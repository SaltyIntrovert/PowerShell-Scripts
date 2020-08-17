<#
Program Name:    CreateDevices
Developer:       Samuel Armenta
Co-Developer:    Samuel Ransford
Date Developed:  11/1/19
Production Date: 12/4/2019

Program Description:

This program pulls data from server (name) Which inputs data form 
Program Microsoft SQL Server Management - file path Database -> Provisioning -> Tables -> dbo.CreateDevices -> Columns, every 15min
And outputs to Program Microsoft SQL Server Management - file path Database -> [].[].[]
The program creates a device in AD and sets it in the propper OU and AD
thing to be cautious of is when the naming convention changes the function "prefix" might have to be updated. 
When an OU or GG is changed you have to update the function "getOUAndGG"
Lasly if new device Types are added please check the conditional statments in the function "createDevice()" to insure they are created in the right areas. 
#>


<#
This function inputs requesters userName, admin userName, the message to be sent, if code had error, ticket number. 
It then places the information in the Terminations.dbo.emailData table in "DCPWDBS1053"
Will send in every quarter hour
#>
function insertEmail{
    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter the recipient's email address.")]$userEmail,
        [Parameter(Mandatory=$False,HelpMessage="Enter the CC's email address.")]$cc,
        [Parameter(Mandatory=$True,HelpMessage="Enter the message.")]$message,
        [Parameter(HelpMessage="Enter type of email (Success, Error, Information).")]$type,
        [Parameter(HelpMessage="Enter the ticket number.")]$TicketNumber
    )
    #headline for message
    $messagePre = "This email serves as confirmation that your request to create a Device has been successfully created! See below for user information.<br><br><table><tr><th>Username</th><th>Serial</th><th>Password</th><th>Owner</th></tr>"
    $message = $messagePre + $message                                 #add message to headline 
    $message += "</table>"                                            #make table format 
    $bcc = "eaa@sutterhealth.org"                                     #bcc EAM 
    $sentDate = $(Get-Date -Format "MM/dd/yyyy")                      # add date
    $subject = "Cherwell Request # $TicketNumber - New Device $type"  #set subject info 
    $userEmail = $userEmail
    if([string]::IsNullOrWhiteSpace($cc)){
        $cc += "informationservices@sutterhealth.org"
    }else{
        $cc += ";informationservices@sutterhealth.org"
    }
    #send info to table
    if($type -eq "Success"){
        $info = "Completion"
    }else{
        $info = "Error"
    }
    $query = "INSERT INTO Terminations.dbo.emailData (recipientEmail,ccEmail,bccEmail,subject,messageEmail,sentDate,typeEmail) VALUES ('$userEmail','$CC','$bcc','$subject','$message','$sentDate','$info')"
    Invoke-Sqlcmd -Query $query -ServerInstance "(serverName)"
}

<#
WARNING: IF NAME CONVENTION CHANGES MUST UPDATE
 This function passess one varable by reference
 If the device type is Iphone,Ipod or Ipad it will add SH to the front of the name.
 
#>
#============================
function prefix([ref] $n){

    $n.Value = "SH"+$n.Value #adds the prefix to ipads,pods and phones standard for device creation 
} #end of prefix function 

<#=============================
This function Inputthe device type and pass by reference the count of the iteration of the device type(when the function is called for the first time on the device type the count is 1)
Then the finction searches through AD to find the next valid name - EX shipod1.. shipod2 
When the next available name is found returns the name. 
===============================#>
function checkName{
 param( [string]$name, [ref]$i)

$check = $true  #set check to true to enter loop
$hold = $name   #hold the original name

#Loops to add a number to the end of the device name, checks Active directory to see if name is used
#if name is used moves increments number at the end at checks again
#once finds a empty name returns value 
while($check){
$name = $hold                                             #places original name before numbers were added
$name += $i.value.ToString("00")                          #add number to end of name
$check = Get-ADUser -LDAPFilter "(sAMAccountName=$name)"  #check AD true if in AD false if not
$i.value++                                                #increment to next number
} #end of while
return $name                                              #return name of device                     

} #end of checkName function 



<#=================================
WARNING: IF THE OU AND GG CHANGE FOR THE DEVICE YOU MUST UPDATE HERE OR THE DEVICES WILL BE PLACED IN THE WRONG OU WITH THE WRONG GG
This Function inputs the device type and passess by reference the ou and gg variables.
Current state: 
1.ipad: 
 OU:"OU=IPads,OU=Device Accounts,OU=Service Accounts,OU=Sutter Health Support Services,DC=root,DC=sutterhealth,DC=org" GG:"SH.BYODWiFi_AllowAccess"  
2.iphone and ipod: 
 OU:"OU=IPhones,OU=Device Accounts,OU=Service Accounts,OU=Sutter Health Support Services,DC=root,DC=sutterhealth,DC=org" GG:"SH.BYODWiFi_AllowAccess"
3.all other types: 
 OU:"OU=Device Accounts,OU=Service Accounts,OU=Sutter Health Support Services,DC=root,DC=sutterhealth,DC=org" GG:"SH.WiFi.GlucoseMeters"
=================================#>
function getOUAndGG([ref]$ou, $type, [ref]$gg){
    #these conditional statments check the name of the device and based on the type of device adds the propper "Orginizational Unit" and "Glabal Group" 
    if($type -eq "SHiPad"){  #ipad ou and GG
        $ou.Value = "OUInput"
        $gg.value = "GGforIpad"
    }
    elseif($type -eq "SHiPhone" -or $type -eq "SHiPod"){ #iphone and ipod ou and GG
        $ou.Value = "OUInput"
        $gg.value = "SggForPhoe"
    }
    else{ #all other device ou and gg
        $ou.Value = "OUInfo"
        $gg.value = "GGfordevice"
    }
}
<#==================================
This function inputs name, password, ou, gg, manager, department, description, serialNumber, notes -- of the new device
Then it creates a new user name for the device. 
Adds the propper gg for the primaryGroup
and removes the device for "Domain Users"
then adds "serial number, employeetype to non-user, and places notes
==================================#>
function createADMember{
    
    param([string]$name, [string]$pw, [string]$ou,[string]$gg, [string]$manager, [string]$department, [string]$description, [string]$serialNumber, [string]$notes)     
   
    $pwS = ConvertTo-SecureString -String $pw -AsPlainText -Force    #encrypt the password
    #add new device to AD
    New-ADUser -Name $name -DisplayName $name -SamAccountName $name -UserPrincipalName "$name@sutterhealth.org" -Manager $manager -Department $department -Description $description -AccountPassword $pwS -Path $ou -Enabled $true -CannotChangePassword $true -PasswordNeverExpires $true -Confirm:$false 

    Add-ADGroupMember -Identity $gg -Members $name -Confirm:$false                                                #add the gg to the account
    $group = get-adgroup $gg -properties @("primaryGroupToken")                                                   #set the account primary group 
    get-aduser $name | set-aduser -replace @{primaryGroupID=$group.primaryGroupToken}                             #set the account primary group 
    Remove-ADGroupMember -Identity "Domain Users" -Members $name -Confirm:$false                                  #remove user from the standard "Domain Users" global group 
    Set-ADUser -Identity $name -Replace @{serialNumber="$serialNumber";employeeType="Non-Person";info=$notes} -Confirm:$false #change primary group 
    
}
<#==================================
This funtion does not have any Inputs or outputs. 
This function calls all other functins and creates the device. 
IT uses a foreach in loop and conditional statment

1. get prifix
2. get ou and gg
3. get device name
4. create device in AD 

===================================#>
function createDevice(){
        $iterStarti = 1          #set variable to 1
        #These variables will keep count of the last number checked for the device type
        #This will keep the program from having to check from 1 everytime the checkName function is called
        #can save 30 seconds or more
        #==========================
        $iphonei = $iterStarti    
        $ipadi = $iterStarti
        $ipodi = $iterStarti
        $IStati = $iterStarti
        $NovaMBCi = $iterStarti
        $NovaMeteri = $iterStarti
        $NovaDAVi = $iterStarti
        #==========================

        #These Variables are set for the conditional statements so if the naming convention changes you would change the variable here 
        #==========================
        $iphone = "iPhone"
        $ipad =  "iPad"
        $ipod =  "iPod"
        $IStat =  "iStat"
        $NovaMBC = "NovaMBC"
        $NovaMeter = "NovaMeter"
        $NovaDAV =  "NovaDAV"
        #==========================
        #These variables assist with sending Emails 
        #=======================
        $manInt = 0 
        $managerHolder = @()
        $message = @()
        $ticketHolder = @()
        $adminHolder = @()
        #=======================
        
        #Call to pull data from data base and begin the inputing data into the program 
        $query = "SELECT * FROM [Provisioning].[dbo].[CreateDevices] WHERE createConfirm IS NULL"
        $cdevice = Invoke-Sqlcmd -Query $query -ServerInstance "(server Name)" 
      
        #check each row in data base
    foreach($input in $cdevice){
        $ou = ""     #set blank for "ou"
        $gg= ""      #set blank for "GG"

        #this information is input from the data base
        #==============================================
        $id = $($input).id
        $device = $($($input).deviceType).replace(' ','')
        $ticket = $($input).ticketNumber
        $manager = $($input).ownerUID
        $description = $($input).descrip
        $serialNumber = $($input).serialNumber
        $admin =$($input).adminUID
        $pw = $($input).devicePassword
        $dep = $($input).department
        $notes = ($ticket +" "+ $(Get-Date -Format "MM/dd/yyyy") + " " + $admin)
        #==============================================
       
        write-host $device

        #WARNING: IF THE OU CHANGE FOR DEVICES MUST UPDATE HERE! OR IF NEW TYPE OF DEVICE IS ADDED MUST ADD HERE IF OU AND GG ARE SAME. 
        if($device -eq $ipad){                                  #if ipad is created
            prefix([ref]$device)                                #add prefix to name
            getOUAndGG([ref]$ou) ($device) ([ref]$gg)           #get OU and the GG
            $device = checkName ($device) ([ref]$ipadi)         #find available Name to user 
            write-host $device $ou $notes                           #
           createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
        } #end if for ipad
        
        #WARNING: IF THE OU CHANGE FOR DEVICES MUST UPDATE HERE! OR IF NEW TYPE OF DEVICE IS ADDED MUST ADD HERE IF OU AND GG ARE SAME. 
        elseif($device -eq $iPhone -or $device -eq $ipod){     #if iphone or ipod
            prefix([ref]$device)                               #add prefix to name
            getOUAndGG([ref]$ou) ($device)([ref]$gg)           #get OU and the GG

            if($device -eq "SHiPhone"){                        #if iphone 
                $device = $device = checkName ($device) ([ref] $iphonei) #find available Name to user 
                write-host $device $ou $notes 
                createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
            }#end if iphone
            else{                                              #else ipod 
                $device = $device = checkName ($device) ([ref] $ipodi) #find available Name to user 
                createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
                write-host $device $ou $notes 
            }#end else ipod

        }#end elseIF for iphone and ipod

        #WARNING: IF THE OU CHANGE FOR DEVICES MUST UPDATE HERE! OR IF NEW TYPE OF DEVICE IS ADDED MUST ADD HERE IF OU AND GG ARE SAME. 
        else{
            getOUAndGG([ref]$ou) ($device) ([ref]$gg)  #get OU and the GG

            if( $device-eq $IStat){            #if istat
                $device = checkName ($device) ([ref] $IStati)  #find available Name to user 
                createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
                write-host $device $ou $notes 
            }
            elseif($device-eq $NovaMBC){       #if novambc
                $device = checkName ($device) ([ref] $NovaMBCi) #find available Name to user 
                createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
                write-host $device $ou $notes 
            }
            elseif($device -eq $NovaMeter){     #if novameter
                $device = checkName ($device) ([ref] $NovaMeteri) #find available Name to user 
                createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
                write-host $device $ou $notes 
            }
            else{                             #if novadavi
                $device = checkName ($device) ([ref] $NovaDAVi)  #find available Name to user 
                createADMember -name $device -pw $pw -ou $ou -gg $gg -manager $manager -department $dep -description $description -serialNumber $serialNumber -notes $notes #create new device in AD
                write-host $device $ou $notes 
            }
        
        }#end else

        $query = "UPDATE [Provisioning].[dbo].[createDevices] SET deviceSAN = '$device' WHERE id = '$id'"
        Invoke-Sqlcmd -Query $query -ServerInstance "serverName" 

        #if the first manager has not been passed through then enter. 
        if($manInt -ne 0){

             $notSame = $true                                         #Bool to look if the user has already been added to manger list - if has been added change to false
             $iter = 0                                                #track the position for new manger
             #While the current manager is not the same as a previous manager and $iter is let than the managers that are in the mangerHolder
             while($notSame -and $iter -lt $manInt){ 
                #if current manger is found in the array of managers
                if($manager -eq $managerHolder[$iter]){
                    $notSame = $False                                 #switch bool to false to allow for to not loop back through
                    $message[$iter] += "<tr><td>$device</td><td>$serialNumber</td><td>$pw</td><td>$manager</td></tr><br>"  #append to end of message 
                    if(!$adminHolder.contains($admin)){
                        $adminHolder += "$admin " 
                    }#endIf
                }#end if 
                $iter++                                                #check next manager in manger array 
             }#while 
             if($notSame){                                             #if the current manager is not in the array of managers
                 
                $managerHolder += $manager                    #add manger to manger array 
                $message += "<tr><td>$device</td><td>$serialNumber</td><td>$pw</td><td>$manager</td></tr><br>"  #append to end of message 
                $ticketHolder += $ticket                      #append to ticket
                $adminHolder += $admin
                $manIter++                                             #increase iter by one to add to manger array
             }
                
        }#end if 

        #if this is the first manger to be checked. 
        else{
                 $message += "<tr><td>$device</td><td>$serialNumber</td><td>$pw</td><td>$manager</td></tr><br>"          #append to end of message 
                 $managerHolder += $manager                           #add manager to manager array                                                 
                 $ticketHolder += $ticket                             #add ticket to ticket array 
                 $adminHolder += "$admin "
                 $manInt++                                            #increase iter by one to add to manger array 

        }#end Else
         
        
        #Change null to Yes in createConfirmed column on server  -MUST TURN ON WHEN SENT TO TEST AND PROD. 
        $query = "UPDATE [Provisioning].[dbo].[createDevices] SET createConfirm = 'Yes' WHERE id = '$id'"
        Invoke-Sqlcmd -Query $query -ServerInstance "ServerName" 
        
    }#end for each 

    #loop through array to send out emails to managers
    for($i = 0; $i -lt $managerHolder.count;$i++){
        $m = $managerHolder[$i]
        $a = $adminHolder[$i]
        $me = $message[$i]
        $t = $ticketHolder[$i]
        insertEmail -userEmail $m -cc $a -message $me -type "Success" -TicketNumber $t
    }
    
}#end function 


createDevice 
