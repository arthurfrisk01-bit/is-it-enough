import 'package:flutter/material.dart';

/// 全局 Navigator Key。
///
/// Overlay 或后台回调中需要跳转呼吸页/主页面时，
/// 无法直接使用 BuildContext，因此统一走这个 Key。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
