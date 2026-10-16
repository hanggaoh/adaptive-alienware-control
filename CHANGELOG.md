# Changelog

## 0.1.0-experimental

- 将电池 / 插电编码 / 插电游戏策略与安装数据分离。
- 导入并扩展状态转换测试；显式标注真实验收 Pending。
- 使用系统电量阈值，不直接写 EnergySaverState；不控制 AWCC 散热预设。
- 安装默认停用；管理员部署到版本化 release 目录。
- 增加启用、停用、安装版本回退、卸载恢复和本机快照。
- 附带可选 WSL/MSBuild 安静构建入口，不自动安装它们。
