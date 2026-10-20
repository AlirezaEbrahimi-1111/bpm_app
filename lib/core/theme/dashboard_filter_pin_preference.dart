import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// فیلترِ پین‌شده‌یِ پیش‌فرضِ داشبورد («همه»/«امروز»/«عقب افتاده»).
///
/// 🔧 طبقِ درخواست: داشبورد دو تب دارد («همه کارها» و «منتخب») و هر تب
/// پینِ جدایِ خودش را دارد. برخلافِ همین قابلیت در نسخه‌ی وب (که یک تنظیمِ
/// روزانه‌ی سرور است و هر روز خودکار ریست می‌شود)، در اپ به‌صورتِ
/// **محلی و دائمی رویِ گوشی** ذخیره می‌شود: تا وقتی خودِ برنامه حذف
/// نشود، این انتخاب باقی می‌ماند.
class DashboardFilterPinPreference {
  DashboardFilterPinPreference._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'dashboard_pinned_filter';
  static const _starredKey = 'dashboard_pinned_filter_starred';

  /// پینِ تبِ «همه کارها»
  static final ValueNotifier<String?> pinnedNotifier = ValueNotifier<String?>(
    null,
  );

  /// پینِ تبِ «منتخب»
  static final ValueNotifier<String?> starredPinnedNotifier =
      ValueNotifier<String?>(null);

  static const _validFilters = {'همه', 'امروز', 'عقب افتاده'};

  /// یک‌بار در شروعِ اپ صدا زده می‌شود
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      // مقدارِ قدیمیِ «منتخب» (قبل از جدا شدنِ تب‌ها) دیگر فیلتر نیست
      if (saved != null && _validFilters.contains(saved)) {
        pinnedNotifier.value = saved;
      }
      final savedStar = await _storage.read(key: _starredKey);
      if (savedStar != null && _validFilters.contains(savedStar)) {
        starredPinnedNotifier.value = savedStar;
      }
    } catch (_) {
      // خطای خواندن یعنی هیچ‌چیز پین‌نشده بماند
    }
  }

  static Future<void> toggle(String filter, {bool starredTab = false}) async {
    final notifier = starredTab ? starredPinnedNotifier : pinnedNotifier;
    final key = starredTab ? _starredKey : _key;
    final updated = notifier.value == filter ? null : filter;
    notifier.value = updated;
    try {
      if (updated == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: updated);
      }
    } catch (_) {}
  }
}
