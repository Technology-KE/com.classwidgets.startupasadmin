# 更新日志

本项目的所有重要改动都会记在这里。版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)，
每个 tag 对应一次 Release，并自动打包发布到插件广场。

## [1.1.0] - 2026-11-20

插件显示名改为 **以管理员权限启动/重启**（插件 ID `com.classwidgets.startupasadmin` 不变）。

### 新增

- **以管理员权限重启**：弹一次 UAC，把当前实例换成提权实例。提权脚本会先等旧实例退出（避免撞上主程序的单实例锁），再以管理员身份拉起主程序，不会再弹"重复打开"提示。
  - 已经是管理员权限时自动退化为普通重启（`api.application.restart()`），不再白弹一次 UAC。
- **主程序开机自启检测**：读 `HKCU/HKLM\...\CurrentVersion\Run`，认出主程序自己写的启动项（`ClassWidgets_2` 或指向 Class Widgets 2 exe 的值）。
  - 没检测到：不显示提示，创建按钮照旧。
  - 检测到：显示提示卡，说明会启动两次、告知在「设置 → 通用 → 开机自启动」里关，并给出 **关闭当前开机自启并创建管理员权限启动**；此时隐藏下面重复的创建按钮。
- **重复启动提醒**：照主程序「重复打开」的样子做的确认弹窗（警告图标 + 说明 + 底部整宽按钮），主程序自启还开着时点创建会先弹它。
- 状态卡新增「当前运行权限」（管理员 / 标准用户）。

### 变更

- 界面重做为 RinUI 卡片式：`Frame` 状态卡 + `PillButton` 状态胶囊 + 分隔线 + 明细行，结果提示改用 `InfoBar`，等待 UAC 时显示 `BusyIndicator` 和「正在等待管理员授权…」。
- 颜色一律跟随主程序主题（`systemSuccess/Caution/CriticalColor`、`cardBorderColor` 等），去掉写死的 `#46CEA3` / `#E05B5B` / `#D28B59`。
- 页面内容交给 `FluentPage` 的滚动容器排版，修掉原来「layout 里写 anchors」的 QML 告警。
- 「关闭当前开机自启并创建」的执行顺序改为**先建任务、再关自启**：中途取消 UAC 时不会落到"自启关了、任务也没有"的状态。
- 关闭主程序自启时会顺带把主程序的 `app.auto_startup` 配置同步成关闭，免得它下次启动又写回注册表。
- 版本号 1.0.4 → 1.1.0；重新打包 `.cwplugin`。

## [1.0.4] - 2026-10-24

### 变更

- 更新打包文件，使 `.cwplugin` 与源码一致。

## [1.0.3] - 2026-10-24

### 变更

- 更新版本号。

## [1.0.2] - 2026-10-17

### 变更

- 适配 Class Widgets 2 SDK 0.7.0（`api_version` 升至 `~=0.7.0`）。
- README 开头改为居中图标 + 徽章 + 版本说明，图标缩至 512×512。

## [1.0.1] - 2026-09-19

### 修复

- 优化使用体验，修复已知问题。

## [1.0.0] - 2026-09-13

### 新增

- 首次发布：通过 Windows 计划任务，让 Class Widgets 2 在登录时以管理员身份自启动（创建 / 更新 / 删除任务，提权走 UAC）。

[1.1.0]: https://github.com/Kryon2025/com.classwidgets.startupasadmin/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/Kryon2025/com.classwidgets.startupasadmin/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/Kryon2025/com.classwidgets.startupasadmin/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/Kryon2025/com.classwidgets.startupasadmin/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/Kryon2025/com.classwidgets.startupasadmin/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Kryon2025/com.classwidgets.startupasadmin/releases/tag/v1.0.0
