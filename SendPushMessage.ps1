<#
.SYNOPSIS
Send Push Notifications to all Devices in a UEM Tenant

.NOTES
  Version:        1.0
  Author:         Chris Halstead - chalstead@vmware.com
  Creation Date:  5/10/2024
  Purpose/Change: Initial script development
  
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#Define Variables
$messagetosend = "Action Needed - Subscription Expiration: The Workspace ONE license on this device is expired. Contact your admin to avoid loss of access to your apps and data."
$listWindows = New-Object Collections.Generic.List[Int]
$listios = New-Object Collections.Generic.List[Int]
$listmac = New-Object Collections.Generic.List[Int]
$listandroid = New-Object Collections.Generic.List[Int]
$listdevices = New-Object Collections.Generic.List[string]
$winbody = "{`n  `"MessageBody`":  `"$($messagetosend)`",`n  `"Application`": `"com.airwatch.workspace.one`",`n  `"MessageType`" : `"wns`"}"
$androidbody = "{`n  `"MessageBody`":`"$($messagetosend)`",`n  `"Application`": `"AirWatch Agent`",`n  `"MessageType`" : `"Push`"}"
$iosbody = "{`n  `"MessageBody`": `"$($messagetosend)`",`n  `"Application`": `"IntelligentHub`",`n  `"MessageType`" : `"Apns`"}"
$macosbody = "{`n  `"MessageBody`": `"$($messagetosend)`",`n  `"Application`": `"com.airwatch.mac.agent`",`n  `"MessageType`" : `"awcm`"}"
$pagesize = "500"



#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Write-Log {
  [CmdletBinding()]

     Param (
         [Parameter(
             Mandatory=$true,
             ValueFromPipeline=$true,
             Position=0)]
         [ValidateNotNullorEmpty()]
         [String]$Message,

       [Parameter(Position=1)]
         [ValidateSet("Information","Warning","Error","Debug","Verbose")]
         [String]$Level = 'Information',

         [String]$script:Path = [IO.Path]::GetTempPath()
        
           )

     Process {
         $DateFormat = "%m/%d/%Y %H:%M:%S"

         If (-Not $NoHost) {
           Switch ($Level) {
             "information" {
               Write-Host ("[{0}] {1}" -F (Get-Date -UFormat $DateFormat), $Message)
               Break
             }
             "warning" {
               Write-Warning ("[{0}] {1}" -F (Get-Date -UFormat $DateFormat), $Message)
               Break
             }
             "error" {
               Write-Error ("[{0}] {1}" -F (Get-Date -UFormat $DateFormat), $Message)
               Break
             }
             "debug" {
               Write-Debug ("[{0}] {1}" -F (Get-Date -UFormat $DateFormat), $Message) -Debug:$true
               Break
             }
             "verbose" {
               Write-Verbose ("[{0}] {1}" -F (Get-Date -UFormat $DateFormat), $Message) -Verbose:$true
               Break
             }
           }
         }


        $logDateFormat = "%m_%d_%Y"
        $sdate = Get-Date -UFormat $logDateFormat

        $script:logfilename = "uem-nofify-$sdate.log"
       
        Add-Content -Path (Join-Path $Path $logfilename) -Value ("[{0}] ({1}) {2}" -F (Get-Date -UFormat $DateFormat), $Level, $Message)

        
     }
 }


