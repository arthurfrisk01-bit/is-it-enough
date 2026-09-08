# Is It Enough v0.3.1 - 按应用分类推送提醒

## ✨ 新功能

### 按应用名称分类推送
**功能描述**：提醒通知现在会显示具体应用名称（如"微信"、"抖音"），不再只显示包名。

**实现细节**：
- Android Kotlin层添加 `getAppLabel()` 方法，通过 PackageManager 查询应用显示名称
- `MonitorTriggerEvent` 增加 `appLabel` 字段携带应用名称
- `ForegroundMonitor` 触发提醒时自动查询应用名称
- 系统通知文案优化：`"你在 微信 上已经使用了 15 分钟"`
- 应用未安装或查询失败时回退显示包名

**用户体验提升**：
- 提醒内容更直观易懂（"微信" vs "com.tencent.mm"）
- 系统通知BigText样式展示完整应用名称
- 日志记录同时包含应用名称和包名，方便问题排查

## 🔧 技术细节

### Android Native层
新增MethodChannel方法：
```kotlin
fun getAppLabel(packageName: String): String?
```
- 通过 `PackageManager.getApplicationLabel()` 获取应用显示名称
- 应用未安装时返回 null
- 查询失败时记录错误并返回 null

### Dart层
- `UsageStatsMethodChannel.getAppLabel()` - 封装MethodChannel调用
- `MonitorTriggerEvent.appLabel` - 可空字段，未获取到时为null
- `NotificationReminderService.showReminder()` - 新增必填参数 `appLabel`

## 📦 继承v0.3.0所有修复

保留v0.3.0的核心修复：
- 提醒重复拦截Bug修复
- 强制提醒重复触发修复
- 系统通知三重兜底
- FATAL日志级别
- 提醒通道自检功能

## 🧪 测试建议

1. **应用名称显示测试**：
   - 在常见应用（微信、抖音、微博等）达到阈值
   - 检查通知栏是否显示中文应用名称
   - 查看日志是否同时记录应用名称和包名

2. **兼容性测试**：
   - 测试查询失败时是否正常回退显示包名
   - 验证系统应用（如设置、文件管理器）名称是否正确

3. **性能测试**：
   - 查询应用名称不应影响提醒触发速度（异步查询）
   - 多次触发提醒不应重复查询（缓存机制可选优化）

## 📋 代码质量

- 所有 `flutter analyze` 错误和警告清零
- Kotlin代码遵循Android最佳实践
- 异常处理完善，查询失败不影响提醒功能

## 📦 构建信息

- **版本号**：0.3.1+11
- **APK 大小**：51.0 MB
- **编译环境**：Flutter 3.3+, Dart SDK >=3.3.0 <4.0.0
- **目标平台**：Android（minSdkVersion 24）

---

**升级建议**：v0.3.0用户推荐升级，提醒内容更清晰直观
