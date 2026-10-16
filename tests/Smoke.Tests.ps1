$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$files=Get-ChildItem -LiteralPath $repo -Recurse -File | Where-Object {$_.Extension -in @('.ps1','.psm1') -and $_.FullName -notmatch '\\(artifacts|local)\\'}
foreach($f in $files){
 $tokens=$null;$errors=$null
 [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors) | Out-Null
 if($errors.Count){$errors | Format-List;throw "Syntax error: $($f.FullName)"}
}
$profiles=Get-Content (Join-Path $repo 'config\profiles.json') -Raw | ConvertFrom-Json
if($profiles.SchemaVersion -ne 1){throw 'Unexpected policy schema'}
if($profiles.EnergySaver.ACThreshold -ne 0 -or $profiles.EnergySaver.DCThreshold -ne 100){throw 'Unexpected energy-saver policy'}
if($profiles.Battery.DC.PERFBOOSTMODE -ne 0){throw 'Battery turbo should remain disabled'}
if(@($profiles.Gaming.AC.PSObject.Properties).Count -ne 0){throw 'Gaming must inherit native Balanced CPU settings'}
if($profiles.Timing.FallbackSeconds -lt 10 -or $profiles.Timing.ExitDelaySeconds -lt 0){throw 'Unsafe timing policy'}
Import-Module (Join-Path $repo 'src\PowerScenes.psm1') -Force
$before=Get-SceneSnapshot
& (Join-Path $repo 'scripts\Install.ps1') -WhatIf
$after=Get-SceneSnapshot
if($before.Plan -ne $after.Plan -or $before.OverlayAC -ne $after.OverlayAC -or $before.OverlayDC -ne $after.OverlayDC){throw 'Install -WhatIf changed power settings'}
$common=Get-Content (Join-Path $repo 'scripts\Common.ps1') -Raw
if($common -match 'Set-ItemProperty|New-ItemProperty|Thermal_Control'){throw 'Lifecycle helper must not write saver flags or thermal profiles'}
"Parsed $($files.Count) PowerShell files; profiles and non-mutating install preview passed."
