param(
 [Parameter(Mandatory)][ValidateSet('Battery','Coding','Gaming')][string]$Expected,
 [string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'),
 [ValidateSet('On','Off','Unknown')][string]$EnergySaverUi='Unknown',
 [Nullable[int]]$AwccExpectedMode=$null
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\scripts\Common.ps1')
Import-Module (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Force
$m=Read-Manifest $StateDirectory
if($m.Uninstalled){throw 'No active installation'}
$r=@($m.Releases | Where-Object Id -eq $m.CurrentRelease)[0]
$cfg=Get-Content (Join-Path $r.Path 'config.json') -Raw | ConvertFrom-Json
$s=Get-SceneSnapshot
$thermalError=$null
try{$thermalSnapshot=Get-SceneSnapshot -ReadThermal;$s=$thermalSnapshot}catch{$thermalError=$_.Exception.Message}
$names=Get-RegisteredGameNames $cfg
$games=@(Get-Process -Name $names -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName)
$actual=Resolve-PowerScene $s.OnAC $games
$d=Get-SceneDefinition $Expected $cfg
$overlay=if($s.OnAC){$s.OverlayAC}else{$s.OverlayDC}
$checks=@(
 [pscustomobject]@{Check='Actual supply and registered-game scene';Result=if($actual -eq $Expected){'Pass'}else{'Fail'}},
 [pscustomobject]@{Check='Active power plan';Result=if($s.Plan -eq $d.Plan){'Pass'}else{'Fail'}},
 [pscustomobject]@{Check='Active AC/DC power mode';Result=if($overlay -eq $d.Overlay){'Pass'}else{'Fail'}},
 [pscustomobject]@{Check='Energy saver UI supplied by operator';Result=if($EnergySaverUi -eq 'Unknown'){'Pending'}elseif($EnergySaverUi -eq $d.EnergySaverExpected){'Pass'}else{'Fail'}},
 [pscustomobject]@{Check='AWCC saved profile matched';Result=if($null -eq $AwccExpectedMode -or $thermalError){'Pending'}elseif($s.AwccMode -eq $AwccExpectedMode){'Pass'}else{'Fail'}}
)
$result=[pscustomobject]@{Time=(Get-Date -Format o);Expected=$Expected;Detected=$actual;Games=$games;Snapshot=$s;ThermalReadError=$thermalError;Checks=$checks;
 Overall=if(@($checks | Where-Object Result -eq 'Fail').Count){'Fail'}elseif(@($checks | Where-Object Result -eq 'Pending').Count){'Pending'}else{'Pass'};
 NoiseAndGameplay='Not certified: requires observing fan noise and actual game smoothness'}
$artifacts=Join-Path $PSScriptRoot '..\artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$result | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $artifacts ("live-$Expected.json")) -Encoding UTF8
$result | ConvertTo-Json -Depth 7
if($result.Overall -eq 'Fail'){throw 'Live acceptance failed'}
