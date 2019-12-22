<#
Program Name:    New Share Drive
Developer:       Samuel Armenta
Co-Developer:    Samuel Ransford
Date Developed:  10/14/19
Production Date: Undetermined

Program Description:

This program pulls data from server '' Which inputs data form 
Program Microsoft SQL Server Management - file path Database -> Provisioning -> Tables -> dbo.CreateGG -> Columns, every 15min
The program creates Global Groups in Active Directory, adds file to netApp server and adds info to DFS 
# >$null 2>&1
#>

#Email requestor and Admin 
#----------
function insertEmail{

    param( [string]$admin, [string]$owner, [string]$coOwner, [string]$ticketNum, [string]$ch, [string]$rd, [string]$message, [string]$type )
    $ownerName = $(Get-ADUser $owner).GivenName
    $coOwnerNameStash = ""
    $coOwners = $($coOwner) -Split(";")
    write-host $coOwner
    foreach($coOwner in $coOwners){
        #$coOwnerNameStash += $(Get-ADUSer $coOwner).GivenName
        $coOwnerNameStash += "<br>"
    }
    $groupEmail = "<tr><td><strong>Read/Write Group:</strong></td><td>$ch"
    $ownerEmail = "<tr><td><strong>Owner:</strong></td><td>$ownerName</td></tr>"
    if($rd){
        $groupEmail += "<tr><td><strong>Read-Only Group:</td><td>$rd</td></tr>"
    }
    if($coOwner){
        $ownerEmail += "<tr><td valign=top><strong>Co-Owner(s):</strong></td><td>$coOwnerNameStash</td></tr>"
    }
    $sentDate = $(Get-Date -Format "MM/dd/yyyy")
    $subject = "Cherwell Request $ticketNum - New Shared Drive $type"
    $iamInstructions = ""
    if($type -eq "Completion"){
        $attachments = $iamInstructions;
    } 

    $query = "INSERT INTO Terminations.dbo.emailData 
    (recipientEmail,ccEmail,bccEmail,attachmentPaths,subject,messageEmail,sentDate,typeEmail) VALUES 
    ('$admin','InformationServices@sutterhealth.org','eaa@sutterhealth.org','$attachments','$subject','$message','$sentDate','$type')"
    Invoke-Sqlcmd -Query $query -ServerInstance ""
}

#This function takes in the previous made permission groups that were created, the file that was put on server '', and the file created under the departments namespace. 
#Then it creates a file under the DFS Managment, places the Permission groups as members and enumerates the file
Function DFSCreation{

param([string]$DFSfilePath, [string]$GGch, [string]$GGrd, [string]$ServerfileName)
Write-Host "Creating DFS Folder"
New-DfsnFolder -Path $DFSfilePath -TargetPath $ServerfileName >$null 2>&1   #creates new folder on DFS and sets the netApp file path
start-sleep -seconds 5
write-host "Adding $GGch to DFS..."
Grant-DfsnAccess -Path $DFSfilePath -AccountName $GGch          #adds the change GG to its membes
if([string]::IsNullOrWhiteSpace($GGrd)){
    write-host "Read-only group is empty. Will not add to DFS."
}else{
    Grant-DfsnAccess -Path $DFSfilePath -AccountName $GGrd          #adds the read Write only GG to its membes
}

dfsutil property sd grant $DFSfilePath Protect                  #hides from rest of files and only allows it members to see its content.

}

