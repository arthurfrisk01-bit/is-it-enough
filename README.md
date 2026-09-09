# 够了吗 (Is It Enough)

[![Release](https://img.shields.io/github/v/release/arthurfrisk01-bit/is-it-enough?label=release)](https://github.com/arthurfrisk01-bit/is-it-enough/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](#平台支持)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-blue)](#许可证)

> 在你无意识刷手机的时候，轻轻问一句「够了吗」。

「够了吗」是一个本地优先的数字健康应用：它监测你在指定应用上的连续使用时长，达到阈值时用两级提醒把你叫醒——你可以选择「再刷一会儿」，也可以选择「现在放下」，然后进入一段呼吸练习，从屏幕里抽离出来。数据全部留在本机，不联网、不注册、不上传。

## 核心功能

- **无意识刷机监测**：Android `UsageStatsManager` 事件流推断前台应用，5 秒轮询，按应用累计连续使用时长；切换应用 30 秒内返回会继续累计（消抖），本应用与桌面不计入。
- **两级提醒强度**：弱提醒是顶部卡片，不阻断下方操作；强提醒是全屏遮罩 + 呼吸圆环，把选择权交给你而不是强行中断。
- **原生全屏悬浮窗**：由 `WindowManager` + `TYPE_APPLICATION_OVERLAY` 原生绘制（`ReminderOverlay.kt`），不依赖第二个 Flutter 引擎；界面销毁或按钮回传失败时自动关窗，不会留下挡屏空窗。
- **系统通知兜底**：悬浮窗权限被拒或被系统收回时走通知通道；锁屏时由系统全屏 Intent 打断，点击通知直接进入完整提醒页。
- **「再刷」有节制**：默认最多连点 3 次「再刷 5 分钟」，之后自动缩短为 2 分钟。
- **呼吸引导**：4 秒吸气 / 4 秒呼气，持续 5 分钟，配震动反馈。
- **提醒通道自检**：设置页一键真实弹出一次悬浮窗（2.5 秒自动关闭），不用等真的刷够时间就能验证通道是否通。
- **权限诊断与日志导出**：一键采集权限/服务/机型状态，支持全量运行日志导出，方便定位「为什么没提醒」。
- **本地统计**：触发次数、选择放下次数等只存在本机 `shared_preferences`。
- **主动专注模式**：手动开启一段专注计时，对应 iOS 极简版的使用方式。

## 平台支持

| 平台 | 能力 |
| --- | --- |
| **Android** | 完整功能：后台监控 + 原生全局悬浮窗 + 通知兜底 + 开机自启 |
| **iOS** | 极简版：受系统限制不做后台监听，由用户主动触发呼吸引导与专注计时 |

## 下载

- GitHub Releases（APK 附件）：https://github.com/arthurfrisk01-bit/is-it-enough/releases/latest
- 官网：https://isitenough.naamtaan1008.com/

当前版本：**v0.3.8 (18)** · 包名 `com.isitenough.app` · minSdk 24 / targetSdk 36

## 技术栈

- **框架**：Flutter 3.x / Dart（`sdk >=3.3.0 <4.0.0`）
- **状态管理**：Provider（`ChangeNotifier` 服务 + 仓库）
- **本地存储**：`shared_preferences`（纯本地，无账号体系、无网络请求；`sqflite` 已移除）
- **平台通道**：`MethodChannel` + Kotlin 原生
  - `UsageStatsBridge`：前台应用查询
  - `ReminderOverlayBridge`：原生悬浮窗显示/隐藏/权限/按钮回传
  - `MonitorForegroundService` + `BootReceiver`：后台保活与开机自启
  - `LogBridge` / `LogStore` / `DiagnosticsCollector`：日志与诊断
- **通知**：`flutter_local_notifications`（仅作兜底通道）
- **权限与跳转**：`permission_handler`、`android_intent_plus`、`device_info_plus`（厂商自启 / 省电白名单页）
- **触感**：`vibration`

## 项目结构

```
lib/
├── main.dart              # UI 入口：初始化存储 / 通知 / 监控 / 提醒链路
├── monitor_main.dart      # 后台服务使用的无界面 Dart 入口
├── app.dart               # MaterialApp 根组件、主题与导航
├── core/                  # 常量（阈值/轮询/消抖）、提醒模式、主题、导航
├── shared/services/       # 日志、通知、权限、设置、统计、诊断、日志导出
└── features/
    ├── onboarding/        # 首次引导与权限授予
    ├── monitoring/        # UsageStats 轮询与前台识别
    ├── reminder/          # 强弱提醒视图、原生悬浮窗通道、提醒控制器
    ├── breathing/         # 5 分钟呼吸引导（CustomPainter 圆环）
    ├── settings/          # 设置页、配置与统计仓库
    ├── statistics/        # 本地统计页
    └── logs/              # 日志查看与导出

android/app/src/main/kotlin/com/isitenough/app/
├── MainActivity.kt / AppBridges.kt
├── UsageStatsBridge.kt            # 前台应用查询
├── ReminderOverlay.kt             # 原生全屏/卡片悬浮窗
├── ReminderOverlayBridge.kt       # 悬浮窗通道
├── MonitorForegroundService.kt    # 后台监控服务
├── BootReceiver.kt                # 开机自启
└── LogBridge.kt / LogStore.kt / DiagnosticsCollector.kt
```

## 快速开始

```bash
git clone https://github.com/arthurfrisk01-bit/is-it-enough.git
cd is-it-enough
flutter pub get
flutter run
```

构建发布版本：

```bash
flutter analyze                  # 期望 No issues found
flutter test                     # 期望 All tests passed
flutter build apk --release
```

> 发布构建注意：`notification_icon` 只被 Dart 字符串引用，AGP 的资源收缩会把它当未使用资源裁掉，必须由 `android/app/src/main/res/raw/keep.xml` 保活；新增同类资源也要一并加进去。

## Android 权限说明

| 权限 | 用途 |
| --- | --- |
| `PACKAGE_USAGE_STATS` | 识别前台应用、统计使用时长（需用户在系统设置中手动授予「使用情况访问」） |
| `SYSTEM_ALERT_WINDOW` | 绘制全局悬浮窗提醒 |
| `POST_NOTIFICATIONS` | 通知兜底通道 |
| `USE_FULL_SCREEN_INTENT` | 锁屏时全屏打断（Android 14+ 需系统允许） |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` | 后台监控保活 |
| `RECEIVE_BOOT_COMPLETED` | 开机自启 |
| `WRITE_EXTERNAL_STORAGE` | 导出日志文件 |

首次运行会引导你逐项完成授权；设置页内也提供权限诊断入口。

## 隐私

- 不联网、无账号、无埋点，不上传任何使用记录或个人信息。
- 配置与统计只保存在本机 `shared_preferences`。
- 日志仅在本机留存，需要你主动导出才会离开设备。

## AI 协作说明（Vibe Coding）

本项目以 **Vibe Coding** 方式开发：需求定义、方案取舍与实机验收由人负责；代码实现、缺陷定位、重构与发布流程由 AI 编码代理执行，全过程以真机日志为准闭环迭代（现象 → 日志取证 → 根因定位 → 修复 → 重新构建 → 实机复验）。

- **编码代理**：Hermes Agent（Nous Research）
- **参与模型**：DeepSeek V4.1 Flash · DeepSeek V4 Flash · Claude Opus 5 · Claude Fable 5
- **代表性产出**：
  - 提醒通道从 `flutter_overlay_window`（独立 Flutter 引擎，实机从不回执 `shareData`）迁移到原生 `WindowManager` 悬浮窗，彻底解决「只有通知、没有前台全屏」；
  - 定位 release 资源收缩裁掉通知图标导致的 `invalid_icon` 静默失败，用 `res/raw/keep.xml` 保活；
  - 前台识别由 `lastTimeUsed` 聚合改为事件流推断，修掉前台判定不准。

> AI-assisted development · Vibe Coding with Hermes Agent

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request。反馈问题时建议附上应用内导出的日志，能显著加快定位速度。
