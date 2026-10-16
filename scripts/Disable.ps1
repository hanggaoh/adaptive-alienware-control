[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'))
. (Join-Path $PSScriptRoot 'Common.ps1')
Import-Module (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Force
$m=Read-Manifest $StateDirectory
if(-not $PSCmdlet.ShouldProcess($StateDirectory,'Disable listener and restore original Windows power settings')){return}
Assert-Admin
Stop-SceneTask $StateDirectory
Restore-InstallSnapshot $m.Baseline
$m.Enabled=$false;Save-Manifest $m $StateDirectory
