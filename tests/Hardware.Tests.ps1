$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $repo 'src/HardwareAdapters.psm1') -Force
$catalog=Join-Path $repo 'config/hardware'
$x=Resolve-HardwareAdapter 'Dell Inc.' 'Alienware x17 R2' $catalog
if($x.Id -ne 'alienware-x17-r2'){throw 'Exact model selection failed'}
foreach($model in @('Alienware m18 R2','Alienware x17 R1','Unknown')){
 $g=Resolve-HardwareAdapter 'Dell Inc.' $model $catalog
 if($g.Id -ne 'generic-windows'){throw 'Unknown model inherited specific tuning'}
 Assert-ThermalBackend $g
}
$rejected=$false
try{Assert-ThermalBackend $x 'alienfan'}catch{$rejected=$true}
if(-not $rejected){throw 'Unimplemented thermal backend accepted'}
'Hardware adapter checks passed (exact match, safe fallback, unsupported backend rejection).'