Function createWorkGroup{
    param([string]$owner, [string]$coOwner, [string]$admin, [string]$ticketNum, [string]$ch, [string]$rd )

    if($coOwner){              #check multiple owners
        $message = "Hello,<br><br>For request $ticketNum the the following Global Groups had multiple owners and a Work Group in <a href=`"http://iam.sutterhealth.org/`">iam.sutterhealth.org</a> needs to be created.<br><br>Please create work groups for<br><ul><li>$ch</li><li>$rd</li></ul><br>The following are owners:<br><ul><li>$owner</li><li>$coOwner</li>" 
        Write-Host "Co-Owners detected. Informational email sent to admin to have an IAM workgroup created."
    }
    insertEmail -admin $admin -owner $owner -coOwner $coOwner -ticketNum $ticketNum -ch $ch -rd $rd -type "Error" -message $message
}
#WARNING: if the server name changes or the permissions change they would have to be updated in this function
#this function takes in the name for the folder, and two global groups that were previously made 
#Then creates a folder on the server "" and sets its permissions. 
#This function is the hart of this script, without this function a folder will not be created, YOU MUST UPDATE THE SERVER AND PERMISSIONS IN THIS FUNCTION
Function createSharedFolder{
    param([string]$name,[string]$groupCH,[string]$groupRD)
    # Set the username so we can connect to the NetApps controller
    $username = ""
    # Set the password to use with the above username
    $passContent = "="
    # Convert the password to a secure string
    $password = ConvertTo-SecureString $passContent -AsPlainText -Force
    # Create the credential string that can be used by PowerShell
    $creds = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
    # Set the server name to place new shared folders
    $server = ""
    # Set the VServer so we can share out the folder
    $Vserver = ""
    # Set the full path to the shared folder directory
    $homePath = ""
    # Set the path to the new home folder
    $folderPath = ""
    Write-Host "Mapping PSDrive..."
    # Map a PSDrive to the homePath so we can use it to create the folder
    New-PSDrive -Name "SharedFolders" -PSProvider "FileSystem" -Root $homePath >$null 2>&1
    # Ensure that the path does not exists before creating the new folder
    if(Test-Path $folderPath){
        # Folder exists. What do?
        Write-Host -ForegroundColor Red "$folderPath exists."
    }else{
        # Folder does not exist, proceed with new folder creation
        
        New-Item -Path $homePath -Name $name -ItemType Directory >$null 2>&1
    }
    # Set the Read/Write permissions on the new folder
    # First, get the current permissions of the folder so we don't overwrite anything.
    $acl = Get-ACL -Path $folderPath
    # Set the permissions (Format: <group>,<inheritance types>,<>,<Allow/Deny>)
    
    $permission = "", "Read,Modify","Allow"
    # Create a new File System Access Rule with the new permissions
    $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permission
    # Add the rule to the ACL (Access Control List)
    #try{
        $acl.SetAccessRule($rule)
    <#}catch{
        Write-Host -ForegroundColor Red $PSItem
    }#>
    # Flush the new permissions to the disk (aka, save the changes)
    $acl | Set-Acl -Path $folderPath
    # Check if the Read-Only group was passed to the function.
    if([string]::IsNullOrWhiteSpace($groupRD)){
        # Read-Only group is null or is whitespace. Do not try to add
    }else{
        # See above comments for this.
        $acl = Get-ACL -Path $folderPath
        $permission = $groupRD, "ReadAndExecute","ContainerInherit, ObjectInherit","None","Allow"
        $rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $permission
        $acl.SetAccessRule($rule)
        $acl | Set-Acl -Path $folderPath
    }
    # Share out the folder and set the Share Permissions (the 'Everyone' group gets read/write access)
    Write-Host ""
    Connect-NcController -Name $server -Credential $creds >$null 2>&1
    Write-Host "Sharing folder..."
    Add-NcCifsShare -name $name -Path "/data$/$name" -ShareProperties oplocks, browsable, show-previous-versions -VserverContext $Vserver >$null 2>&1
    Write-Host "Setting NTFS Permissions..."
    Set-NcCifsShareAcl -Share $name -UserOrGroup Everyone -Permission Change >$null 2>&1
}

#this function takes in the file name. It will check all ther servers to make sure the file name is not already used 
function checkServer($file){

#these are all ther severs that are checked to see if the file exist on any of the servers. 
#==========================================================================================
$server1 = test-path -Path 
$server3 = test-path -Path 
$server2 = test-path -Path 
$server4 = test-path -Path 
#========================================================================================
write-host "server check $server1"#if a sever has a file with this name on it then the function returns True else it will return false. 
if($server1 -or $server2 -or $server3 -or $server4 ){ 
return $True}#end if 
else{
return $False}#end else
}#end checkServer Function 

#this function checks the AD Groups to see if the New Global Group Name is already a Group name in Use
#if the group name is used it returns "False" - else it returns "True" 
#---------
Function CheckGroupName($PermissionGroup){
    try{
        $checkGroup = Get-ADGroup -Identity $PermissionGroup  #check if group is in AD 
    }catch{
        Write-Host "$PermissionGroup not found"
        $checkGroup = $null
    }
    if($checkGroup -eq $NULL){           
        return $True     #name is not used
    }else{              
        return $False   #name Used. 
    }
}

