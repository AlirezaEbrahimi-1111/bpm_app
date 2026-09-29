import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// مدیریت انتخاب دستیِ کاربر برای تمِ روشن/تاریک (سوییچ داخل منوی
/// دراور). پیش‌فرضِ اپ همیشه «روشن» است — مگر این‌که کاربر خودش قبلاً
/// دستی «تاریک» را انتخاب کرده باشد (که در حافظه‌ی امن ذخیره می‌شود و
/// دفعه‌ی بعد هم همان اعمال می‌ماند).
///
/// 🔧 چرا ValueNotifier جدا از Get.isDarkMode:
/// بلافاصله بعد از Get.changeThemeMode، خواندنِ Get.isDarkMode همیشه
/// مقدار تازه را برنمی‌گرداند (چون به rebuild شدنِ GetMaterialApp
/// وابسته است) — همین باعث می‌شد سوییچِ داخل دراور با یک قدم تأخیر
/// (یا اصلاً) به‌روز نشود. isDarkNotifier بلافاصله و بدون وابستگی به
/// زمان‌بندیِ rebuild مقدار درست را می‌دهد.
class ThemeController {
  ThemeController._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(false);

  /// یک‌بار در شروع اپ صدا زده می‌شود تا انتخاب ذخیره‌شده (اگر باشد)
  /// اعمال شود. اگر کاربر هرگز دستی چیزی انتخاب نکرده باشد، پیش‌فرض
  /// «روشن» باقی می‌ماند (نه پیرویِ سیستم).
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      final dark = saved == 'dark';
      isDarkNotifier.value = dark;
      Get.changeThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    } catch (_) {
      // خطای خواندن یعنی همان پیش‌فرضِ روشن بماند
    }
  }

  static Future<void> setDark(bool dark) async {
    isDarkNotifier.value = dark; // فوری — سوییچ بلافاصله جابه‌جا می‌شود
    Get.changeThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    try {
      await _storage.write(key: _key, value: dark ? 'dark' : 'light');
    } catch (_) {}
  }

  static bool get isDark => isDarkNotifier.value;
}
