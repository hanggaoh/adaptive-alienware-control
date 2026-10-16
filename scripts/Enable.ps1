[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'))
. (Join-Path $PSScriptRoot 'Common.ps1')
$m=Read-Manifest $StateDirectory
if($m.Uninstalled){throw 'Installation is uninstalled; install again before enabling.'}
$r=@($m.Releases | Where-Object Id -eq $m.CurrentRelease)[0]
if(-not $PSCmdlet.ShouldProcess($m.CurrentRelease,'Enable experimental scene controller')){return}
Assert-Admin
Stop-SceneTask $StateDirectory
Set-SceneTask $r $StateDirectory -Enable
$m.Enabled=$true;Save-Manifest $m $StateDirectory
