import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';

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

/// 🔧 طبق درخواست: تبِ پین‌شده‌ی داشبورد، مشترک با وب — همان تنظیمِ سرور
/// (`default_tab` در api/dashboard/prefs-get.php و prefs-set.php). «همه کارها»
/// همان `mine`ِ وب است و «منتخب» همان `starred`. دائمی است تا کاربر لغوش کند.
/// وب تب‌های `delegated` و `recent` را هم دارد که این‌جا نیستند.
class DashboardTabPin {
  DashboardTabPin._();

  static const mine = 'mine';
  static const starred = 'starred';

  static final ValueNotifier<String> notifier = ValueNotifier<String>('');

  static Future<void> load() async {
    try {
      final res = await ApiClient.dio.get('/api/dashboard/prefs-get.php');
      final data = ApiClient.parseResponse(res.data);
      final prefs = data['prefs'];
      if (data['success'] == true && prefs is Map) {
        notifier.value = prefs['default_tab']?.toString() ?? '';
      }
    } catch (_) {
      // بی‌اینترنت: تبِ پیش‌فرض «همه کارها» می‌ماند
    }
  }

  /// فوراً رویِ صفحه عوض می‌شود؛ اگر ذخیره نشد برمی‌گردد و false می‌دهد
  static Future<bool> toggle(String tab) async {
    final previous = notifier.value;
    final updated = previous == tab ? '' : tab;
    notifier.value = updated;
    try {
      final res = await ApiClient.dio.post(
        '/api/dashboard/prefs-set.php',
        data: {'pref_key': 'default_tab', 'pref_value': updated},
      );
      if (ApiClient.parseResponse(res.data)['success'] == true) return true;
    } catch (_) {}
    notifier.value = previous;
    return false;
  }
}