#This Function takes in the "Permission Groups", "Owner", "coOwner", "Members", "description", "notes", "chRd" variables 
#creates the permission group and then add Owner, co-ower,members, and notes to AD
#Creates both Read-Write and Read Only Permission groups - Also Application Name 
#---------
Function InputPermissionGroupToOU{
    param([string] $permissionGroup, [string]$owner, [string[]]$coOwners,[string[]]$members, [string]$description,  [string]$notes,[string]$chRd)  #parameters input into function 

    
    #create group 
    New-ADGroup -Name $permissionGroup -DisplayName $permissionGroup -GroupScope Global -GroupCategory Security -Path "OU=" -ManagedBy $owner -Description $description -Confirm:$false
    #add notes
    Set-ADGroup -Identity $permissionGroup -Replace @{info="$notes"}
    Write-Host "$permissionGroup created, pending AD sync for 60 seconds. Stand by..."
    Start-Sleep -Seconds 60
    Write-Host "Adding owner(s) to group..."
    if($chRd -eq "yes"){                                                                #check if needs to add owner and co-owner as members 
        Add-ADGroupMember -Identity $permissionGroup -Members $($owner).trim()          #add owner to group
        if( $coOwner -ne $NULL){                                                            #check if co-owner
            foreach($user in $coOwner){                                                       #add co-owners to members of Permission Group 
                Add-ADGroupMember -Identity $permissionGroup -Members $($user).trim()
            }#end add co owners 
        }#end co Owners
    }#end chRd check 
    if( $members -ne $NULL){                                                            #check if members
        foreach($user in $members){                                                     #add members to members of permission group
            if([string]::IsNullorWhitespace($user)){
                write-host "Found a blank user."
            }else{
                write-host "Adding '$user' to $permissionGroup"
                Add-ADGroupMember -Identity $permissionGroup -Members $($user).trim()
            }
        }#add members 
    }  #end if members    
          
}#end InputPermissionGroupToOU function 

#this function takes in the global groups created and will delete them. 
#this will hapen if the file is already on a server
function deleteGG{
    param([string]$chGG, [string]$rdGG )
    Remove-ADGroup -identity $chGG -Confirm:$false
    try{
        Remove-ADGroup -identity $rdGG -Confirm:$false
    }catch{
        Write-Host "Could not delete '$rdGG' - $PSItem"
    }
}

