# 设备验证记录

目标设备：iPhone 13 / iOS 27；Apple Watch Series 12 / watchOS 27。
准备日期：2026-10-06。

| 项目 | 状态 | 实际结果 |
| --- | --- | --- |
| 源码与配置准备 | 已完成 | YAML、Python 语法和 Bash 语法检查通过，不能代表 Swift 编译成功 |
| 包结构检查器 | 已完成 | 6 个测试通过；使用结构模拟包，不能代表真实 IPA 打包或安装成功 |
| GitHub 连接与源码上传 | 已完成 | 63243254/WatchStress，按用户授权公开，main 分支 |
| GitHub 云构建 | 已完成 | Run 37474088750 成功，标准 xcode-27 runner |
| Swift 算法测试 | 已完成 | 5 个测试通过，0 失败 |
| Xcode 27 编译 | 已完成 | Xcode 27.0 / 27A266a，手机 / Watch / Widget 三个 Target 归档成功 |
| 待设备签名 IPA 打包 | 已完成 | 本地占位签名验证通过；下载后嵌套结构复核通过，不代表已获得 Apple 设备签名 |
| Windows 工具配置修正 | 已准备 | 固定社区源码，补充 Watch 共享组、缓存键改写与权限检查 |
| Windows 工具 Rust 测试 | 已完成 | 4 个测试通过，0 失败；尚不代表 Apple 在线签名成功 |
| Windows 工具 GUI 构建 | 已完成 | Run 37475879730 成功；EXE 下载后校验和匹配，GitHub ZIP 摘要匹配；发布者签名状态 NotSigned |
| Windows 手机签名安装 | 未执行 | 需要用户设备与本地 Apple 登录 |
| Windows S12 签名安装 | 未执行 | 侧载工具对此型号 / 系统尚未验证 |
| HRV / 心率读取 | 未执行 | 需要真机授权 |
| 圆形 / 矩形 / 单行组件 | 未执行 | 需要适合的表盘 |
| 数据过期隐藏分数 | 部分完成 | Swift 过期边界测试通过，真机 / 表盘效果仍待验证 |
| 手机 / Watch / 扩展续签 | 未执行 | 不包含自动续签 |

记录后续结果时附带工具版本、系统版本与成功 / 失败阶段。
不要放入 Apple 账号、密码、证书、UDID、配对记录或真实健康数据。

App 构建源码：`4484b1f52d2f4a69da2bacf9b12935f62076fa2b`。
构建：<https://github.com/63243254/WatchStress/actions/runs/37474088750>。
IPA SHA-256：`DB1020209BC7778A4CDE66B63BE1D81F7C6EFE23BD65BECDC4E1DA0D49096085`。

安装工具构建源码：`36fb19d33b3085d1a2ca6af93602b8a20452beec`。
构建：<https://github.com/63243254/WatchStress/actions/runs/37475879730>。
EXE SHA-256：`1B902A5EEF287213058821322CB379EA1750AE3F031C0FB348AD3A1382CC3055`。

