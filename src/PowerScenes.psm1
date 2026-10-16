Set-StrictMode -Version Latest
function Resolve-PowerScene {
    param([bool]$OnAC,[string[]]$Games=@())
    if(-not $OnAC){return 'Battery'}
    if(@($Games | Where-Object {$_}).Count -gt 0){return 'Gaming'}
    'Coding'
}
function Get-SceneTransition {
    param([string]$Current,[bool]$OnAC,[string[]]$Games=@(),[datetime]$Now=[datetime]::UtcNow,[Nullable[datetime]]$ExitDue=$null,[ValidateRange(0,120)][int]$ExitDelaySeconds=15)
    $target=Resolve-PowerScene $OnAC $Games
    if($target -eq 'Battery'){return [pscustomobject]@{Scene='Battery';ExitDue=$null}}
    if($Current -eq 'Gaming' -and $target -eq 'Coding'){
        if($null -eq $ExitDue){$ExitDue=$Now.AddSeconds($ExitDelaySeconds)}
        if($Now -lt $ExitDue){return [pscustomobject]@{Scene='Gaming';ExitDue=$ExitDue}}
    }
    [pscustomobject]@{Scene=$target;ExitDue=$null}
}
function ConvertTo-GameImage {
    param([string]$Path)
    $name=[IO.Path]::GetFileNameWithoutExtension($Path)
    if($name -notmatch '^[a-zA-Z0-9_. -]+$'){return}
    if($name -match '^(explorer|steam|steamwebhelper|Xbox|XboxPcApp|GamingServices|EpicGamesLauncher|GalaxyClient|Battle\.net|upc|python|python3|chrome|msedge)$'){return}
    $name
}
function Get-SceneDefinition {
    param([ValidateSet('Battery','Coding','Gaming')][string]$Scene,$Config)
    switch($Scene){
        Battery {[pscustomobject]@{Scene=$Scene;Plan=$Config.BatteryPlan;Overlay='961cc777-2547-4f9d-8174-7d86181b8a7a';Supply='DC';EnergySaverExpected='On';ThermalOwner='Windows/AWCC'}}
        Coding {[pscustomobject]@{Scene=$Scene;Plan=$Config.QuietPlan;Overlay='961cc777-2547-4f9d-8174-7d86181b8a7a';Supply='AC';EnergySaverExpected='Off';ThermalOwner='AWCC'}}
        Gaming {[pscustomobject]@{Scene=$Scene;Plan=$Config.GamePlan;Overlay='00000000-0000-0000-0000-000000000000';Supply='AC';EnergySaverExpected='Off';ThermalOwner='AWCC'}}
    }
}
function Get-RegisteredGameNames {
    param($Config)
    $names=@($Config.GameProcesses | ForEach-Object {ConvertTo-GameImage ($_.ToString()+'.exe')})
    foreach($path in $Config.GameLibraries){
        if(Test-Path -LiteralPath $path){
            try {
                $data=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
                if($data.PSObject.Properties['Games']){
                    foreach($game in $data.Games){
                        if($game.PSObject.Properties['ExePath'] -and $game.ExePath){$names+=ConvertTo-GameImage $game.ExePath}
                    }
                }
            } catch {Write-Warning "Could not read game library: $path"}
        }
    }
    @($names | Where-Object {$_} | Sort-Object -Unique)
}
function Initialize-SceneNative {
    if('SceneNative' -as [type]){return}
    Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public class SceneNative {
 [StructLayout(LayoutKind.Sequential)] public struct Status{public byte AC,Flags,Percent,Saver;public uint Life,FullLife;}
 [DllImport("kernel32.dll")] public static extern bool GetSystemPowerStatus(out Status s);
 [DllImport("powrprof.dll")] public static extern uint PowerSetUserConfiguredACPowerMode(ref Guid mode);
 [DllImport("powrprof.dll")] public static extern uint PowerSetUserConfiguredDCPowerMode(ref Guid mode);
}
'@
}
function Get-SceneSnapshot {
    param([switch]$ReadThermal)
    Initialize-SceneNative
    $s=New-Object SceneNative+Status
    if(-not [SceneNative]::GetSystemPowerStatus([ref]$s)){throw 'Power status query failed'}
    if($s.AC -notin @(0,1)){throw 'Power supply state is unknown'}
    $p=Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes'
    $result=[ordered]@{Time=(Get-Date -Format o);OnAC=($s.AC -eq 1);BatteryPercent=$s.Percent;Plan=$p.ActivePowerScheme;
        OverlayAC=$p.ActiveOverlayAcPowerScheme;OverlayDC=$p.ActiveOverlayDcPowerScheme;
        LegacySaverSignal=$s.Saver;EnergySaverVerified=$false;EnergySaverUi='Unknown';AwccMode=$null}
    if($ReadThermal){
        $device=Get-CimInstance -Namespace root/wmi -ClassName AWCCWmiMethodFunction
        $result.AwccMode=[int](Invoke-CimMethod -InputObject $device -MethodName Thermal_Information -Arguments @{arg2=[uint32]11}).argr
    }
    [pscustomobject]$result
}
function Invoke-Scene {
    param([ValidateSet('Battery','Coding','Gaming')][string]$Scene,$Config)
    $before=Get-SceneSnapshot
    if(($Scene -eq 'Battery') -eq $before.OnAC){throw 'Requested scene does not match actual power supply'}
    $d=Get-SceneDefinition $Scene $Config
    & powercfg.exe /setactive $d.Plan | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Power plan activation failed'}
    $guid=[guid]$d.Overlay
    if($d.Supply -eq 'AC'){$r=[SceneNative]::PowerSetUserConfiguredACPowerMode([ref]$guid)}
    else{$r=[SceneNative]::PowerSetUserConfiguredDCPowerMode([ref]$guid)}
    if($r -ne 0){throw "Power mode call failed: $r"}
    # Never write EnergySaverState: the DC=100%, AC=0% policy is owned by Windows.
    # Never write thermal modes: AWCC owns its global and per-game presets.
    $after=Get-SceneSnapshot
    if($after.Plan -ne $d.Plan){throw 'Read-back of active plan failed'}
    $observed=if($d.Supply -eq 'AC'){$after.OverlayAC}else{$after.OverlayDC}
    if($observed -ne $d.Overlay){throw 'Read-back of power mode failed'}
    $after
}
Export-ModuleMember -Function Resolve-PowerScene,Get-SceneTransition,ConvertTo-GameImage,Get-SceneDefinition,Get-RegisteredGameNames,Get-SceneSnapshot,Invoke-Scene
