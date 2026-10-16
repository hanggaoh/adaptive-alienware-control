$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Force
$results=@()
function Check([string]$Name,[scriptblock]$Test){
    try{if(-not (& $Test)){throw 'Assertion returned false'};$script:results+=[pscustomobject]@{Test=$Name;Passed=$true}}
    catch{$script:results+=[pscustomobject]@{Test=$Name;Passed=$false;Error=$_.Exception.Message}}
}
$cfg=[pscustomobject]@{BatteryPlan='battery';QuietPlan='quiet';GamePlan='game'}
$now=[datetime]'2026-01-01T00:00:00Z'
Check 'Battery without game -> Battery' {(Resolve-PowerScene $false @()) -eq 'Battery'}
Check 'Battery with game -> Battery (battery has priority)' {(Resolve-PowerScene $false @('game')) -eq 'Battery'}
Check 'AC without game -> Coding' {(Resolve-PowerScene $true @()) -eq 'Coding'}
Check 'AC with one registered game -> Gaming' {(Resolve-PowerScene $true @('game')) -eq 'Gaming'}
Check 'AC with multiple games -> Gaming' {(Resolve-PowerScene $true @('a','b')) -eq 'Gaming'}
Check 'Unplug during game -> Battery immediately' {(Get-SceneTransition Gaming $false @('a') $now).Scene -eq 'Battery'}
Check 'Plug in with game running -> Gaming' {(Get-SceneTransition Battery $true @('a') $now).Scene -eq 'Gaming'}
Check 'Plug in with no game -> Coding' {(Get-SceneTransition Battery $true @() $now).Scene -eq 'Coding'}
Check 'Game exit starts debounce' {$r=Get-SceneTransition Gaming $true @() $now;$r.Scene -eq 'Gaming' -and $r.ExitDue -eq $now.AddSeconds(15)}
Check 'Game exit before deadline stays Gaming' {(Get-SceneTransition Gaming $true @() $now.AddSeconds(10) $now.AddSeconds(15)).Scene -eq 'Gaming'}
Check 'All games exited past deadline -> Coding' {(Get-SceneTransition Gaming $true @() $now.AddSeconds(16) $now.AddSeconds(15)).Scene -eq 'Coding'}
Check 'Second game keeps Gaming and cancels exit delay' {$r=Get-SceneTransition Gaming $true @('b') $now $now.AddSeconds(15);$r.Scene -eq 'Gaming' -and $null -eq $r.ExitDue}
Check 'Steam launcher is not a game' {$null -eq (ConvertTo-GameImage 'C:\Steam\steam.exe')}
Check 'Python/Torch is not automatically a game' {$null -eq (ConvertTo-GameImage 'C:\Python\python.exe')}
Check 'Game update folder does not change process recognition' {(ConvertTo-GameImage 'C:\WindowsApps\NewVersion\forzahorizon6.exe') -eq 'forzahorizon6'}
Check 'Battery definition expects real Energy saver On' {(Get-SceneDefinition Battery $cfg).EnergySaverExpected -eq 'On'}
Check 'Game definition expects real Energy saver Off' {(Get-SceneDefinition Gaming $cfg).EnergySaverExpected -eq 'Off'}
Check 'Coding uses tuned quiet plan, not battery plan' {(Get-SceneDefinition Coding $cfg).Plan -eq 'quiet'}
Check 'Gaming uses native Balanced power mode, not aggressive overlay' {(Get-SceneDefinition Gaming $cfg).Overlay -eq [guid]::Empty.ToString()}
Check 'AWCC owns gaming thermal profiles' {(Get-SceneDefinition Gaming $cfg).ThermalOwner -eq 'AWCC'}
Check 'Custom exit delay is respected' {(Get-SceneTransition Gaming $true @() $now $null -ExitDelaySeconds 3).ExitDue -eq $now.AddSeconds(3)}
Check 'No registry-based Energy saver writer' {(Get-Content (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Raw) -notmatch 'Set-ItemProperty|New-ItemProperty'}
Check 'No firmware thermal or fan write' {(Get-Content (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Raw) -notmatch 'MethodName Thermal_Control|SetFanBoost'}
$artifacts=Join-Path $PSScriptRoot '..\artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $artifacts 'unit-test-results.json') -Encoding UTF8
$results | Format-Table -AutoSize
if(@($results | Where-Object {-not $_.Passed}).Count){throw 'Some tests failed'}
"Passed $($results.Count) logic tests. This does NOT certify live Energy Saver, AWCC recognition, fan noise or game performance."
