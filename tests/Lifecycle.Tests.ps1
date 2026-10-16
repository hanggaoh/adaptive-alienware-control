# Mocked task lifecycle tests: no real task registration or power-setting writes.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\scripts\Common.ps1')
$root=Join-Path $PSScriptRoot '..\artifacts\lifecycle'
$release=[pscustomobject]@{Path=$root}
New-Item -ItemType Directory -Path (Join-Path $root 'src') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\src\Watch-Scenes.ps1') -Destination (Join-Path $root 'src\Watch-Scenes.ps1')
@{Fixture=$true} | ConvertTo-Json | Set-Content (Join-Path $root 'config.json') -Encoding UTF8
$script:calls=[Collections.Generic.List[string]]::new()
function New-ScheduledTaskAction {param($Execute,$Argument);[pscustomobject]@{Execute=$Execute;Argument=$Argument}}
function New-ScheduledTaskPrincipal {param($UserId,$LogonType,$RunLevel);[pscustomobject]@{RunLevel=$RunLevel}}
function New-ScheduledTaskTrigger {param([switch]$AtLogOn,$User);[pscustomobject]@{User=$User}}
function New-ScheduledTaskSettingsSet {param([switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries,$ExecutionTimeLimit,$MultipleInstances,$RestartCount,$RestartInterval);[pscustomobject]@{Fixture=$true}}
function Register-ScheduledTask {param($TaskName,$Action,$Principal,$Trigger,$Settings,$Description,[switch]$Force);$script:calls.Add('Register');if($Action.Argument -notmatch 'Watch-Scenes.ps1') {throw 'Wrong task action'}}
function Disable-ScheduledTask {param($TaskName);$script:calls.Add('Disable')}
function Enable-ScheduledTask {param($TaskName);$script:calls.Add('Enable')}
function Start-ScheduledTask {param($TaskName);$script:calls.Add('Start')}
function Assert-NoOtherControllers {$script:calls.Add('ConflictCheck')}
Set-SceneTask $release $root
if(($script:calls -join ',') -ne 'Register,Disable'){throw 'Install must create a disabled task by default'}
$script:calls.Clear()
Set-SceneTask $release $root -Enable
if(($script:calls -join ',') -ne 'ConflictCheck,Register,Disable,Enable,Start'){throw 'Conflict check must precede mutation and enabling must be explicit'}
$script:calls.Clear()
function Assert-NoOtherControllers {throw 'Simulated conflicting controller'}
$failed=$false
try{Set-SceneTask $release $root -Enable}catch{$failed=$true}
if(-not $failed -or $script:calls.Count -ne 0){throw 'A conflicting controller must prevent task mutation'}
$script:calls.Clear()
function Invoke-PC {param([string[]]$Arguments);$script:calls.Add('PC:'+($Arguments -join ' '))}
function Set-SnapshotOverlay {param([string]$Side,[string]$Id);$script:calls.Add("Overlay:$Side=$Id")}
$snapshot=[pscustomobject]@{Plan='11111111-1111-1111-1111-111111111111';OverlayAC='00000000-0000-0000-0000-000000000000';OverlayDC='961cc777-2547-4f9d-8174-7d86181b8a7a'}
Restore-InstallSnapshot $snapshot
if(($script:calls -join ',') -ne 'PC:/setactive 11111111-1111-1111-1111-111111111111,Overlay:AC=00000000-0000-0000-0000-000000000000,Overlay:DC=961cc777-2547-4f9d-8174-7d86181b8a7a'){throw 'Snapshot restore did not restore plan before both overlays'}
$manifest=[pscustomobject]@{Baseline=$snapshot;Releases=@([pscustomobject]@{Plans=@('22222222-2222-2222-2222-222222222222')})}
if(@(Get-SafeOwnedPlans $manifest)[0] -ne '22222222-2222-2222-2222-222222222222'){throw 'Owned plan selection failed'}
foreach($protected in @($snapshot.Plan,'381b4222-f694-41f0-9685-ff5bb260df2e')){
 $manifest.Releases[0].Plans=@($protected);$rejected=$false
 try{$null=Get-SafeOwnedPlans $manifest}catch{$rejected=$true}
 if(-not $rejected){throw 'Protected plan was not rejected before deletion'}
}
'7 mocked lifecycle checks passed: task enable/disable/conflicts, restoration order, owned plan selection and protected-plan guards.'
