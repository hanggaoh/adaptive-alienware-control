# 真实场景验收（自动测试不能替代）

先运行 `Test.ps1`，管理员安装，再显式 `Enable.ps1`。保持 Windows **Always use energy saver 关闭**，由电量阈值处理电池自动节能。

## A. 电池

1. 拔电，游戏可仍在运行；电池规则必须优先。
2. 检查 `Status.ps1` 的 Battery、实际 QPS Battery 计划及 DC 最佳能效。
3. 在 Windows 设置确认 Energy saver 为 On；看 AWCC 是否显示对应节能状态。
4. 待温度稳定再记录转速/噪音，不把切换后 30 秒内的残余热量当作失败。

## B. 插电编码

1. 无游戏时插电。
2. 检查 Coding 和 QPS Coding 计划，CPU 策略等同版本化的 Quiet Coding 数据。
3. Energy saver 实际为 Off，AWCC 日常默认配置生效。
4. 测试打字、视频、WSL 编译和 VS 编译响应。不能只看低温就判成功。

## C. 插电玩游戏

1. 启动 AWCC/名单登记的游戏。
2. 检查 Gaming、QPS Gaming 计划、AC Balanced power mode。
3. Energy saver 实际 Off；AWCC 识别正确的游戏并选择用户保存的配置。
4. 在真实游戏前台记录帧率/卡顿与噪音。任务管理器前台/游戏失去焦点时的数据不能当作游戏瓶颈结论。
5. 退出全部游戏，约 15 秒后回 Coding；第二个游戏仍运行时不能回 Coding。
6. 游戏中拔电 -> Battery；已有游戏时插电 -> Gaming。

读取记录（`-EnergySaverUi` 是操作者看 UI 后提供的证据，不是脚本猜的值）：

```powershell
.\tests\Live.Tests.ps1 -Expected Battery -EnergySaverUi On -AwccExpectedMode 165
.\tests\Live.Tests.ps1 -Expected Coding -EnergySaverUi Off
.\tests\Live.Tests.ps1 -Expected Gaming -EnergySaverUi Off -AwccExpectedMode 160
```

160/165 仅是这台 x17 R2 的已观察模式示例，不是强制所有机型或游戏使用这个 ID。AWCC 自定义曲线可能使用 0；先确认用户保存的目标。未提供 AWCC 目标则 Pending。

额外验收：睡眠/唤醒、监听重启、坏掉的游戏库 JSON、游戏更新路径、两个游戏重叠运行、未知游戏未登记、旧控制器冲突。未知游戏不识别属于覆盖失败，不能宣称“任意游戏均可”。

## 安装/回退验收

本次仅自动执行只读测试与 Install -WhatIf，没有在当前机器真实部署这个新仓库版。实际管理员安装、升级、Rollback、Uninstall 都必须另行验证：原计划不修改；回退选择正确 release；卸载先恢复初始计划再删除自建计划；Energy saver 和 AWCC 手工修改不被伪造恢复。
