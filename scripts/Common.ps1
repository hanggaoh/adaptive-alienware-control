$ErrorActionPreference='Stop'
$script:SceneTask='QuietPowerScenes'
function Assert-Admin {
 $id=[Security.Principal.WindowsIdentity]::GetCurrent()
 if(-not ([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run this command from an elevated PowerShell.'}
 if([Environment]::OSVersion.Version.Build -lt 22000){throw 'Windows 11 is required.'}
}
function Invoke-PC([string[]]$Arguments){
 $output=& powercfg.exe @Arguments
 if($LASTEXITCODE -ne 0){throw "powercfg failed: $($Arguments -join ' ') $output"}
}
function Read-Manifest([string]$StateDirectory){
 $path=Join-Path $StateDirectory 'install.json'
 if(-not (Test-Path -LiteralPath $path)){throw "No installation manifest: $path"}
 Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}
function Save-Manifest($Manifest,[string]$StateDirectory){
 $path=Join-Path $StateDirectory 'install.json'
 $temporary=Join-Path $StateDirectory 'install.json.tmp'
 $Manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $temporary -Encoding UTF8
 Move-Item -LiteralPath $temporary -Destination $path -Force
}
function Stop-SceneTask([string]$StateDirectory){
 $task=Get-ScheduledTask -TaskName $script:SceneTask -ErrorAction SilentlyContinue
 if(-not $task){return}
 Disable-ScheduledTask -TaskName $script:SceneTask | Out-Null
 New-Item -ItemType File -Path (Join-Path $StateDirectory 'stop') -Force | Out-Null
 for($i=0;$i -lt 12;$i++){
  if((Get-ScheduledTask -TaskName $script:SceneTask).State -ne 'Running'){return}
  Start-Sleep -Seconds 1
 }
 Stop-ScheduledTask -TaskName $script:SceneTask
}
function Assert-NoOtherControllers {
 $legacy=Get-ScheduledTask -TaskName 'QuietCoding-GamePowerSwitch' -ErrorAction SilentlyContinue
 if($legacy -and $legacy.State -eq 'Running'){throw 'Legacy watcher is running; stop it before enabling.'}
 $mutex=[Threading.Mutex]::new($false,'Local\QuietCodingGamePowerSwitch')
 try{if(-not $mutex.WaitOne(0)){throw 'Another power controller is running.'};$mutex.ReleaseMutex()}finally{$mutex.Dispose()}
}
function Set-SceneTask($Release,[string]$StateDirectory,[switch]$Enable){
 $exe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $watcher=Join-Path $Release.Path 'src\Watch-Scenes.ps1'
 $config=Join-Path $Release.Path 'config.json'
 if(-not (Test-Path -LiteralPath $watcher) -or -not (Test-Path -LiteralPath $config)){throw 'Release files are missing.'}
 if($Enable){Assert-NoOtherControllers}
 $arguments='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$watcher+'" -ConfigPath "'+$config+'" -StateDirectory "'+$StateDirectory+'"'
 $action=New-ScheduledTaskAction -Execute $exe -Argument $arguments
 $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
 $trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
 $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([timespan]::Zero) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
 Register-ScheduledTask -TaskName $script:SceneTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Description 'Experimental three-scene Windows power control; AWCC owns thermal profiles.' -Force | Out-Null
 Disable-ScheduledTask -TaskName $script:SceneTask | Out-Null
 if($Enable){
  $stop=Join-Path $StateDirectory 'stop'
  if(Test-Path -LiteralPath $stop){Remove-Item -LiteralPath $stop}
  Enable-ScheduledTask -TaskName $script:SceneTask | Out-Null
  Start-ScheduledTask -TaskName $script:SceneTask
 }
}
function Set-SnapshotOverlay([string]$Side,[string]$Id){
 $null=Get-SceneSnapshot
 $guid=[guid]$Id
 $code=if($Side -eq 'AC'){[SceneNative]::PowerSetUserConfiguredACPowerMode([ref]$guid)}else{[SceneNative]::PowerSetUserConfiguredDCPowerMode([ref]$guid)}
 if($code -ne 0){throw "Could not restore $Side power mode: $code"}
}
function Restore-InstallSnapshot($Snapshot){
 Invoke-PC @('/setactive',$Snapshot.Plan)
 foreach($side in @('AC','DC')){
  $id=if($side -eq 'AC'){$Snapshot.OverlayAC}else{$Snapshot.OverlayDC}
  Set-SnapshotOverlay $side $id
 }
 # No EnergySaverState registry writes or AWCC writes, including during uninstall.
}
function Get-SafeOwnedPlans($Manifest){
 $protected=@($Manifest.Baseline.Plan,'381b4222-f694-41f0-9685-ff5bb260df2e','a1841308-3541-4fab-bc81-f71556f20b4a','8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c')
 $plans=@($Manifest.Releases | ForEach-Object {$_.Plans} | Sort-Object -Unique)
 foreach($id in $plans){
  $value=([guid]$id).ToString()
  if($value -in $protected){throw 'Refusing to delete a protected/original plan.'}
  $value
 }
}
