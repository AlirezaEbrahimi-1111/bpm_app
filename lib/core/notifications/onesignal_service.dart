import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../features/tasks/task_detail_page.dart';

/// راه‌اندازیِ OneSignal — سرویسِ Push انتخاب‌شده برایِ اپ (بعدِ بررسیِ
/// متریکس/پوشفا/نجوا؛ یادداشتِ کاملِ تصمیم در pubspec.yaml است).
///
/// هویتِ کاربر (`OneSignal.login`/`logout`) جایِ دیگری، در
/// `ApiClient.saveCachedUser`/`getAutoLoginUser`/`clearToken` مدیریت
/// می‌شود — چون همان‌جا نقطه‌یِ واحدِ شناخته‌شدن/خروجِ کاربر است.
class OneSignalService {
  OneSignalService._();

  static const String _appId = 'c6203850-9f7b-45e0-a0a3-5aeb2baf1648';

  static Future<void> init() async {
    if (kDebugMode) {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    }
    OneSignal.initialize(_appId);

    // 🔧 طبقِ قراردادِ payload: بک‌اند هنگامِ ارسالِ Push، در فیلدِ
    // additionalData مقدارِ {"route": "task_detail", "task_id": "..."}
    // را می‌گذارد؛ با کلیک، همان کارِ مشخص باز می‌شود
    OneSignal.Notifications.addClickListener(_onNotificationClick);
  }

  static void _onNotificationClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (data == null) return;

    final route = data['route']?.toString();
    if (route == 'task_detail') {
      final taskId = int.tryParse(data['task_id']?.toString() ?? '');
      if (taskId != null) {
        Get.to(() => TaskDetailPage(taskId: taskId));
      }
    }
  }
}
