# Adaptive Alienware Control

An experimental, model-aware power scene controller for Windows 11: battery efficiency, quiet coding, and gaming.

**Version: 0.1.0-experimental.** An independent project, not an official Dell product or a complete AWCC replacement. Compatibility with every Alienware model is not claimed.

## Current scope

| Scene | Windows behavior | Cooling ownership |
|---|---|---|
| Battery (takes priority over games) | Efficiency mode; automatic Energy Saver threshold of 100%; x17 R2 policy disables CPU turbo | Firmware/AWCC |
| Plugged in, no registered game | Tuned Quiet Coding on x17 R2; conservative Windows fallback on other models | User's default AWCC preset |
| Plugged in, registered game running | Native Balanced CPU policy, no added overclocking; Energy Saver expected off | AWCC must recognize the game and apply its saved preset |

Unknown models use a generic Windows policy, not x17 R2 hybrid-core tuning. Generic support means Windows power switching, not validated cooling compatibility.

**Direct fan control and the AlienFan backend are not implemented.** See [Hardware adapters](docs/hardware-adapters.md) for extension interfaces and safety requirements. License: [MIT](LICENSE).

Automated test results and successful plan GUID changes do not establish correct Energy Saver behavior, AWCC switching, temperatures, fan noise, or game performance. Physical acceptance remains separate.

## Quick start

Use Windows PowerShell 5.1 or later from the repository directory:

```powershell
.\Test.ps1
.\scripts\Install.ps1 -WhatIf
```

If Windows PowerShell blocks scripts under Restricted execution policy, explicitly choose a process-scoped policy for this invocation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test.ps1
```

No system-wide execution policy change or security software disabling is required.

Install from an elevated PowerShell. **Installation does not enable the watcher or change the active plan by default.**

```powershell
.\scripts\Install.ps1
.\scripts\Status.ps1
```

Review the policy, turn off **Always use energy saver** in Windows Settings, and prepare for physical acceptance tests before explicitly enabling:

```powershell
.\scripts\Enable.ps1
```

The installer creates three owned plans without modifying the original. On x17 R2, a uniquely named existing Quiet Coding plan is used as the battery/coding template when available; otherwise native Balanced is used. Other models default to Balanced. Advanced users can explicitly supply `-QuietTemplateGuid`.

Version-controlled settings from the selected adapter policy are then applied: `config/profiles.json` for x17 R2, or `config/policies/generic-windows.json` for the fallback.

## Installation and safety

Formerly Quiet Power Scenes. Internal task and directory names remain `QuietPowerScenes` for compatibility with existing installations, snapshots, and rollback scripts. Repository renaming does not alter a running installation.

- Installed code: `%ProgramFiles%\QuietPowerScenes\releases\<release-id>`. Editing the checkout does not immediately change elevated runtime code.
- Local snapshots, plan GUIDs, state, and logs: `%ProgramData%\QuietPowerScenes`; excluded from Git.
- Logon task: `QuietPowerScenes`, elevated in the current user's interactive session with hidden PowerShell. Not a system service; Codex does not need to remain open.
- Process start/stop and power events drive switching, with 60-second reconciliation and a 15-second delay after all registered games exit.
- No game injection, game-file modification, security disabling, AWCC fan/firmware writes, or direct `EnergySaverState` registry writes.
- Legacy `QuietCoding-GamePowerSwitch` and temporary controllers are not silently taken over. Detected controller conflicts prevent enablement.

## Game detection

Reads the AWCC game library and `config/games.json`. Detection uses executable names rather than version-specific WindowsApps paths. Steam/Xbox launchers, Python/Torch, and browsers are not automatically classified as games.

**Not every arbitrary executable can be reliably identified as a game.** Add unregistered games to AWCC or the configured list, then install a new configuration release. AWCC still needs the correct executable association and saved performance preset to control cooling.

## Testing

- `Test.ps1`: scene logic, hardware selection/fallback, mocked lifecycle checks, PowerShell syntax, policy validation, and a non-mutating installation preview.
- `tests/Live.Tests.ps1`: read-only observations. Unconfirmed Energy Saver UI or AWCC state remains Pending, not Pass.
- [Physical acceptance](docs/acceptance.md): plug/unplug, game start/exit, sleep/resume, frame rate, and noise. This companion document is currently in Chinese.

## Updates, rollback, and uninstall

```powershell
# Test and install a new release; disabled by default.
.\Test.ps1
.\scripts\Install.ps1

# Select the previous installed release, preserving the original snapshot.
.\scripts\Rollback.ps1 -WhatIf
.\scripts\Rollback.ps1
.\scripts\Enable.ps1

# Stop and restore the pre-install Windows plan and AC/DC power modes.
.\scripts\Disable.ps1

# Remove the task and restore the original configuration.
# Owned plans are retained by default for auditing.
.\scripts\Uninstall.ps1

# Also remove plans verified as owned by this installation.
.\scripts\Uninstall.ps1 -RemoveOwnedPlans
```

Uninstall retains release files and snapshots without recursive deletion. It does not undo manual changes in AWCC, Windows Settings, or BIOS. Runtime plan selection can affect automatic Energy Saver, but uninstall does not write an unreliable global saver registry toggle.

An uninstalled state directory is retained as an archive. Start a new installation cycle with a new `-StateDirectory`; pass that same directory to subsequent Status/Enable/Rollback/Uninstall commands.

Source rollback (`git switch --detach <tag-or-commit>`, followed by testing and installation) is distinct from `Rollback.ps1`, which selects an already installed release.

## Optional development helpers

`dev/quiet-dev` provides manual WSL entry points with eight build jobs and six CPU math-library threads. Its Torch entry point uses six intra-op and two inter-op threads without limiting the GPU. `dev/Build-Quiet.ps1` uses a single MSBuild project worker and limits C++ `/MP` concurrency.

These helpers are optional: installation does not modify WSL or replace Visual Studio Build/F5 actions.

## Known limitations

Energy Saver automatic thresholds are supported Windows policies, but complete UI/AWCC integration has not been validated on the test machine. Some API readings disagree with the Windows UI; status output preserves Unknown/Pending when appropriate.

The x17 R2 Coding policy disables turbo, which may reduce compilation performance. Validate with your own workloads. Firmware may ignore some Windows cooling settings; fixed RPM, silence, and stutter-free gameplay are not guaranteed.

See [Contributing](CONTRIBUTING.md) before adding models. Never publish machine snapshots, serial numbers, tokens, or unredacted diagnostic logs.

## References

- [Windows battery threshold policy](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/battery-threshold)
- [Windows Energy Saver behavior](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/energy-saver)
- [CIM events](https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/register-cimindicationevent)
- [Windows AC power mode API](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powersetuserconfiguredacpowermode)
