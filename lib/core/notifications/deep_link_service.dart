import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../features/tasks/task_detail_page.dart';
import '../network/api_client.dart';

/// 🔧 طبق درخواست: لمسِ نوتیفیکیشنِ یک کار، مستقیم همان کار را باز کند.
///
/// سرور پوشِ متریکس را با `url = malekbpm://task/<id>` می‌فرستد؛ اندروید
/// اپ را با همین لینک باز می‌کند و MainActivity.kt آن را از کانالِ
/// `malekbpm/deeplink` به این‌جا می‌دهد. فقط بعد از ورود (از MainShell)
/// فعال می‌شود — اگر اپ با لینک ولی بدونِ ورود باز شده باشد، لینک تا بعد
/// از ورود سمتِ اندروید نگه داشته می‌شود.
class DeepLinkService {
  DeepLinkService._();

  static const _channel = MethodChannel('malekbpm/deeplink');
  static bool _started = false;

  static Future<void> start() async {
    if (kIsWeb || _started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _open(call.arguments as String);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null) {
        // صبر تا اولین فریمِ پوسته ساخته شود، بعد صفحه‌ی کار
        WidgetsBinding.instance.addPostFrameCallback((_) => _open(initial));
      }
    } catch (_) {
      // روی پلتفرم‌هایی که کانال ندارند (مثلاً iOS فعلاً) بی‌اثر
    }
  }

  static void _open(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host != 'task') return;
    final id = int.tryParse(
      uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '',
    );
    if (id == null) return;
    // اعلانِ همین کار دیگر «خوانده‌نشده» نماند
    ApiClient.markTaskNotificationsRead(id);
    Get.to(() => TaskDetailPage(taskId: id));
  }
}
