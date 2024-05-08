<#
.SYNOPSIS
Sample script for VMware Workspace ONE UEM REST API

.NOTES
  Version:        1.0
  Author:         Chris Halstead - chalstead@vmware.com
  Creation Date:  8/21/2019
  Purpose/Change: Initial script development
  
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#Define Variables
$listWindows = New-Object Collections.Generic.List[Int]
$listios = New-Object Collections.Generic.List[Int]
$listmac = New-Object Collections.Generic.List[Int]
$listandroid = New-Object Collections.Generic.List[Int]
$listdevices = New-Object Collections.Generic.List[string]
$winbody = "{`n  `"MessageBody`": `"TEST - Action Needed - Subscription Expiration: The Workspace ONE license on this device is expired. Contact your admin to avoid loss of access to your apps and data.`",`n  `"Application`": `"com.airwatch.workspace.one`",`n  `"MessageType`" : `"wns`"}"
$androidbody = "{`n  `"MessageBody`": `"TEST - Action Needed - Subscription Expiration: The Workspace ONE license on this device is expired. Contact your admin to avoid loss of access to your apps and data.`",`n  `"Application`": `"AirWatch Agent`",`n  `"MessageType`" : `"Push`"}"
$iosbody = "{`n  `"MessageBody`": `"TEST - Action Needed - Subscription Expiration: The Workspace ONE license on this device is expired. Contact your admin to avoid loss of access to your apps and data.`",`n  `"Application`": `"IntelligentHub`",`n  `"MessageType`" : `"Apns`"}"
$macosbody = "{`n  `"MessageBody`": `"TEST - Action Needed - Subscription Expiration: The Workspace ONE license on this device is expired. Contact your admin to avoid loss of access to your apps and data.`",`n  `"Application`": `"com.airwatch.mac.agent`",`n  `"MessageType`" : `"awcm`"}"




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

         [String]$Path = [IO.Path]::GetTempPath()
        
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

        Add-Content -Path (Join-Path $Path 'log.txt') -Value ("[{0}] ({1}) {2}" -F (Get-Date -UFormat $DateFormat), $Level, $Message)

        
     }
 }


Function SearchandMessageDevices() {


if ([string]::IsNullOrEmpty($wsoserver))
  {
    $script:WSOServer = Read-Host -Prompt 'Enter the Workspace ONE UEM API Server Name'
  
  }
 if ([string]::IsNullOrEmpty($header))
  {
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

    $script:header = @{
    "Authorization"  = "Basic $cred";
    "aw-tenant-code" = $apikey;
    "Accept"		 = "application/json;version=2";
    "Content-Type"   = "application/json";}
  }

  Write-Log "Second Message" -Level "Warning"




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

write-host "Processing: " $devicetype

try {
    
  $sresult = Invoke-RestMethod -Method Get -Uri "https://$wsoserver/api/mdm/devices/search?platform=$platform&page=0&pagesize=10" -ContentType "application/json" -Header $header

  #API/mdm/devices/search?platform=winrt&page=0&pagesize=50

}

catch {
  Write-Host "An error occurred when running script:  $_"
  break
}


if ($sresult -eq "")

{

  write-host "No $devicetype devices found"
  continue

}

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


write-host $sresult.total "$devicetype devices found"

$finalpage = [Math]::Ceiling($sresult.total / 10) 

Write-Host "Final Page $finalpage"

if ($finalpage -eq 1)

{

  switch ($devicetype)
  {
    Windows {write-host $listWindows.count "Windows Devices To Message"}
    MacOS {write-host $listmac.count "MacOS Devices To Message"}
    iOS {write-host $listios.Count  "iOS Devices To Message"}
    Android {write-host $listandroid.Count  "Android Devices To Message" }
  
  }
 
  switch ($devicetype)
  {
    Windows {

           

            }
    MacOS {


      foreach ($id in $listmac)

      {
        try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $macosbody}

        catch {Write-Host "An error occurred when running script:  $_" }


        if ($response.statuscode -eq 202)

        {

          Write-Host "Message Sent Sucessfully to Device ID $id"

        }
        
        
      }

    }
    
    iOS {  
       foreach ($id in $listandroid)

      {
        try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $androidbody}

        catch {Write-Host "An error occurred when running script:  $_" }


        if ($response.statuscode -eq 202)

        {

          Write-Host "Message Sent Sucessfully to Device ID $id"

        }
        
        
      }


  }


    Android { 
        
      foreach ($id in $listandroid)

        {
          try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $androidbody}

          catch {Write-Host "An error occurred when running script:  $_" }


          if ($response.statuscode -eq 202)

          {

            Write-Host "Message Sent Sucessfully to Device ID $id"

          }
          
          
        }


    }
  
  }

 
  continue


}

 
  #page through results

  $icount = 1

 DO

 {

  $sresult = ""

  $sresult = Invoke-RestMethod -Method Get -Uri "https://$wsoserver/api/mdm/devices/search?platform=$platform&page=$icount&pagesize=10" -ContentType "application/json" -Header $header

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
 

  switch ($devicetype)
  
  {
    Windows {write-host $listWindows.count "Windows Devices To Message"}
    MacOS {write-host $listmac.count "MacOS Devices To Message"}
    iOS {write-host $listios.Count  "iOS Devices To Message"}
    Android {write-host $listandroid.Count  "Android Devices To Message" }
  }



  switch ($devicetype)
  {
    Windows {

      continue

      foreach ($id in $listWindows)

      {
        try {$response = Invoke-WebRequest -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $winbody}

        catch {Write-Host "An error occurred when running script:  $_" }


        if ($response.statuscode -eq 202)

        {

          Write-Host "Message Sent Sucessfully to Device ID $id"

        }
        
        
      }


  }      
            
    MacOS {}
    iOS {}
    Android {
        
      foreach ($id in $listandroid)

        {

          $snotify = Invoke-RestMethod -Method Post -Uri "https://$wsoserver/api/mdm/devices/messages/push?searchby=deviceid&id=$id" -ContentType "application/json" -Header $header -Body $androidbody

          write-host $snotify
          
        }


    }
  
  }















  


  

}








}


##########
#Run Code
SearchandMessageDevices

