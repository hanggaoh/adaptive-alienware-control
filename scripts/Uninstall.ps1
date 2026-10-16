[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'),[switch]$RemoveOwnedPlans)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
Import-Module (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Force
$m=Read-Manifest $StateDirectory
if($m.Uninstalled){'Already uninstalled; snapshots remain available.';return}
$owned=@();if($RemoveOwnedPlans){$owned=@(Get-SafeOwnedPlans $m)}
if(-not $PSCmdlet.ShouldProcess($StateDirectory,"Stop task and restore install snapshot; remove owned plans=$RemoveOwnedPlans")){return}
Assert-Admin
Stop-SceneTask $StateDirectory
Restore-InstallSnapshot $m.Baseline
Unregister-ScheduledTask -TaskName $script:SceneTask -Confirm:$false -ErrorAction SilentlyContinue
if($RemoveOwnedPlans){
 foreach($id in $owned){
  Invoke-PC @('/delete',$id)
 }
}
$m.Enabled=$false;$m.Uninstalled=$true
Save-Manifest $m $StateDirectory
'Controller uninstalled; original plan/power modes restored. Release files and snapshots retained for audit.'
