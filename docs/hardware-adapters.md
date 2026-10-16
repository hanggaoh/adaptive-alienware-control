# Hardware adapters

The scene resolver is vendor-independent. Installation selects an exact model adapter using Win32_ComputerSystem, records hardware.json in the installed release, and uses that adapter's versioned policy. Unknown models use generic-windows, not x17 R2 tuning. An explicit QuietTemplateGuid remains an advanced user override.

To add a model, add config/hardware/<model>.json and a policy file. Use anchored manufacturer/model patterns, no machine identifiers, serial numbers or usernames. Include selection and fallback tests. Validation must start as unvalidated; report Windows build, CPU, BIOS and manual acceptance results without publishing serial numbers.

Generic support means Windows plan switching only, not certified cooling compatibility. Its CPU settings inherit Balanced; it still sets the documented lid, display timeout and Energy Saver policies. These are not a promise of maximum battery savings.

## Thermal backend contract (reserved, not implemented)

Only external ownership is accepted today: BIOS/AWCC owns cooling. A future backend must expose capability discovery, profile validation, enter/leave scene, read-back and restore-on-failure. It must enforce one controller, reject unknown models and unsupported commands, preserve firmware protections, avoid overclocking, and test rollback before enabling writes. Firmware mode IDs must never be shared across models by assumption. AlienFan cannot necessarily lower a BIOS fan floor.

Do not distribute vendor binaries, AWCC data or copied third-party code without checking its license. This repository currently contains no AlienFan implementation or binary.
