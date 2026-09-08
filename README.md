# 够了吗（Is It Enough）

通过"温和提问 + 呼吸锚定"帮你打破无意识刷手机状态的跨平台数字健康应用。

## 当前进度

- ✅ Flutter 目录骨架 + 核心依赖
- ✅ 设置页：提醒强度 / 触发阈值 / 监控名单 / 权限入口
- ✅ Android `UsageStatsManager` MethodChannel + 5 秒轮询
- ✅ 提醒控制器：弱/强提醒 + "再刷 5 分钟/2 分钟" + "现在放下"
- ✅ 强提醒全屏毛玻璃 / 弱提醒顶部悬浮卡片
- ✅ 呼吸引导页（8 秒周期、5 分钟倒计时、震动反馈）
- ✅ iOS 极简模式入口（"开始专注"按钮直接进入呼吸页）
- ✅ `flutter create . --platforms=android,ios` 补齐 Android/iOS 平台工程
- ✅ Android 包名/命名空间统一为 `com.isitenough.app`，Overlay Service 类名已按 0.4.5 校正

## 运行前

平台工程已补齐（Android / iOS）。日常开发：

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Android 注意事项

1. 需要在系统设置中授予：
   - 使用情况访问权限
   - 悬浮窗权限
   - 电池优化白名单（厂商自启）
2. 当前 `flutter_overlay_window` 0.4.5 的全局悬浮窗使用 `flutter.overlay.window.flutter_overlay_window.OverlayService`；升级插件后请按插件 README 校正 `AndroidManifest.xml`。
3. `UsageStatsManager` 只能推断最近前台应用，无法在 Android 10+ 直接读取当前 Activity，这是平台限制下的标准方案。

## iOS 说明

按 PRD，iOS 不调用私有 API，不做后台监听。用户通过"现在放下 / 开始专注"主动进入全屏黑色呼吸页。

## 数据隐私

所有配置与后续统计只保存在本机（`shared_preferences` / `sqflite`），无账号、无网络上传。

## 官网与发布

- 静态官网：`website/`（功能 / 下载 / 更新 / 隐私）
- HK 生产 Nginx 配置：`deploy/hk/isitenough.conf`
- 一键全量推送到 HK（不经 frp）：`deploy/push-to-hk.sh`
- 说明见 `deploy/README.md`
