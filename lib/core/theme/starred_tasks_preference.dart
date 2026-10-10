import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// لیستِ کارهایِ «منتخب» (ستاره‌دار).
///
/// 🔧 طبقِ درخواست: برخلافِ همین قابلیت در نسخه‌ی وب (که یک تنظیمِ
/// روزانه‌ی سرور است — api/dashboard/prefs-get.php/prefs-set.php — و
/// هر روز خودکار ریست می‌شود)، در اپ به‌صورتِ **محلی و دائمی رویِ گوشی**
/// ذخیره می‌شود: تا وقتی خودِ برنامه حذف نشود، این انتخاب باقی می‌ماند.
class StarredTasksPreference {
  StarredTasksPreference._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'starred_task_ids';

  static final ValueNotifier<Set<String>> idsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  /// یک‌بار در شروعِ اپ صدا زده می‌شود
  static Future<void> init() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved);
        if (decoded is List) {
          idsNotifier.value = decoded.map((e) => e.toString()).toSet();
        }
      }
    } catch (_) {
      // خطای خواندن یعنی لیستِ خالی بماند
    }
  }

  static bool isStarred(dynamic taskId) =>
      idsNotifier.value.contains(taskId.toString());

  static Future<void> toggle(dynamic taskId) async {
    final id = taskId.toString();
    final updated = Set<String>.from(idsNotifier.value);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    idsNotifier.value = updated; // فوری — همه‌جا (داشبورد و جزئیاتِ کار)
    try {
      await _storage.write(key: _key, value: jsonEncode(updated.toList()));
    } catch (_) {}
  }
}