#This function calls to server  and opens file "Provisioning" "dbo.CreateGG" With in Microsoft SQL Server Management
#Then it pulls the rows from the "dbo.CreateGG" table 
#Once Data is input from the table it checks to see if a Share drive or Application name is requesting to be made - Builds the name accordingly 
#Creates the propper Global Group names (.CH -.RD)
#Calls function CheckGroupName to ensure the new Global Groups are not already in AD - If Global groups are in AD send error email 
#Else calls InputPermissionGroupToOU Function to create Groups in AD and send completion email
#updates createConfirmed field it "dbo.CreateGG" table
Function CreateShareDrive(){

    $query = "SELECT * FROM [].[].[] WHERE createConfirmed IS NULL"
    $pGroupList = Invoke-Sqlcmd -Query $query -ServerInstance "" 

    
    forEach( $pGroup in $pGroupList){                         #$pGroup = permission group
        $notes = ($($pGroup).ticketNumber +" "+ $(Get-Date -Format "MM/dd/yyyy") + " " + $($pGroup).adminUID )  #create notes section 
        $ticket = ($pGroup).ticketNumber

	    $pNameCH = $($pGroup).displayName + ".CH" 	        #create ch group name
	    $pNameRD = $($pGroup).displayName  + ".RD"          #create rd group name
         #input Members
        $membersCH = $($($pGroup).membersListCH) -Split(";")  #cChange members
        $membersRD = $($($pGroup).membersListRD) -Split(";")  #Read only members    
	    
        $owner = $($pGroup).ownerUname   		             #owner username 
        $ownerName = $(Get-ADUser $owner | Select-Object Name).Name
        $coOwners = $($($pGroup).coOwners) -Split(";")      #Co owner members
        

        #get file name to place on server
        $displayName = $($pGroup).displayName
        $fileName = $displayName.Split('.')[$($displayName.Split('.').Count-1)]

        #get name to plave on dfs
        $DFSName = $($pGroup).displayName
        $DFSName = $DFSName.Replace(".","-")

        if((CheckGroupName($pNameCH)) -and (CheckGroupName($pNameRD))){ #Check to see if Share drive is created and if name is alread in AD
            if([string]::IsNullOrWhiteSpace($description)){
                $description = "M:\ Drive: $DFSName"
            }else{
                $description = "M:\ Drive: $DFSName // $description"
            }
            #Create Ch group   
            write-host "Creating CH group."     
		    InputPermissionGroupToOU -permissionGroup $pNameCH -owner $owner -coOwners $coOwners -members $membersCH -description $description -notes $notes -chRd "yes"

		    #Create RD Group
		    if($membersRd -ne $NULL){
			    InputPermissionGroupToOU -permissionGroup $pNameRD -owner $owner -coOwners $coOwners -members $membersRD -description $description -notes $notes -chRd "no"
			}#end if RD group 
             else{$pNameRD =""}
            
            $fileCheck = checkServer ($fileName)         #check if name is previously used

            Start-Sleep -Seconds 60 # pause system to allow the gloabal groups to run accross severs 
            #check if ther is a server with the file already on it
           
            if($fileCheck -eq $False){  
                # Create the shared folder with the appropriate permissions
                if($membersRd -eq $null){
                    createSharedFolder -name $fileName -groupCH $pNameCH
                }else{
                    createSharedFolder -name $fileName -groupCH $pNameCH -groupRD $pNameRD
                }
                #file Name for DFS function 
                $DfSfile = "\\\\$DFSName"
                $ServerfileName = "\\\\$fileName"
                if([string]::IsNullOrWhiteSpace($pNameRD)){
                    $readOnlyEmail = ""
                }else{
                    $readOnlyEmail = "<tr><td><strong>Read-Only Group</strong></td><td>$pNameRD</td></tr>"
                }
                #Call DFS Function 
                DFSCreation -DFSfilePath $DFSfile -GGch $pNameCH  -GGrd $pNameRD -ServerfileName $ServerfileName
                $message = "This email serves as confirmation that Cherwell Request # <u>$ticket</u> has been completed.<br><br>The below shared drive has been created.<br><br><table><tr><td><strong>M:\ Drive Name</strong></td><td>$DFSName</td></tr><tr><td><strong>Read/Write Group</strong></t><td>$pNameCH</td></tr>$readOnlyEmail<tr><td><strong>Owner</strong></th><td>$ownerName ($owner)</td></tr></table><br><strong>PLEASE NOTE:</strong> It is the responsibility of the owner(s) to maintain the shared drive listed above by adding and removing members as appropriate. All requests received by EAM to update the members list will be forwarded to the owner(s). If you are the owner, you can utilize <a href=`"https://iam.sutterhealth.org`">IAM</a> to add and remove users to your group(s).<br><br><strong>PLEASE NOTE:</strong> Since this shared drive is on the department drive (M:\), there is no need to map it. Simply click on <u>Start</u>, click on <u>Computer</u> then double-click on <u>Department Share (M:)</u> and find the name of the folder. The name for this folder is listed above."
                insertEmail -admin ($pGroup).adminUID -owner ($pGroup).adminUID -coOwner ($pGroup).coOwner -ticketNum ($pGroup).ticketNumber -ch $pNameCH -rd $pNameRD -message $message -type "Completion" 
            }#end "if" file check 
            #if file name is already user remove GG 
           else{
                deleteGG -chGG $pNameCH -rdGG $pNameRD
                $message = "This email is to inform you that that Cherwell Request # <u>$ticket</u> ran into issuess. The <strong>file name</strong> requested to be made is already in use, please request a new name.<br><br><table><tr><th>File Name</th><tr><td>$FileName</td></tr></table>"       
                insertEmail -admin ($pGroup).adminUID -owner ($pGroup).adminUID -coOwner ($pGroup).coOwner -ticketNum ($pGroup).ticketNumber -ch $pNameCH -rd $pNameRD -message $message -type "Failure" 
                }#end else if             
        }#end if for creating share drive
       
        else{            #gg name already used
            if($membersRd -eq $NULL){$pNameRD -eq ""}
            write-host "$pNameCH exists."
            $message = "This email is to inform you that that Cherwell Request # <u>$ticket</u> ran into issues. The <strong>global groups</strong> requested to be made are already in use, please request a new name.<br><br><table><tr><th>Global Group Name </th></tr><tr><td>$pNameCH<br>$pNameRD</td></tr></table>"
            insertEmail -admin ($pGroup).adminUID -owner ($pGroup).adminUID -coOwner ($pGroup).coOwner -ticketNum ($pGroup).ticketNumber -ch $pNameCH -rd $pNameRD -message $message -type "Failure" 
        }
        #Change null to Yes in createConfirmed column on server  -MUST TURN ON WHEN SENT TO TEST AND PROD. 
            $query = "UPDATE [].[].[] SET createConfirmed = 'Yes' WHERE id = '$($($pGroup).id)'"
            #Invoke-Sqlcmd -Query $query -ServerInstance "" 
     
	}#end foreach 

}#end CreateDl function 


CreateShareDrive
