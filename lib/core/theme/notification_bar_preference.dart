import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// آیا نوار «بدون اینترنت» (OfflineBanner) در پوسته‌ی اصلی نمایش داده
/// شود؟ — کنترلری هم‌الگو با ThemeController، برای سوییچِ «نمایش نوار
/// اعلان» در صفحه‌ی تنظیمات.
class NotificationBarPreference {
  NotificationBarPreference._();
  static const _storage = FlutterSecureStorage();
  static const _key = 'show_notification_bar';
  static final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(
    true,
  );

  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      // پیش‌فرض: فعال (نمایش داده شود) مگر این‌که کاربر صریحاً خاموش کرده باشد
      isEnabledNotifier.value = saved != 'off';
    } catch (_) {}
  }

  static Future<void> setEnabled(bool enabled) async {
    isEnabledNotifier.value = enabled;
    try {
      await _storage.write(key: _key, value: enabled ? 'on' : 'off');
    } catch (_) {}
  }
}
