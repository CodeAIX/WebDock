<p align="center"><img src="Sources/WebDock/Resources/WebDock.icon/Assets/WebDock.png" width="128" alt="WebDock 图标"></p>

# WebDock

**一个 Dock 图标，集中管理常用网站、浏览器和账号。**

[English](README.en.md) · **简体中文** · [下载 1.1.0](https://github.com/CodeAIX/WebDock/releases/latest)

WebDock 是原生 macOS 网站启动器。在 Launcher 中搜索、分组和打开网站，为每个网站指定浏览器及受支持的浏览器账号，并通过备份或同步在多台 Mac 间使用同一份启动规则。

支持 **macOS 13.0 及以上**，通用安装包同时支持 **Intel 和 Apple Silicon**。

## 下载与安装

从 [GitHub Releases](https://github.com/CodeAIX/WebDock/releases/latest) 下载：

| 文件 | 用途 |
| --- | --- |
| `WebDock-1.1.0-macos-universal.dmg` | 打开后将 WebDock 拖入 Applications |
| `WebDock-1.1.0-macos-universal.zip` | 解压后将 WebDock.app 移入 Applications |
| `WebDock.icns` | 独立应用图标 |
| `SHA256SUMS.txt` | 下载文件的 SHA-256 校验值 |

安装包使用 ad-hoc 签名，尚未进行 Developer ID 签名及 Apple 公证。首次打开若被系统拦截，请确认下载来源后参考 [Apple 的应用打开说明](https://support.apple.com/en-us/102445)。

更新时先退出 WebDock，再替换 Applications 中的应用。资料库存放在用户的 Application Support 目录；更新前可在「设置 → 备份与恢复」中创建备份。

## 开始使用

1. 打开 WebDock，点击 Launcher 顶栏的 `+`，输入网站名称和 HTTP/HTTPS 地址。
2. 按需指定浏览器；支持账号路由的浏览器还可选择目标账号邮箱。
3. 点击网站图标即可打开。使用搜索栏、分组侧栏或键盘导航快速定位网站。
4. 点击书签图标进入资料库，编辑启动规则、分组、图标和本机浏览器覆盖设置。

## Launcher 与资料库

- 单个 Dock 入口；点击 Dock 图标可显示或隐藏 Launcher。
- 搜索网站及分组，使用方向键导航、Return 打开网站。
- 在未筛选的「所有快捷方式」中拖动排序，重启后保留。
- 新建、编辑、复制和删除网站；未保存的编辑具有草稿保护。
- 自动获取网站图标，也可选择本地图片；显示浏览器和解析警告标识。

## 全局快捷键

WebDock 运行时，按 **⌃⌥W（Control + Option + W）** 可从其他应用唤出 Launcher。

在「设置 → 通用 → 全局快捷键」中启用、关闭、录制新组合或恢复默认。快捷键仅保存在本机，重启后保留；占用时会提示并保留原设置。录制时按 Esc 可取消。

| 快捷键 | 操作 |
| --- | --- |
| `⌃⌥W` | 全局唤出 Launcher，可自定义 |
| `⌘1` | 在 WebDock 中打开 Launcher |
| `⌘2` | 打开资料库 |
| `⌘N` | 新建快捷方式 |
| `⌘F` | 在 Launcher 中搜索 |
| `⌘,` | 打开设置 |

## 浏览器与账号

可以选择系统默认浏览器，或指定 Safari、Chrome、Chromium、Edge、Firefox、Brave、Arc、Vivaldi。

Chrome、Chromium、Edge、Brave、Vivaldi 支持按本机已登录账号的邮箱匹配浏览器配置。相同邮箱在不同 Mac 上可以对应不同的本地配置目录。

- 找不到目标账号时，使用所选浏览器的默认配置并显示警告。
- 找不到浏览器时，使用系统默认浏览器并显示警告。
- 账号匹配不唯一时，可以在资料库的「本机」区域指定本机覆盖，不影响其他 Mac。

macOS 可能要求授权读取浏览器配置元数据。在「设置 → 浏览器与账号」中使用「授权 / 重新扫描」，并按系统提示处理「文件与文件夹」权限。WebDock 无法替你开启系统授权。

## 备份与恢复

- 自动本机快照：每天最多一次，保留最近 20 份自动快照。
- 手动备份，以及便携 `.webdockbackup` 导出。
- 支持替换或合并恢复；恢复前先创建安全快照。
- 便携备份包含网站、浏览器偏好、账号邮箱、分组、排序和网站图标，不包含本机浏览器路径、Profile 目录或本机覆盖设置。

## 多 Mac 同步

在「设置 → 同步」中选择一个同步方式：

| 方式 | 设置方法 |
| --- | --- |
| 同步文件夹 | 选择由 iCloud Drive、Dropbox、OneDrive、Syncthing 或 NAS 等工具管理的普通文件夹 |
| WebDAV | 填写现有文件夹地址、用户名和密码／应用密码，保存凭据后测试连接并同步 |

两种方式均交换 `WebDockSync.json`。网站规则、分组、排序和网站图标可同步；本机浏览器解析、覆盖设置、显示偏好、全局快捷键和应用自定义图标保留在各自 Mac 上。WebDAV 密码保存在 macOS 钥匙串中。

## 语言与外观

- 简体中文和 English，默认跟随系统，也可在通用设置中手动选择。
- 界面语言即时更新；重新启动后，macOS 菜单和系统对话框完整使用所选语言。
- 跟随系统、浅色和深色外观；调整网格密度、副标题、侧栏及标识。
- 使用地球与彩色环带默认图标。
- 外观设置可选择本机 ICNS，自定义运行中的 Dock／⌘Tab 图标，并支持恢复默认。Finder 显示安装包提供的默认图标。

## 隐私与数据

WebDock 只读取匹配账号所需的浏览器配置元数据，不读取 Cookie、密码、浏览历史或网页内容。自动获取网站图标会向对应网站请求公开图标信息，不使用浏览器 Cookie 或凭据。

资料库位于 `~/Library/Application Support/WebDock/`。便携备份及同步数据可能包含你设置的网站地址、账号邮箱和网站图标；请自行选择可信的保存位置与同步服务。WebDAV 远程连接建议使用 HTTPS。

## 常见问题

**全局快捷键没有反应？** 确认 WebDock 正在运行，并在通用设置中检查开关和占用提示，必要时重新录制其他组合。

**更新后读不到浏览器账号？** 保留 Applications 中的一个 WebDock 副本，退出其他副本后重新授权／扫描。ad-hoc 签名的不同版本可能需要重新授权，系统权限由 macOS 管理。

**可以导入浏览器导出的快捷方式文件吗？** 请直接新建网站规则；不支持导入 `.crwebloc`、`.webloc` 或 `.url` 文件。

**同步后是否会复制浏览器登录状态？** 不会。每台 Mac 必须自行安装浏览器并登录账号；WebDock 只同步启动规则。

## 其他资料

[构建与校验](docs/BUILDING.md) · [同步与数据结构](docs/SYNC_AND_DEVICE_RESOLUTION.md) · [使用限制](docs/KNOWN_LIMITATIONS.md) · [报告问题](https://github.com/CodeAIX/WebDock/issues)
