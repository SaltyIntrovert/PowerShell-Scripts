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

    if($i -eq 10 -and $middle){                                          #if the iteration = 10 and there is a middle name then add middle inital, set iterator back to 0 search for a valid user name
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
