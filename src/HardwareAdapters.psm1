Set-StrictMode -Version Latest
function Resolve-HardwareAdapter {
    param([string]$Manufacturer,[string]$Model,[string]$CatalogDirectory)
    $catalog=@(Get-ChildItem -LiteralPath $CatalogDirectory -Filter '*.json' | ForEach-Object {Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json})
    $match=@($catalog | Where-Object {$_.Id -ne 'generic-windows' -and $Manufacturer -match $_.Match.Manufacturer -and $Model -match $_.Match.Model})
    if($match.Count -gt 1){throw 'Ambiguous hardware adapters; refusing automatic selection'}
    if($match.Count -eq 1){return $match[0]}
    $fallback=@($catalog | Where-Object Id -eq 'generic-windows')
    if($fallback.Count -ne 1){throw 'Exactly one generic Windows fallback is required'}
    $fallback[0]
}
function Assert-ThermalBackend {
    param($Adapter,[string]$Backend='external')
    if($Backend -ne 'external'){throw 'Direct thermal backends are not implemented. Leave fan control to firmware/AWCC.'}
    if($Adapter.Capabilities.DirectFanWrites){throw 'This release does not support direct fan writes'}
}
Export-ModuleMember -Function Resolve-HardwareAdapter,Assert-ThermalBackend
