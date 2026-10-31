# 览课 · iOS 个人版

原生 SwiftUI 应用，面向福建农林大学旧版教务系统。支持 iOS 17 及以上，包含登录、学期课表、成绩、考试安排、离线记录和学校原网页入口。

**交付状态：0.3.0（构建9）。39项核心测试、模拟器编译、真机归档和IPA上传全部通过。主屏幕组件小号/中号设计预览已检查；Sideloadly签名后的真实数据共享仍待安装验证。**

新增日期课表、列表/表格切换、手动课程、独立搜索及实时活动扩展。详见 [更新说明](UPDATE-0.3.0.md)。强制关闭应用后，不保证实时活动准时变色和结束。

## 你没有 Mac：这样使用

整体步骤：GitHub 保存源码 → GitHub 的 Mac 编译 → 下载未签名 IPA → Windows 签名 → 安装到 iPhone。

1. 将项目解压到一个文件夹。项目根目录应同时包含 `FAFUCampus.xcodeproj`、`FAFUCampus`、`Packages` 和 `.github`。
2. 用自己的 GitHub 账号创建仓库，将**项目文件夹内部的内容**提交到默认分支。不要把整个项目再多包一层目录；`.github/workflows/build-ios.yml` 必须在仓库根目录下。可以用 GitHub Desktop 新建本地仓库，再复制这些文件、提交并发布；必须包含 `.github`。
3. 在仓库网页打开 **Actions → Build iOS app → Run workflow**。main 分支源码更新会自动构建，也支持手动运行。
4. 流程会依次运行核心测试、编译模拟器版本、归档 iPhone 版本，再打包 IPA。全部成功后，在运行页面底部 **Artifacts** 下载 `FAFUCampus-unsigned-IPA`。
5. 解压下载的 artifact，得到 `FAFUCampus-unsigned.ipa`。它还没有 Apple 签名，不能直接点开安装。
6. 在 Windows 从 [Sideloadly 官方网站](https://sideloadly.io/)下载工具，按其说明安装所需 Apple 驱动组件。用数据线连接 iPhone，在手机上选择信任电脑。
7. 在 Sideloadly 选择你的 iPhone，载入上面的 IPA，用自己的 Apple 账号完成签名和安装。Apple 账号信息只在你自己操作的签名工具中输入；不要填写到源码、GitHub Secrets 或教务应用里。
8. 如果手机提示，按系统指引在“设置 → 隐私与安全”开启开发者模式，并在“设置 → 通用 → VPN 与设备管理”信任相应开发者。具体入口以手机系统提示为准。
9. 打开“览课”，先点“先体验界面”检查四个页面；再退出示例，用自己的教务账号登录。

免费 Apple 账号签名通常有 7 天有效期，需要续签；Sideloadly 支持在电脑和手机满足连接条件时自动刷新。实际可安装数量、签名和续签规则以 [Sideloadly FAQ](https://sideloadly.io/faq) 为准。

GitHub 公共仓库的标准托管 runner 可免费使用，私有仓库会消耗账号的 Actions 额度；运行前可在账号设置查看用量。无需为本项目把 Apple 签名证书或学校密码上传到 GitHub。参见 [GitHub runner 说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)和[手动运行工作流](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)。

若编译任务标红，先打开失败的步骤查看错误；`Test parser and encoding` 是核心测试，`Build for iOS Simulator` 是应用编译。可以把错误日志交给开发者修复，日志应不含学校密码，因为工作流不访问个人教务数据。

## 以后有 Mac 时

先在项目根目录运行 `swift Scripts/RenderIcon.swift` 生成同款叶子图标，再使用 Xcode 26 或更新版本打开 `FAFUCampus.xcodeproj`，等待 Swift Package Manager 解析 SwiftSoup。选择 FAFUCampus scheme，可先运行 iOS 模拟器的示例模式。

连接真机后，在 Signing & Capabilities 中选择自己的 Team；如遇 Bundle ID 冲突，将 `app.personal.fafucampus` 改成你自己的唯一标识，然后运行。核心测试可在终端执行：

```sh
swift test --package-path Packages/CampusCore
```

## 已实现的功能

- 登录：学号、密码、手动输入图片验证码；读取实时隐藏字段、Cookie 和会话路径。
- 课表：选择学年、学期，按星期查看原始课程内容；处理表格的 rowspan/colspan，保留周次和单双周文字。
- 成绩：查询全部学年学期，在本机筛选学年、学期或关键词；查看全部原始字段，保留“优秀”“补考中”等非数字值。
- 考试：查询当前或指定学期，显示考试记录和详情。
- 缓存：保存最新成功查询结果，显示更新时间。重新启动后可显式进入离线查看。
- 账号：返回登录时可保留离线数据；也可以清除全部本地数据。切换账号时不会显示前一账号的数据。
- 原网页：独立的临时网页会话，便于核对学校页面、修改初始密码；需要单独登录。
- 示例：明确标注“示例数据”，不需要登录或联网，不会覆盖真实缓存。

## 本版的范围与待验证项

- 对接依据是用户提供的 iFAFU 1.5.7 APK 的网络行为，未复制其应用界面或学校标志，也未使用真实学生网页作为测试材料。
- 学校当前页面可能与 APK 发布时不同。首次真机登录是必要的联调步骤；成功编译不能证明所有学校接口当前可用。
- 课表以“学期课表”展示，不推断当前教学周；调停课原始说明单独展示，尚未自动合并到课程。考试日期也保留学校原文，不猜测“待安排”的日期。
- 本地解析页面结构异常时显示错误，不把错误页当成空课表覆盖缓存。
- 重启后自动验证并恢复会话；断网时显示离线数据并提供“恢复连接”。学校使会话过期时仍需重新输入验证码，不保存密码进行自动重试。主动返回登录会清除保存的会话。
- App 本身不提供校园网穿透。若教务入口限制校园网，设备需要学校允许的网络或 VPN。
- 未加入选课、评教、修改成绩、后台定时刷新或通知。

## 数据流和实现

```text
手机 → jwgl.fafu.edu.cn：登录页 / 验证码 / 登录表单 / 查询网页
学校网页 → 手机内解析 → 本地缓存与原生界面
```

基础地址：`http://jwgl.fafu.edu.cn/(会话编号)/`

| 功能 | 页面 |
|---|---|
| 登录 | default2.aspx |
| 验证码 | CheckCode.aspx |
| 学生主页 | xs_main.aspx |
| 课表 | xskbcx.aspx |
| 成绩 | xscjcx_dq_fafu.aspx |
| 考试 | xskscx.aspx |

`CampusCore` 包含 URLSession 请求、GB18030/GBK 兼容编码、HTML 解析和数据模型；界面与磁盘缓存位于 `FAFUCampus/`。HTML 解析使用 [SwiftSoup 2.7.7](https://github.com/scinfu/SwiftSoup/tree/2.7.7)，版本固定，避免自动升级改变构建结果。

由于已确认的学校入口是 HTTP，Info.plist 仅为 `jwgl.fafu.edu.cn` 配置 ATS 例外，登录页也明确告知未加密传输。没有对所有域名关闭 ATS。参见 [Apple ATS 说明](https://developer.apple.com/documentation/security/preventing-insecure-network-connections)。

应用不调用 iFAFU 的课表解析服务器。密码不会落盘，会话路径及 Cookie 保存在本机钥匙串（WhenUnlockedThisDeviceOnly，不同步到 iCloud）；缓存包含学号、姓名和教务记录，使用 iOS 完整文件保护，并排除 iCloud 备份。保留缓存时，能打开已解锁手机中本应用的人仍可查看缓存。清除本地数据可删除这些记录。

## 工程文件

- `FAFUCampus.xcodeproj`：可直接打开的 Xcode 项目与共享 scheme。
- `FAFUCampus/`：SwiftUI、临时网页视图、状态管理和缓存。
- `Packages/CampusCore/`：核心逻辑、26 项 XCTest 测试和合成 HTML 测试页面。
- `.github/workflows/build-ios.yml`：手动云端测试、构建、生成未签名 IPA。
- `TEST_PLAN.md`：真实设备验收步骤。
- `BUILD_STATUS.md`：本次实际完成的检查及未完成项。

这是个人学习工具，非福建农林大学官方应用。


## 0.1.0 · 构建 3

- 多任务切换保留正常界面快照，移除隐私遮罩。
- 会话保存在设备钥匙串，启动时验证身份；不将缓存等同于已认证状态。
- 登录页移除用户圈出的三段介绍；关于内容移到“我的 → 关于览课”，第一行为“版本 0.1.0”。
- Xcode 26+ 构建启用系统 Liquid Glass 导航和标签栏；登录按钮采用 glassProminent，旧系统及减少透明度时回退。
- AppIcon.icon 为分层图标。Scripts/RenderIcon.swift 在 Mac 构建前渲染与参考图相同的 leaf.fill 图样，并生成浅色、深色及着色后备图标。光照由系统生成，不在图片里绘制假玻璃。
- 云端使用 macos-15-intel，并通过 DEVELOPER_DIR 明确选择 Xcode 26.3，检查 iOS SDK >= 26。更新时必须一并替换工作流及 Scripts 文件夹。

参考：[Apple Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)、[Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)。
