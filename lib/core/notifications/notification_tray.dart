import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 🔧 طبق درخواست: پوش‌های یک کار با بازشدنِ آن کار از نوارِ اعلانِ گوشی پاک
/// شوند. پوش را SDKِ متریکس نشان می‌دهد و شناسه‌ی کار در آن قابل‌خواندن نیست،
/// پس با همان عنوان و متنی که سرور در اعلانِ داخلِ اپ هم ذخیره کرده پیدا می‌شود.
class NotificationTray {
  NotificationTray._();

  static const _channel = MethodChannel('malekbpm/notifications');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> hasActive() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasActive') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelMatching(List<Map<String, String>> items) async {
    if (!_supported || items.isEmpty) return;
    try {
      await _channel.invokeMethod('cancelMatching', items);
    } catch (_) {}
  }
}

/// شماره‌ی کارِ یک اعلان. لینک مقدم است چون در اعلانِ روتین related_id
/// شماره‌ی روتین است، نه کار.
int? taskIdOfNotification(Map notif) {
  final link = notif['link']?.toString() ?? '';
  final match = RegExp(r'task-detail\.php\?id=(\d+)').firstMatch(link);
  if (match != null) return int.tryParse(match.group(1)!);
  final type = notif['related_type']?.toString();
  final relatedId = int.tryParse(notif['related_id']?.toString() ?? '') ?? 0;
  if ((type == 'task' || type == 'checklist') && relatedId > 0) {
    return relatedId;
  }
  return null;
}
