param(
    [Parameter(Mandatory, Position=0)][string]$Project,
    [string]$Configuration = 'Debug',
    [string]$Platform,
    [ValidateRange(1,20)][int]$Jobs = 8,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio Installer/vswhere not found.' }
$msbuild = & $vswhere -latest -products '*' -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) { throw 'MSBuild not found.' }
$projectPath = (Resolve-Path -LiteralPath $Project).Path
$buildArgs = @($projectPath, '/t:Build', '/m:1', "/p:Configuration=$Configuration", "/p:CL_MPCount=$Jobs", "/p:MultiProcMaxCount=$Jobs", '/nologo')
if ($Platform) { $buildArgs += "/p:Platform=$Platform" }
if ($DryRun) { $msbuild; $buildArgs; return }
& $msbuild @buildArgs
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed with exit code $LASTEXITCODE" }
