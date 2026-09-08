# 够了吗（Is It Enough）—— 项目架构与目录设计

> 第一阶段产出：目录骨架 + `pubspec.yaml` 核心依赖。
> 后续按模块逐步实现 Android 全功能 MVP 与 iOS 极简专注版。

## 1. 总体设计原则

- **隐私优先**：配置与统计只保存在本机（`shared_preferences` / `sqflite`），不做账号体系、不联网。
- **平台分叉清晰**：
  - Android：`UsageStatsManager` 轮询 + `flutter_overlay_window` 全局悬浮窗；
  - iOS：不依赖后台监听，走“用户主动开启专注计时”的极简流程。
- **提醒强度可配置**：
  - 弱提醒：非阻断式顶部悬浮 Card；
  - 强提醒：全屏毛玻璃 + 呼吸动画阻断（默认）。
- **可测试性**：业务逻辑放在 domain / data 层，UI 只消费状态。

## 2. 建议目录结构

```text
lib/
├── main.dart                     # 入口：初始化本地存储/通知/权限状态
├── app.dart                      # MaterialApp 根组件、主题与路由
├── core/
│   ├── constants/
│   │   ├── app_constants.dart    # 默认阈值、时长常量、渠道 ID 等
│   │   └── reminder_modes.dart   # 弱/强提醒枚举
│   ├── theme/
│   │   └── app_theme.dart        # 深色为主、毛玻璃氛围
│   └── utils/
│       ├── result.dart           # 统一结果封装（可选）
│       └── time_formatter.dart
├── shared/
│   ├── services/
│   │   ├── permission_service.dart       # 悬浮窗/使用情况/自启动跳转
│   │   ├── local_notification_service.dart
│   │   └── settings_service.dart          # shared_preferences 配置读写
│   └── widgets/
│       └── breathing_circle.dart          # 可复用的呼吸圆环
├── features/
│   ├── settings/                          # 模块 1：设置页
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── app_config.dart
│   │   │   │   └── monitor_rule.dart
│   │   │   └── repositories/
│   │   │       └── settings_repository.dart
│   │   ├── domain/
│   │   │   └── settings_usecase.dart
│   │   └── presentation/
│   │       ├── settings_page.dart
│   │       └── widgets/
│   │           ├── mode_selector.dart
│   │           ├── threshold_selector.dart
│   │           ├── app_blacklist_editor.dart
│   │           └── permission_guide_section.dart
│   ├── monitoring/                        # 模块 2：Android 监听
│   │   ├── data/
│   │   │   ├── usage_stats_method_channel.dart   # MethodChannel 封装
│   │   │   ├── foreground_monitor.dart            # 5s 轮询控制器
│   │   │   └── usage_stats_parser.dart
│   │   ├── domain/
│   │   │   └── monitor_state.dart
│   │   └── presentation/
│   │       └── monitoring_controller.dart
│   ├── reminder/                          # 模块 3：提醒 UI
│   │   ├── overlay_controller.dart        # 根据模式拉起 weak/strong overlay
│   │   ├── weak_reminder_view.dart        # 轻量顶部悬浮 Card
│   │   └── strong_reminder_view.dart      # 全屏毛玻璃阻断
│   └── breathing/                         # “现在放下”后的 5 分钟呼吸页
│       ├── breathing_page.dart
│       ├── breathing_painter.dart         # CustomPainter 脉动圆环
│       └── breathing_timer.dart

android/app/src/main/kotlin/com/isitenough/app/
├── MainActivity.kt
├── UsageStatsBridge.kt         # MethodChannel：查询前台包名
├── OverlayService.kt           # flutter_overlay_window 配套原生逻辑
└── BootReceiver.kt             # 开机自启（可选）

android/app/src/main/
├── AndroidManifest.xml
├── res/xml/
│   ├── overlay_permissions.xml
│   └── usage_stats_permissions.xml
└── res/values/
    └── strings.xml
```

## 3. 模块边界与依赖方向

```text
UI (presentation)
   ↓
Domain / UseCase
   ↓
Data / Repository
   ↓
Platform Channel + SharedPreferences + sqflite
```

- UI 不直接触碰 `MethodChannel`。
- Overlay 视图与主 App 是同一 Dart Isolate 时由 `OverlayController` 管理；若插件要求独立 entrypoint，再拆出 `overlay_main.dart`。

## 4. 当前实现进度（截至当前迭代）

1. ✅ `main.dart` + `app.dart` + 主题与路由骨架；
2. ✅ `SettingsService` + 设置页（提醒模式 / 阈值 / 黑白名单 / 权限入口）；
3. ✅ Android 原生 `UsageStatsManager` MethodChannel + 5 秒轮询；
4. ✅ Overlay 强弱提醒视图、App 内回退页、“再刷 / 现在放下”控制器；
5. ✅ 呼吸引导页（`CustomPainter` + 8 秒周期 + 5 分钟倒计时 + 震动反馈）；
6. ✅ 主动“开始专注”入口（iOS 极简版 / 用户手动模式）；
7. ✅ `flutter create . --platforms=android,ios` 补齐 Gradle/图标工程；
8. ✅ 按 `flutter_overlay_window` 0.4.5 核对 OverlayService 类名与入口指向；
9. 🔧 剩余上线前工作：
   - 厂商自启动页进一步细分（MIUI/HyperOS、HarmonyOS、ColorOS/OriginOS）；
   - 防杀后台、通知保活、统计页。

## 5. 后续实现顺序（扩展）

1. 厂商权限跳转适配与防杀后台兜底；
2. 本地统计（sqflite）与“够了吗”洞察页；
3. 白名单/黑名单增强：读取已安装应用列表。