Function SearchandMessageDevices() {


    $WSOServer = Read-Host -Prompt 'Enter the Workspace ONE UEM API Server Name'
    $oguuid = Read-Host -Prompt 'Enter the UUID of the OG to search'
    $Username = Read-Host -Prompt 'Enter the Username'
    $Password = Read-Host -Prompt 'Enter the Password' -AsSecureString
    $apikey = Read-Host -Prompt 'Enter the API Key'
    
    #Convert the Password
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    #Base64 Encode AW Username and Password
    $combined = $Username + ":" + $UnsecurePassword
    $encoding = [System.Text.Encoding]::ASCII.GetBytes($combined)
    $cred = [Convert]::ToBase64String($encoding)

    $header = @{
    "Authorization"  = "Basic $cred";
    "aw-tenant-code" = $apikey;
    "Accept"		 = "application/json;version=3";
    "Content-Type"   = "application/json;version=3";}

  Write-Log "Starting Script" -Level Information
  Write-Log "Log file $script:path$script:logfilename" -Level Information
  Write-Log "Searching $wsoserver" -Level Information
  Write-Log "Message to be pushed to the Devices: $messagetosend" -Level Information

  try {
    
    $sog = Invoke-RestMethod -Method Get -Uri "https://$wsoserver/API/system/groups/$oguuid" -ContentType "application/json" -Header $header
  
  }
  
  catch {
    Write-Log "An error occurred when searching OGs:  $_" -Level "Warning"
    exit
  
  }

  $ogfn = $sog.name

  Write-Log "Selected Organization Group: $ogfn" Information

  $listdevices.add("Android")
  $listdevices.add("Windows")
  $listdevices.add("iOS")
  $listdevices.add("MacOS")


 foreach ($os in $listdevices) 

 {

$devicetype = $os

 $platform = switch ($devicetype)
  {
      Windows {"Winrt" }
      MacOS {"appleosx"}
      iOS {"apple"}
      Android {"Android" }
  
  }

write-log "Processing: $devicetype" -Level Information

try {
    
  $sresult = Invoke-RestMethod -Method Get -Uri "https://$wsoserver/api/mdm/devices/search?organization_group_uuid=$oguuid&device_type=$platform&page=0&pagesize=$pagesize" -ContentType "application/json" -Header $header

}

catch {
  Write-Log "An error occurred when searching devices:  $_" -Level "Warning"
  exit

}


if ($sresult -eq "")

{

  Write-Log "No $devicetype devices found" -Level Information
  continue

}

Write-Log "OG Name: $ogfn"

foreach ($deviceid in $sresult.devices.id.value)

    {

    
  switch ($devicetype)
  
    {
      Windows {$listWindows.add($deviceid)}
      MacOS {$listmac.add($deviceid)}
      iOS {$listios.add($deviceid)}
      Android {$listandroid.add($deviceid) }
    }
 
    
  }


$itotal = ""

$itotal = $sresult.Total

Write-Log "$itotal $devicetype devices found" -Level Information

$finalpage = [Math]::Ceiling($sresult.total / $pagesize) 

Write-Log "Final Page:  $finalpage" -Level Verbose

if ($finalpage -eq 1)

{

#Finished - do nothing 


}

else

{
 
  #page through results

  $icount = 1

 DO

 {

  $sresult = ""

  $sresult = Invoke-RestMethod -Method Get -Uri "https://$wsoserver/api/mdm/devices/search?platform=$platform&page=$icount&pagesize=$pagesize" -ContentType "application/json" -Header $header

  foreach ($deviceid in $sresult.devices.id.value)

    {

      switch ($devicetype)
      {
          Windows {$listWindows.add($deviceid)}
          MacOS {$listmac.add($deviceid)}
          iOS {$listios.add($deviceid)}
          Android {$listandroid.add($deviceid) }
      
      }
 
    }

      # Increment the counter
      $icount++

  
  }  until($icount-eq $finalpage)
    
  
  }

}


#Prompt if want to send notification

switch ($devicetype)
  
  {
    Windows {Write-Log "Total Windows Devices: $($listWindows.Count)" -Level Information}
    MacOS {write-log "Total MacOS Devices: $($listmac.Count)" -Level Information}
    iOS {Write-Log "Total iOS Devices: $($listios.Count)" -Level Information}
    Android {Write-Log "Total Android Devices: $($listandroid.Count)" -Level Information}
  }

$icountdevices = $listwindows.count + $listmac.count + $listios.count + $listandroid.count

if ($icountdevices -eq 0)

{
 Write-Log "No devices found - Exiting"
 break
}

$squestion = "Are you sure you want to send notifications to $icountdevices devices in the $ogfn OG (and Sub OGs) on $wsoserver ?"

 # Clear-Host
$answer = $Host.UI.PromptForChoice('Send Notifications?', $squestion, @('&Yes', '&No'), 1)

if ($answer -eq 0) {
    #yes
    Write-Host 'Sending Notifications'
}else{
    
  Write-Log "Script Execution Complete - No Notifications Sent" Information
    
    break
}



$ilimit = 1


foreach ($device in $listdevices)

{

  switch ($device)
  {
    Windows {

      foreach ($id in $listWindows)

      {

        $ilimit++

        if ($ilimit -eq 150)

        {Write-Log "Pausing 5 seconds after 150 Devices" Verbose
         
        Start-Sleep -Seconds 5

        $ilimit = 0 }

        try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $winbody}

        catch {{Write-Log "An error occurred when sendinng push notification to Windows Device ID $id :  $_" -Level Error }}


        if ($response.statuscode -eq 202)

        {

          Write-Log "Message Sent Sucessfully to Windows Device ID $id" -Level Information

        }
        
        
      }

            }
    MacOS {


      foreach ($id in $listmac)

      {

        $ilimit++

        if ($ilimit -eq 150)

        {Write-Log "Pausing 5 seconds after 150 Devices" Verbose
         
        Start-Sleep -Seconds 5

        $ilimit = 0 }

        try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $macosbody}

        catch {Write-Log "An error occurred when sendinng push notification to MacOS Device ID $id :  $_" -Level Error }


        if ($response.statuscode -eq 202)

        {

          Write-Log "Message Sent Sucessfully to MacOS Device ID $id" -Level Information

        }
        
        
      }

    }
    
    iOS {  
       foreach ($id in $listios)

      {

        $ilimit++

        if ($ilimit -eq 150)

        {Write-Log "Pausing 5 seconds after 150 Devices" Verbose
         
        Start-Sleep -Seconds 5

        $ilimit = 0 }

        try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $iosbody}

        catch {Write-Log "An error occurred when sendinng push notification to iOS Device ID $id :  $_" -Level Error }


        if ($response.statuscode -eq 202)

        {

          Write-log "Message Sent Sucessfully to iOS Device ID $id" -Level Information

        }
        
       
        
      }

     

  }


    Android { 
        
      foreach ($id in $listandroid)

        {

          $ilimit++

          if ($ilimit -eq 150)
  
          {Write-Log "Pausing 5 seconds after 150 Devices" Verbose
           
          Start-Sleep -Seconds 5
  
          $ilimit = 0 }

          try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $androidbody}

          catch {Write-Log "An error occurred when sendinng push notification to Android Device ID $id :  $_" -Level Error }

          if ($response.statuscode -eq 202)

          {

            Write-Log "Message Sent Sucessfully to Android Device ID $id" -Level Information

          }
          
          
        }


    }

  }
  
  }

Write-Log "Script Execution Complete" Information

}


##########
#Run Code
SearchandMessageDevices

