# Windows 真机安装验证

此工程有两个独立的云构建：`build.yml` 生成手机 / Watch / 表盘扩展 IPA，
`build-installer.yml` 从固定社区源码生成实验性 Windows 安装工具。
构建不使用 Apple 账号，不包含签名证书或健康数据。

## 工具来源与修改

工具基于社区作者已验证的版本：

- <https://github.com/Rzbck/iloader>：`70f37e9b4afc659ab44ec1944c034093f4cda416`
- <https://github.com/Rzbck/isideload>：`f7b9f3da570edd6824c29680545e710846d07df5`
- 验证说明：<https://github.com/Rzbck/iloader-watch-companion>

原版本跳过 Watch App Group 配置，并不会改写自定义的 `StressAppGroup` 信息键。
`scripts/watchstress-isideload.patch` 为本 App 补充 Watch / Widget 的共享组配置，
使用 watchOS 平台参数，统一改写缓存信息键，并在描述文件缺少权限时中止签名。
该修改需要独立的真机验证，不能沿用作者对原版本的成功结论。

这是独立的个人实验构建，不是官方 iLoader 发行版，不保证 S12 / watchOS 27 兼容。
上游 iLoader / isideload 的许可证与署名随工具一同保留。

## 安装步骤

1. 在 Windows 安装 Apple 官方的 Apple Devices，使电脑能识别 iPhone。
   商店页面：<https://apps.microsoft.com/detail/9np83lwlpz9k>。
2. 用支持数据传输的数据线连接 iPhone，解锁并信任此电脑。Watch 保持与此 iPhone 配对。
3. 下载并解压成功的 `WatchStress-Windows-installer-experimental` artifact。
4. 启动 `WatchStress-Installer-experimental.exe`。它是便携程序。
5. 在本地工具中选择手机、完成 Apple 账号登录与双重认证，导入
   `WatchStress-resign-required.ipa`，按界面执行安装。账号信息不需要发送到聊天或 GitHub。
6. 按手机和 Watch 的实际提示启用开发者模式、信任开发者及接受配对请求。
   若提示撤销已有证书，先确认它是否影响其他已侧载的 App；不要自动接受。
7. 确认手机与 Watch 都能启动「压力观察」。在 Watch 内授权读取健康数据，再点击刷新。
8. 编辑支持对应形状的表盘组件，选择「压力观察」。先确认 HRV 样本与时间，再确认分数。

免费 Personal Team 的签名通常 7 天后过期，手机、手表及扩展都需要重新签名安装。
此版本没有自动续签。不要将此实验工具更新为官方 iLoader 后仍假定 Watch 支持保留。

## 失败时定位

- 手机未显示：先检查数据线、信任、Apple Devices 与驱动。
- 签名阶段失败：区分 Apple 登录、免费 App ID 数量限制与 Watch 共享组配置失败。
- 手机成功而 Watch 失败：记录 Watch 发现、描述文件、配对或传输的失败阶段。
- App 启动但表盘没有数据：先在 Watch App 刷新，检查共享组错误信息及 HRV 是否过期。

具体失败原因必须依据本机工具提示和真机结果。记录结果时隐藏账号、设备 UDID、
配对信息、证书和真实健康数据，不能把云端编译成功写成安装成功。
