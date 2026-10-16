# Optional quiet build commands

These helpers are opt-in. The power-profile installer does not copy them into WSL or change Visual Studio settings.

WSL, after activating your project's virtual environment:

```bash
bash /mnt/c/path/to/adaptive-power-scenes/dev/quiet-dev make
bash /mnt/c/path/to/adaptive-power-scenes/dev/quiet-dev cmake build
bash /mnt/c/path/to/adaptive-power-scenes/dev/quiet-dev run python script.py
bash /mnt/c/path/to/adaptive-power-scenes/dev/quiet-dev torch python train.py
```

Defaults: build jobs 8, CPU libraries 6 threads; dedicated `torch` entry adds inter-op 2. GPU is unrestricted. Torch entry imports Torch before your script; for torchrun/multiprocessing/complex launchers use `run` and configure Torch threads in your code. DataLoader worker count is not modified.

Override one invocation with `QUIET_BUILD_JOBS=6` or `QUIET_CPU_THREADS=2`. Other build steps/processes can exceed these advisory budgets.

Windows:

```powershell
.\dev\Build-Quiet.ps1 .\YourSolution.sln -Configuration Debug -Platform x64 -Jobs 8
```

One project at a time, C++ `/MP` budget 8 when already enabled in the project. Doesn't enable `/MP` or change Visual Studio Build/F5 behavior. Custom build steps may ignore these settings.
