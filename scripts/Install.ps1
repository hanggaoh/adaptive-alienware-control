[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [string]$InstallDirectory=(Join-Path $env:ProgramFiles 'QuietPowerScenes'),
 [string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'),
 [guid]$QuietTemplateGuid=[guid]::Empty,
 [switch]$Enable
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $repo 'src\PowerScenes.psm1') -Force
Import-Module (Join-Path $repo 'src\HardwareAdapters.psm1') -Force
$hardware=Get-CimInstance Win32_ComputerSystem
$adapter=Resolve-HardwareAdapter -Manufacturer $hardware.Manufacturer -Model $hardware.Model -CatalogDirectory (Join-Path $repo 'config\hardware')
Assert-ThermalBackend $adapter
$version=(Get-Content (Join-Path $repo 'VERSION') -Raw).Trim()
if(-not $PSCmdlet.ShouldProcess($InstallDirectory,"Install $version; create three owned plans and task; enabled=$Enable")){return}
Assert-Admin
$policyPath=[IO.Path]::GetFullPath((Join-Path $repo $adapter.Policy))
if(-not $policyPath.StartsWith($repo+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Policy path must stay inside the repository'}
$profiles=Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$games=Get-Content (Join-Path $repo 'config\games.json') -Raw | ConvertFrom-Json
if($profiles.SchemaVersion -ne 1){throw 'Unsupported profile schema'}
$previous=$null
if(Test-Path -LiteralPath (Join-Path $StateDirectory 'install.json')){$previous=Read-Manifest $StateDirectory}
if(-not $previous -and (Get-ScheduledTask -TaskName $script:SceneTask -ErrorAction SilentlyContinue)){throw 'Task name already exists without this install manifest; refusing to overwrite it.'}
if($previous -and $previous.Uninstalled){throw 'This state directory is archived after uninstall. Use a new -StateDirectory for a new installation cycle; do not overwrite its restore snapshot.'}
$snapshot=Get-SceneSnapshot
$baseline=if($previous){$previous.Baseline}else{$snapshot}
$releaseId=(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')+'-'+$version
$releasePath=Join-Path (Join-Path $InstallDirectory 'releases') $releaseId
New-Item -ItemType Directory -Path $StateDirectory,$releasePath -Force | Out-Null
if(-not $previous){
 $snapshot | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $StateDirectory 'before-install.json') -Encoding UTF8
 Invoke-PC @('/export',(Join-Path $StateDirectory 'before-install.pow'),$snapshot.Plan)
}
Stop-SceneTask $StateDirectory
$created=@()
try{
 $balanced='381b4222-f694-41f0-9685-ff5bb260df2e'
 $template=$balanced
 if($QuietTemplateGuid -ne [guid]::Empty){$template=$QuietTemplateGuid.ToString()}
 elseif($adapter.Id -eq 'alienware-x17-r2'){
  $found=@(Get-CimInstance -Namespace root/cimv2/power -ClassName Win32_PowerPlan | Where-Object ElementName -eq 'Quiet Coding')
  if($found.Count -eq 1 -and $found[0].InstanceID -match '\{([a-fA-F0-9-]{36})\}'){$template=$Matches[1]}
 }
 $ids=@{}
 foreach($scene in @('Battery','Coding','Gaming')){
  $id=[guid]::NewGuid().ToString();$ids[$scene]=$id
  $base=if($scene -eq 'Gaming'){$balanced}else{$template}
  Invoke-PC @('/duplicatescheme',$base,$id);$created+=$id
  Invoke-PC @('/changename',$id,"APS $scene $version","Owned by QuietPowerScenes release $releaseId")
  foreach($side in @('AC','DC')){
   foreach($setting in $profiles.$scene.$side.PSObject.Properties){
    if($setting.Name -notmatch '^[A-Z0-9_]+$' -or [int]$setting.Value -lt 0 -or [int]$setting.Value -gt 100){throw 'Invalid processor profile setting'}
    Invoke-PC @("/set$($side.ToLower())valueindex",$id,'sub_processor',$setting.Name,[string]$setting.Value)
   }
   $threshold=if($side -eq 'AC'){$profiles.EnergySaver.ACThreshold}else{$profiles.EnergySaver.DCThreshold}
   Invoke-PC @("/set$($side.ToLower())valueindex",$id,'sub_energysaver','ESBATTTHRESHOLD',[string]$threshold)
   Invoke-PC @("/set$($side.ToLower())valueindex",$id,'sub_energysaver','ESPOLICY',[string]$profiles.EnergySaver.Policy)
   Invoke-PC @("/set$($side.ToLower())valueindex",$id,'sub_buttons','lidaction',[string]$profiles.Shared.LidAction)
   Invoke-PC @("/set$($side.ToLower())valueindex",$id,'sub_video','videoidle',[string]$profiles.Shared.DisplayIdleSeconds)
  }
 }
 New-Item -ItemType Directory -Path (Join-Path $releasePath 'src') -Force | Out-Null
 Copy-Item -LiteralPath (Join-Path $repo 'src\PowerScenes.psm1'),(Join-Path $repo 'src\Watch-Scenes.ps1') -Destination (Join-Path $releasePath 'src')
 Copy-Item -LiteralPath (Join-Path $repo 'VERSION'),(Join-Path $repo 'config\profiles.json'),(Join-Path $repo 'config\games.json') -Destination $releasePath
 Copy-Item -LiteralPath $policyPath -Destination (Join-Path $releasePath 'profiles.json') -Force
 $adapter | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $releasePath 'hardware.json') -Encoding UTF8
 $libraries=@()
 if($games.DiscoverAwccLibraries){$libraries=@((Join-Path $env:ProgramData 'Alienware\Alienware Command Center\GameLibrary\GameLibrary.json'),(Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center\GameLibrary\GameLibrary.json'))}
 $config=[pscustomobject]@{Version=3;BatteryPlan=$ids.Battery;QuietPlan=$ids.Coding;GamePlan=$ids.Gaming;GameProcesses=@($games.GameProcesses);GameLibraries=$libraries;
  AlwaysEnergySaverMustBeOff=$true;FallbackSeconds=[int]$profiles.Timing.FallbackSeconds;ExitDelaySeconds=[int]$profiles.Timing.ExitDelaySeconds}
 $config | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $releasePath 'config.json') -Encoding UTF8
 $release=[pscustomobject]@{Id=$releaseId;Version=$version;Path=$releasePath;Plans=@($created)}
 $history=@();if($previous){$history=@($previous.Releases)};$history+=$release
 $manifest=[pscustomobject]@{SchemaVersion=1;CurrentRelease=$releaseId;Baseline=$baseline;Releases=$history;Enabled=[bool]$Enable;Uninstalled=$false}
 Save-Manifest $manifest $StateDirectory
 Set-SceneTask $release $StateDirectory -Enable:$Enable
 [pscustomobject]@{Release=$releaseId;Installed=$true;Enabled=[bool]$Enable;StateDirectory=$StateDirectory;RuntimeConfig=(Join-Path $releasePath 'config.json')}
}catch{
 $failure=$_
 try{Stop-SceneTask $StateDirectory;Restore-InstallSnapshot $snapshot}catch{Write-Warning 'Automatic recovery failed; retain before-install snapshot.'}
 foreach($id in $created){try{Invoke-PC @('/delete',$id)}catch{Write-Warning "Plan retained for recovery: $id"}}
 if($previous){try{
  $old=@($previous.Releases | Where-Object Id -eq $previous.CurrentRelease)[0]
  Set-SceneTask $old $StateDirectory -Enable:$previous.Enabled
 }catch{$previous.Enabled=$false;Write-Warning 'Previous task could not be resumed; it remains disabled.'}
 Save-Manifest $previous $StateDirectory}
 else{
  Unregister-ScheduledTask -TaskName $script:SceneTask -Confirm:$false -ErrorAction SilentlyContinue
  [pscustomobject]@{Failed=$true;Error=$failure.Exception.Message;Snapshot=$snapshot} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $StateDirectory 'failed-install.json') -Encoding UTF8
  $marker=Join-Path $StateDirectory 'install.json'
  if(Test-Path -LiteralPath $marker){Move-Item -LiteralPath $marker -Destination (Join-Path $StateDirectory ('failed-manifest-'+$releaseId+'.json'))}
 }
 throw $failure
}
