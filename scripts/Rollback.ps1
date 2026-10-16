[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$ReleaseId,[string]$StateDirectory=(Join-Path $env:ProgramData 'QuietPowerScenes'),[switch]$Enable)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
Import-Module (Join-Path $PSScriptRoot '..\src\PowerScenes.psm1') -Force
$m=Read-Manifest $StateDirectory
if($m.Uninstalled){throw 'Installation has been uninstalled; run Install.ps1 for a new installation.'}
if(-not $ReleaseId){
 $index=-1;for($i=0;$i -lt $m.Releases.Count;$i++){if($m.Releases[$i].Id -eq $m.CurrentRelease){$index=$i}}
 if($index -le 0){throw 'No earlier installed release exists.'}
 $ReleaseId=$m.Releases[$index-1].Id
}
$matches=@($m.Releases | Where-Object Id -eq $ReleaseId)
if($matches.Count -ne 1){throw 'Release ID must name exactly one recorded installation.'}
$target=$matches[0]
if(-not $PSCmdlet.ShouldProcess($ReleaseId,"Switch installed release; enabled=$Enable")){return}
Assert-Admin
foreach($plan in $target.Plans){Invoke-PC @('/query',[string]$plan)}
Stop-SceneTask $StateDirectory
Restore-InstallSnapshot $m.Baseline
Set-SceneTask $target $StateDirectory -Enable:$Enable
$m.CurrentRelease=$ReleaseId;$m.Enabled=[bool]$Enable
Save-Manifest $m $StateDirectory
"Selected installed release: $ReleaseId"
