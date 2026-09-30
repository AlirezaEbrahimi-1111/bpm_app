import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// سه‌حالتیِ اندازه‌ی فونت — طبقِ درخواست: کوچک/متوسط/بزرگ با ±۲۰٪
enum AppFontSize { small, medium, large }

extension AppFontSizeX on AppFontSize {
  double get scale => switch (this) {
    AppFontSize.small => 0.8,
    AppFontSize.medium => 1.0,
    AppFontSize.large => 1.2,
  };

  String get label => switch (this) {
    AppFontSize.small => 'کوچک',
    AppFontSize.medium => 'متوسط',
    AppFontSize.large => 'بزرگ',
  };
}

/// مدیریتِ اندازه‌ی فونتِ کلِ اپ. با `MediaQuery.textScaler` در ریشه‌ی اپ
/// (main.dart، پارامترِ builder) اعمال می‌شود — یعنی همه‌ی fontSizeهایِ
/// هاردکدِ موجود در کلِ پروژه، خودکار با همین ضریب اسکیل می‌شوند، بدونِ
/// نیاز به دست‌زدن به تک‌تکِ Textها.
class FontSizePreference {
  FontSizePreference._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'font_size';

  static final ValueNotifier<AppFontSize> sizeNotifier =
      ValueNotifier<AppFontSize>(AppFontSize.medium);

  /// یک‌بار در شروعِ اپ صدا زده می‌شود تا انتخابِ ذخیره‌شده (اگر باشد)
  /// اعمال شود. پیش‌فرض: «متوسط».
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      sizeNotifier.value = switch (saved) {
        'small' => AppFontSize.small,
        'large' => AppFontSize.large,
        _ => AppFontSize.medium,
      };
    } catch (_) {
      // خطای خواندن یعنی همان پیش‌فرضِ «متوسط» بماند
    }
  }

  static Future<void> set(AppFontSize size) async {
    sizeNotifier.value = size; // فوری — کلِ اپ بلافاصله ری‌بیلد می‌شود
    try {
      await _storage.write(key: _key, value: size.name);
    } catch (_) {}
  }
}
