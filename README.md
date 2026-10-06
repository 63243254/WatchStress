# 压力观察 · WatchStress

给 iPhone 13 / iOS 27、Apple Watch Series 12 / watchOS 27 准备的原生最小验证工程。
目标是先验证自己的设备能安装、读取 HRV，并将结果放到表盘。

## 当前状态

- 源码、XcodeGen 工程配置、GitHub Actions 编译流程已准备。
- **尚未在 Xcode 编译，尚未生成 IPA，尚未在手机或手表安装验证。**
- 当前 Windows 环境没有 Xcode / Apple SDK；本地静态检查不能代替真实编译。
- Windows 手表侧载方案仍是实验性项目，没有明确覆盖 S12 / watchOS 27 的兼容承诺。
- 第一版仅在打开 App 或点击刷新时更新；不包含全天后台自动更新。

## 第一版包含

1. 手机和手表分别读取本机 HealthKit 的最近 21 天 HRV 与最近 2 小时心率。
2. 显示 HRV、心率、各自的数据时间、个人基线与压力估计。
3. 表盘提供圆形、矩形和单行三种组件，读取手表 App 写入的本地缓存。
4. 数据不足时不生成压力分数；数据超过 2 小时后隐藏分数。
5. 无账号系统、服务器、广告和 App 内订阅。源码不上传健康数据。

手机与手表的 App Group 是各设备上的独立容器，并不会自动跨设备同步。
两端直接查询各自的 HealthKit，所以受系统的健康数据同步延迟影响。
手表表盘读取手表端的缓存，需要先在手表上打开 App 授权、刷新一次。

## 算法说明

这不是临床验证过的压力测量模型，也不是商业 App 算法的复刻。
它只将当前 HRV 的 SDNN 与个人历史基线比较，便于观察相对变化。

- 取最新 HRV 样本之前的 14 个完整日期，排除最新样本所在日期。
- 每个日期先求 HRV 中位数，再取这些日期中位数的中位数作为基线。
- 至少需要 5 个有效历史日期、10 个有效历史样本。
- 显示分数 = `clamp(round(50 - 45 * log2(当前 HRV / 基线)), 0, 100)`。
- 分数越高表示 HRV 相对基线越低，未必意味着心理压力更大。
- 运动、疾病、睡眠、呼吸、测量条件等都可能影响 HRV。
- HealthKit 中其他 App 写入的 HRV 样本目前也会参与计算。

## 只有 Windows：先云端编译，再验证侧载

### 1. 准备一个自己的 GitHub 仓库

将这个文件夹内的内容作为仓库根目录上传，保留 `.github/workflows/build.yml`。
公开仓库的标准 GitHub-hosted runner 可免费使用；私有仓库取决于账号额度。
公开源码是一个独立选择：确认接受公开后再上传。本地工程现在没有发布到 GitHub。

不要上传 Apple 密码、设备 UDID、证书、签名描述文件、配对文件或健康数据。
这个编译流程不需要 Apple 登录信息。它先进行不使用 Apple 开发者签名的编译，
再添加本地占位签名，将 HealthKit / App Group 权限写入包，供后续侧载工具识别。
占位签名不会让包变得可安装，也不是付费开发者计划中的 Ad Hoc 分发签名。

### 2. 触发编译

在 GitHub 仓库进入 **Actions → Build iPhone and Watch validation app → Run workflow**。
流程使用 `xcode-27` runner，执行 Swift 算法测试，生成 Xcode 工程，再构建手机 App、
嵌入式 Watch App 及表盘扩展。成功后下载 `WatchStress-validation` artifact。

如果 runner 的公开预览暂时不可用或 Homebrew 安装失败，保留日志并改用可用的
Xcode 27+ macOS runner / 借用的 Mac；不要将构建失败当作设备不支持。

下载包中的 `WatchStress-resign-required.ipa` **不能直接安装**，还需要对手机、Watch、
表盘扩展分别签名，并保留 HealthKit 和 App Group 权限。

### 3. 先验证 Windows 手表侧载工具

参考独立社区项目：
<https://github.com/Rzbck/iloader-watch-companion>

这不是普通 iLoader 稳定版自带的已承诺功能。项目的已知验证版本：

- iLoader：`70f37e9b4afc659ab44ec1944c034093f4cda416`
- isideload：`f7b9f3da570edd6824c29680545e710846d07df5`

截至本工程准备时，入口仓库没有发布可直接下载的 Windows 安装包；应按照作者文档
从对应实现仓库获取或编译版本，不能假定下载普通 iLoader 就能安装 Watch App。
此处只提供验证入口，不附带未经核实的安装程序。

