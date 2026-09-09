# 够了吗 (Is It Enough)

[![Release](https://img.shields.io/github/v/release/arthurfrisk01-bit/is-it-enough?label=release)](https://github.com/arthurfrisk01-bit/is-it-enough/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](#平台支持)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-blue)](#许可证)

> 打开短视频，本来只想刷五分钟，回过神一个小时没了。

## 你是不是也这样

- 睡前说好只看一会儿，结果刷到凌晨；
- 打开抖音想查个东西，被推荐流带着走，一小时后才想起自己要干嘛；
- 地铁上点开一个视频，坐过站了都没察觉。

不是你不够自律——这些应用本来就设计得让人停不下来。「够了吗」不用蛮横手段，只做一件事：在你刷过头的时候，问你「够了吗?」。

## 它怎么帮你

- **刷久了会提醒你**：在同一个应用上连续刷到设定时长（默认 10 分钟，可选 5 / 10 / 15 / 20），它就会出现，并且直接告诉你**是哪个应用、已经用了多久**。
- **提醒不粗暴，选择权在你**：可以只是顶部一张小卡片，不挡你手上正在做的事；也可以是一块全屏呼吸画面，认真问你一句「够了吗」。选「再刷一会儿」最多给 3 次，之后只给 2 分钟。
- **正在专注？一键勿扰**：写方案、开会、陪家人的时候点一下「1 小时内勿扰」，这段时间它彻底安静，也不会把这段时间算进使用时长。
- **放下了有地方去**：点「现在放下」进入 5 分钟呼吸练习，帮你从屏幕里缓过来，而不是三秒后又摸回手机。
- **看得见的账**：统计页给出今日使用量（按应用排序）和竖向使用时间线，一眼看清时间花在哪。
- **通知栏随时提醒你**：常驻通知实时显示当前应用和已用时长，不用打开 App 也知道自己在刷什么。
- **不用你操心**：自动识别你正在用哪个应用，切走再切回来继续算；它自己不算数，桌面也不算。国产 ROM 的自启动设置有一键引导。
- **你的事只有你知道**：不联网、不注册、不上传，所有记录只留在你手机里。
- **出了问题好排查**：设置页有「提醒通道自检」，一键真实弹一次提醒；还有权限诊断和日志导出，反馈问题不用靠猜。

## 平台支持

| 平台 | 能力 |
| --- | --- |
| **Android** | 完整功能：后台监控 + 原生全局悬浮窗 + 通知兜底 + 开机自启 |
| **iOS** | 极简版(开发中）：受系统限制不做后台监听，由用户主动开启专注计时与呼吸引导 |

## 下载

- GitHub Releases（APK 附件）：https://github.com/arthurfrisk01-bit/is-it-enough/releases/latest
- 官网：https://isitenough.naamtaan1008.com/

当前版本：**v0.4.0 (19)** · 包名 `com.isitenough.app` · minSdk 24 / targetSdk 36

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
