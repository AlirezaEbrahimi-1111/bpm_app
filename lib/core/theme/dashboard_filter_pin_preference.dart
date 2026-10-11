import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// فیلترِ پین‌شده‌یِ پیش‌فرضِ داشبورد («همه»/«امروز»/«عقب افتاده»/«منتخب»).
///
/// 🔧 طبقِ درخواست: برخلافِ همین قابلیت در نسخه‌ی وب (که یک تنظیمِ
/// روزانه‌ی سرور است و هر روز خودکار ریست می‌شود)، در اپ به‌صورتِ
/// **محلی و دائمی رویِ گوشی** ذخیره می‌شود: تا وقتی خودِ برنامه حذف
/// نشود، این انتخاب باقی می‌ماند.
class DashboardFilterPinPreference {
  DashboardFilterPinPreference._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'dashboard_pinned_filter';

  static final ValueNotifier<String?> pinnedNotifier = ValueNotifier<String?>(
    null,
  );

  /// یک‌بار در شروعِ اپ صدا زده می‌شود
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) {
        pinnedNotifier.value = saved;
      }
    } catch (_) {
      // خطای خواندن یعنی هیچ‌چیز پین‌نشده بماند
    }
  }

  static Future<void> toggle(String filter) async {
    final updated = pinnedNotifier.value == filter ? null : filter;
    pinnedNotifier.value = updated;
    try {
      if (updated == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: updated);
      }
    } catch (_) {}
  }
}
