[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'tests\Hardware.Tests.ps1')
& (Join-Path $PSScriptRoot 'tests\Unit.Tests.ps1')
& (Join-Path $PSScriptRoot 'tests\Lifecycle.Tests.ps1')
& (Join-Path $PSScriptRoot 'tests\Smoke.Tests.ps1')
'Automated checks passed. Physical plug/unplug, Energy Saver UI, AWCC profiles and gameplay remain separate acceptance tests.'
