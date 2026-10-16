param(
 [Parameter(Mandatory)][string]$ConfigPath,
 [Parameter(Mandatory)][string]$StateDirectory,
 [ValidateRange(0,120)][int]$ValidationMinutes=0
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'PowerScenes.psm1') -Force
$cfg=Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$status=Join-Path $StateDirectory 'watcher-status.json'
$log=Join-Path $StateDirectory 'watcher.log'
$stop=Join-Path $StateDirectory 'stop'
$names=Get-RegisteredGameNames $cfg
function Subscribe([string[]]$List){
 foreach($kind in @('Start','Stop')){
  $source="Scene.$kind";Unregister-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
  Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
  $images=@($List | ForEach-Object {"$_.exe"})
  if($kind -eq 'Stop'){$images+=@($images | ForEach-Object {foreach($length in @(13,14,15)){if($_.Length -gt $length){$_.Substring(0,$length)}}})}
  $filter=($images | Sort-Object -Unique | ForEach-Object {"ProcessName='$_'"}) -join ' OR '
  $null=Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM Win32_Process${kind}Trace WHERE $filter" -SourceIdentifier $source
 }
}
$mutex=[Threading.Mutex]::new($false,'Local\QuietCodingGamePowerSwitch')
if(-not $mutex.WaitOne(0)){throw 'Another power controller is already running'}
$phase='Unknown';$due=$null;$next=[datetime]::UtcNow;$dirty=$true
$end=if($ValidationMinutes -eq 0){[datetime]::MaxValue}else{[datetime]::UtcNow.AddMinutes($ValidationMinutes)}
try{
 Subscribe $names
 $null=Register-CimIndicationEvent -Namespace root/cimv2 -ClassName Win32_PowerManagementEvent -SourceIdentifier 'Scene.Power'
 while([datetime]::UtcNow -lt $end -and -not (Test-Path -LiteralPath $stop)){
  $now=[datetime]::UtcNow
  if($dirty -or $now -ge $next -or ($due -and $now -ge $due)){
   if($now -ge $next){
    $new=Get-RegisteredGameNames $cfg
    if(($new -join '|') -ne ($names -join '|')){$names=$new;Subscribe $names}
    $next=$now.AddSeconds($cfg.FallbackSeconds)
   }
   $snapshot=Get-SceneSnapshot
   $games=@(Get-Process -Name $names -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique)
   $decision=Get-SceneTransition $phase $snapshot.OnAC $games $now $due -ExitDelaySeconds $cfg.ExitDelaySeconds
   $due=$decision.ExitDue
   if($decision.Scene -ne $phase){
    $snapshot=Invoke-Scene $decision.Scene $cfg
    $phase=$decision.Scene
    Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+" Scene=$phase; Windows plan read-back verified; Energy Saver UI and AWCC profile NOT yet verified.")
   }
   $d=Get-SceneDefinition $phase $cfg
   [pscustomobject]@{Time=(Get-Date -Format o);Phase=$phase;Snapshot=$snapshot;RunningGames=$games;RecognizedGames=$names;
    EnergySaverExpected=$d.EnergySaverExpected;EnergySaverActual='Pending UI verification';AwccExpected='User per-game/default preset';AwccActual='Pending verification';Overall='Pending';
    TrialOnly=($ValidationMinutes -gt 0);ValidationEnds=if($ValidationMinutes -gt 0){$end.ToString('o')}else{$null}
   } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $status -Encoding UTF8
   $dirty=$false
  }
  $timeout=[Math]::Max(1,[Math]::Ceiling(($next-[datetime]::UtcNow).TotalSeconds))
  if($due){$timeout=[Math]::Min($timeout,[Math]::Max(1,[Math]::Ceiling(($due-[datetime]::UtcNow).TotalSeconds)))}
  $timeout=[Math]::Min($timeout,10) # Check stop flag/deadline, without enumerating processes every 10s.
  $event=Wait-Event -Timeout ([int]$timeout)
  if($event){
   foreach($e in @(Get-Event | Where-Object SourceIdentifier -like 'Scene.*')){Remove-Event -EventIdentifier $e.EventIdentifier -ErrorAction SilentlyContinue}
   Start-Sleep -Milliseconds 500;$dirty=$true
  }
 }
}catch{
 Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+' ERROR: '+$_.Exception.Message)
 throw
}finally{
 foreach($source in @('Scene.Start','Scene.Stop','Scene.Power')){Unregister-Event -SourceIdentifier $source -ErrorAction SilentlyContinue}
 Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+' Listener stopped; current plan retained. Use Uninstall.ps1 to restore the install snapshot.')
 $mutex.ReleaseMutex();$mutex.Dispose()
}
