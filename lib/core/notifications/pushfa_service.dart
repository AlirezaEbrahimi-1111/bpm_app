import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../features/tasks/task_detail_page.dart';

/// فازِ ۰ (Push) — پوشفا انتخاب شد (بعدِ ردِ متریکس/OneSignal/نجوا/چابک؛
/// شرحِ کاملِ تصمیم در pubspec.yaml است). چون SDKِ فلاترِ رسمی ندارد،
/// از یک MethodChannel به کدِ نیتیوِ Kotlin (در MainActivity.kt /
/// PushfaApplication.kt) وصل می‌شویم — خودِ راه‌اندازیِ SDK سمتِ نیتیو
/// (در Application.onCreate) انجام می‌شود؛ این کلاس فقط شناساییِ کاربر
/// و دیپ‌لینک را مدیریت می‌کند.
class PushfaService {
  PushfaService._();

  static const _channel = MethodChannel('ir.itmalek.bpm/pushfa');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        _handleDeepLink(call.arguments?.toString());
      }
      return null;
    });
  }

  /// بعدِ لاگین/ورودِ خودکار — کاربر را با همان user.id به‌عنوانِ
  /// alias به دستگاه وصل می‌کند تا بک‌اند بتواند دقیقاً به همین کاربر
  /// Push بفرستد
  static Future<void> identify(dynamic userId) async {
    if (userId == null) return;
    try {
      await _channel.invokeMethod('addAlias', {
        'label': 'user_id',
        'value': userId.toString(),
      });
    } catch (_) {}
  }

  /// موقعِ خروج — تا کاربرِ بعدی که با همین گوشی لاگین می‌کند، اشتباهاً
  /// پیامِ کاربرِ قبلی را نگیرد
  static Future<void> clearIdentity() async {
    try {
      await _channel.invokeMethod('removeAlias', {'label': 'user_id'});
    } catch (_) {}
  }

  // 🔧 طبقِ قراردادِ payload: بک‌اند یک URLِ سبک مثلِ
  // "malekbpm://task?id=123" در link_url می‌گذارد
  static void _handleDeepLink(String? url) {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host != 'task') return;
    final taskId = int.tryParse(uri.queryParameters['id'] ?? '');
    if (taskId != null) {
      Get.to(() => TaskDetailPage(taskId: taskId));
    }
  }
}
