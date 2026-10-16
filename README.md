# Adaptive Alienware Control

项目已从 Quiet Power Scenes 更名。为兼容已有安装、快照与回退脚本，本版本保留内部任务名及安装/状态目录 `QuietPowerScenes`；这不影响三场景自适应功能。源码目录可以自行改名，正在运行的配置不会因仓库更名而改变。

Windows 11 三场景电源控制器，当前版本 **0.1.0-experimental**。支持可扩展机型适配：x17 R2 使用实验调校，其他机型回退到通用 Windows 策略，不套用 x17 R2 的混合核心参数。不是 Dell 官方产品，也不宣称支持所有 Alienware。

适配器接口与支持边界：[Hardware adapters](docs/hardware-adapters.md)。许可证：MIT。AlienFan 后端仅预留设计，目前不写风扇或固件。

| 场景 | Windows 行为 | AWCC |
|---|---|---|
| 电池供电（优先于游戏） | Battery 最佳能效、CPU 禁用睿频；Energy saver 自动电量阈值 100% | Windows 节能限制/用户默认预设 |
| 插电、不运行游戏 | 当前调教过的 Quiet Coding 策略 | 用户默认预设 |
| 插电、运行已登记游戏 | 原生 Balanced CPU 策略，不额外超频；Energy saver 应关闭 | AWCC 识别游戏并应用各自保存的预设 |

**这是可测试的实验配置，不是已经证明能解决卡顿/噪音的稳定版。** 逻辑测试与实际 Energy saver、AWCC、温度/转速、游戏流畅度验收分开。不要因为计划 GUID 切换成功就认为所有层都通过。

## 快速开始

在仓库目录运行（Windows PowerShell 5.1 或更新版本）：

```powershell
.\Test.ps1
.\scripts\Install.ps1 -WhatIf
```

若旧版 Windows PowerShell 的脚本执行策略为 Restricted，可对这一次命令显式指定进程级策略，例如 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test.ps1`。无需修改系统级执行策略或关闭安全软件。

管理员 PowerShell 安装，**默认不启用监听，也不切换当前计划**：

```powershell
.\scripts\Install.ps1
.\scripts\Status.ps1
```

确认 Windows 设置中 **Always use energy saver 已关闭**，检查策略数据并准备做实际场景测试后，再显式启用：

```powershell
.\scripts\Enable.ps1
```

安装时创建独立的三个计划，不改原计划。若找到唯一名为 Quiet Coding 的原计划，电池/编码档以它为模板；否则以系统 Balanced 为模板。也可显式传 `-QuietTemplateGuid`。CPU 参数以版本控制的 `config/profiles.json` 为准，非静默沿用旧参数。

## 安装目录与安全边界

- 代码副本：`%ProgramFiles%\QuietPowerScenes\releases\<release-id>`；编辑 Git 工作区不会即时改变正在运行的管理员脚本。
- 本机快照、计划 GUID、状态、日志：`%ProgramData%\QuietPowerScenes`，不进 Git。
- 登录任务：`QuietPowerScenes`，当前用户交互会话、管理员权限、隐藏 PowerShell；不是系统服务，不依赖 Codex 常开。
- 进程启动/退出事件 + 电源变化事件；每 60 秒兜底；所有游戏退出后延迟 15 秒回编码档。
- 不注入游戏、不改游戏文件、不关安全防护、不写 AWCC 风扇/固件模式、不直接写 `EnergySaverState`。
- 旧的 `QuietCoding-GamePowerSwitch` 和临时控制器不会被静默接管；启用时发现其他控制器会拒绝启动。

## 游戏识别边界

读取 AWCC 游戏库与 `config/games.json` 名单。按进程名识别，不依赖 WindowsApps 版本目录。Steam/Xbox 启动器、Python/Torch、浏览器不自动当作游戏。

**不是所有任意 EXE 都能可靠判断为游戏。** 未登记游戏先加入 AWCC 或名单，再重新安装配置版本；AWCC 本身也必须有正确的实际游戏关联和保存好的性能预设。

## 测试

- `Test.ps1`：纯逻辑测试、PowerShell 语法、策略校验、安装 `-WhatIf` 无电源变更检查。
- `tests/Live.Tests.ps1`：只读实际验收；UI 未确认或未指定正确 AWCC 模式时结果为 Pending，不冒充 Pass。
- 实际拔电/插电、游戏进程和退出事件、睡眠唤醒、帧率与噪音：[验收步骤](docs/acceptance.md)。

## 版本与回退

```powershell
# 更新策略/代码后运行测试，再安装一个新 release；默认仍停用。
.\Test.ps1
.\scripts\Install.ps1

# 切回上一个已安装 release（保留原始安装前快照）。
.\scripts\Rollback.ps1 -WhatIf
.\scripts\Rollback.ps1
.\scripts\Enable.ps1

# 停用并恢复安装前 Windows 计划和 AC/DC power mode。
.\scripts\Disable.ps1

# 卸载任务并恢复原始配置；默认保留自建计划，便于审计。
.\scripts\Uninstall.ps1
# 额外删除清单中确认为本项目创建的计划：
.\scripts\Uninstall.ps1 -RemoveOwnedPlans
```

卸载保留 release 文件和快照，不做递归删除。它不撤销用户自己在 AWCC、Windows UI、BIOS 中作的改动。运行时计划选择会影响系统的自动 Energy saver，但卸载不写不可靠的全局节能注册表开关。

卸载后的状态目录作为归档保留，不允许再次覆盖其初始快照；重新开始安装周期时指定新的 `-StateDirectory`，后续 Status/Enable/Rollback/Uninstall 传相同目录。

Git 源码回退：`git switch --detach <tag-or-commit>` 后重新测试、安装；这和 `Rollback.ps1` 选择已经安装的 release 是两种操作。

## 附带开发命令

`dev/quiet-dev`：WSL 手动编译 8 路、CPU 数学库线程 6，Torch 专用入口支持 intra-op 6 / inter-op 2；不限制 GPU。`dev/Build-Quiet.ps1`：VS/MSBuild 单项目构建并限制 C++ `/MP` 并发。这些是可选入口，不由安装器写入 WSL、不更改 VS 的 Build/F5 按钮。

## 已知风险

Energy saver 自动阈值是系统支持的策略，但在这台机器上的 UI/AWCC 联动尚未完成全部实测。部分 Windows API 对节能状态读数与 UI 不一致；状态文件会保留 Unknown/Pending。Coding 禁用睿频可能影响编译速度，需要用实际项目验收。硬件固件可能忽略部分 Windows 散热策略；不承诺固定 RPM 或无声。

参考：[Windows 电量阈值](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/battery-threshold)、[Energy Saver 行为](https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/energy-saver)、[进程事件](https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/register-cimindicationevent)、[Windows AC power mode](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powersetuserconfiguredacpowermode)。
