# 够了吗 (Is It Enough)

一个帮助你打破无意识刷手机习惯的跨平台数字健康应用。

## 简介

在日常生活中，我们常常不知不觉地拿起手机，在各个应用之间切换浏览，直到突然意识到已经过去了很长时间。这个应用通过温和的提问和呼吸引导，帮你在陷入无意识浏览时及时察觉并做出选择。

## 核心功能

**智能监控**  
监测你在特定应用上的使用时长，当达到设定阈值时触发提醒。

**温和提醒**  
提供弱提醒（顶部卡片）和强提醒（全屏引导）两种模式，用"再刷几分钟"或"现在放下"的方式，让你自主选择而非强制中断。

**呼吸引导**  
当你选择放下手机时，提供一个5分钟的呼吸练习页面，帮助你从手机中抽离，重新专注当下。

**隐私优先**  
所有数据仅存储在本地设备，不上传任何使用记录或个人信息。

## 平台支持

- **Android**: 完整功能，包括后台监控和全局悬浮窗提醒
- **iOS**: 简化版本，用户主动触发呼吸引导（受系统限制，不支持后台监控）

## 开发环境

本项目基于 Flutter 开发，需要以下环境：

- Flutter SDK 3.3.0 或更高版本
- Dart 3.0+
- Android Studio / Xcode（用于构建对应平台）

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/arthurfrisk01-bit/is-it-enough.git
cd is-it-enough

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

## Android 特别说明

应用需要以下系统权限才能正常工作：

- **使用情况访问权限**: 用于检测前台应用
- **悬浮窗权限**: 用于显示提醒卡片
- **电池优化白名单**: 确保后台监控不被系统杀掉

首次运行时，应用会引导你完成这些权限的授予。

## 项目结构

```
lib/
├── features/
│   ├── monitoring/      # 应用使用监控
│   ├── reminder/        # 提醒展示和控制
│   ├── breathing/       # 呼吸引导页
│   └── settings/        # 设置页面
├── shared/              # 共享服务和工具
└── core/                # 核心配置和常量

website/                 # 项目官网静态页面
deploy/                  # 部署脚本和配置
```

## 技术栈

- **框架**: Flutter 3.x
- **状态管理**: Provider
- **本地存储**: shared_preferences + sqflite
- **平台交互**: MethodChannel (Android UsageStatsManager)
- **悬浮窗**: flutter_overlay_window

## 构建发布版本

```bash
# Android APK
flutter build apk --release

# iOS IPA (需要 macOS + Xcode)
flutter build ios --release
```

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request。
