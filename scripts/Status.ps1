param([string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'))
. (Join-Path $PSScriptRoot 'Common.ps1')
$m=Read-Manifest $StateDirectory
[pscustomobject]@{Release=$m.CurrentRelease;Enabled=$m.Enabled;Uninstalled=$m.Uninstalled;Releases=$m.Releases | Select-Object Id,Version} | ConvertTo-Json -Depth 5
Get-ScheduledTask -TaskName $script:SceneTask -ErrorAction SilentlyContinue | Select-Object TaskName,State
$status=Join-Path $StateDirectory 'watcher-status.json'
if(Test-Path -LiteralPath $status){Get-Content -LiteralPath $status}