需要逐项验证：

1. Windows 能通过数据线识别已解锁并信任电脑的 iPhone。
2. 工具能发现 iPhone 配对的 S12，而不只是发现 iPhone。
3. 能给手机、Watch、表盘扩展注册 App ID 和适用的签名描述文件。
4. 签名后保留 HealthKit 和 App Group 权限。
5. 如果工具重写 Bundle ID / App Group，它也必须同步改写各包的
   `WKCompanionAppBundleIdentifier` 与自定义 `StressAppGroup` 键。
6. 按系统提示在手机、手表开启开发者模式；第三方工具在你的系统版本上能否触发
   开发者模式入口仍需实测。
7. 手机 App 和 Watch App 都能安装并启动。

只装上手机 App，不等于已经完成手表安装。普通 iPhone IPA 侧载工具不一定支持
Watch 的签名和安装路径，不要通过删除 Watch 或表盘扩展来绕过错误。

### 4. 验证健康数据和表盘

在手表打开「压力观察」→「授权健康数据」→允许读取 HRV、心率→「刷新」。
如果未授权或没有样本，显示空状态；读取权限是否被拒绝无法由 App 直接确认。
可在系统健康权限设置中检查，或等待手表产生并同步样本后再刷新。

在支持对应组件形状的表盘中编辑组件，选择「压力观察」。圆形、矩形、单行的
位置是否可用取决于你选的表盘。系统控制表盘刷新时机，更新请求不保证即时显示。

无个人基线时仍可看到 HRV 和时间；满足基线条件后才出现压力估计。
第一版需要打开手表 App 刷新缓存，随后再验证后台更新方案。

### 5. 免费签名到期

免费 Apple Personal Team 的描述文件 7 天后过期，必须在到期前重新签名安装。
本工程未实现自动续签，手表与扩展的续签也需要验证，不保证手机续签后手表一起续签。
付费开发者账号可以降低续签频率，但不属于永久签名。

## 能借到 Mac：更稳妥的真机路径

1. 安装支持你的系统版本的 Xcode 27+，再执行 `brew install xcodegen`。
2. 在工程目录执行 `xcodegen generate`，打开生成的 `WatchStress.xcodeproj`。
3. 在 Xcode 登录自己的 Apple 账号，为三个 Target 选择自己的 Personal Team。
4. 确认手机和 Watch Target 启用了 HealthKit，三个 Target 配置相同的 App Group。
5. 按需要在 `Configuration/Common.xcconfig` 修改标识；App Group 值也要一起修改。
6. 将 iPhone 与 Mac 配对，按 Xcode 提示配对 Watch 并开启开发者模式。
7. 选择 `WatchStressPhone` scheme，在 iPhone 上运行。
8. 选择 `WatchStressWatch` scheme，在 Watch 上运行。
9. 依次验证授权、HRV 查询、表盘组件显示和过期状态。

## 目录

- `project.yml`：三个 Target、Bundle 关系、HealthKit / App Group 权限。
- `Configuration/Common.xcconfig`：Bundle 前缀与 App Group 标识。
- `Core/`：独立 Swift Package，含基线、数据有效性和过期逻辑测试。
- `Phone/`、`Watch/`：两个 App 的入口。
- `Shared/`：HealthKit 查询、摘要界面、设备本地缓存。
- `Complication/`：手表 WidgetKit 表盘扩展。
- `scripts/build-unsigned.sh`：XcodeGen + Xcode 未签名编译、打包。
- `scripts/prepare_resigning.py`：保留权限的本地占位签名；不使用 Apple 账号。
- `scripts/validate_ipa.py`：验证手机 / Watch / 表盘扩展的嵌套关系。
- `.github/workflows/build.yml`：手动触发的云构建。

## 验收记录

在 `VALIDATION.md` 记录实际验证结果；不要把源码检查或打包成功记为真机成功。
下一阶段应先通过真机安装，再考虑 HealthKit 后台投递、数据同步与续签自动化。

## 官方与项目资料

- Xcode 系统要求：<https://developer.apple.com/xcode/system-requirements>
- Xcode 27 runner：<https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md>
- GitHub runner 费用：<https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job>
- 免费账号限制：<https://developer.apple.com/help/account/basics/about-your-developer-account>
- watchOS 权限：<https://developer.apple.com/help/account/reference/supported-capabilities-watchos/>
- Windows Watch 侧载：<https://github.com/Rzbck/iloader-watch-companion>

