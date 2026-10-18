import 'package:metrix_analytics/Metrix.dart';

/// Push از طریقِ متریکس. خودِ SDK از رویِ meta-data های AndroidManifest
/// خودکار راه‌اندازی می‌شود و ثبتِ توکنِ FCM و درخواستِ مجوزِ نوتیفیکیشن
/// را خودش انجام می‌دهد؛ این‌جا فقط شناساییِ کاربر مدیریت می‌شود — چون
/// متریکس فقط به کاربرانِ شناخته‌شده (customUserId) Push می‌فرستد و
/// بک‌اند با همین user.id هدف‌گیری می‌کند.
class MetrixService {
  MetrixService._();

  static void identify(dynamic userId) {
    if (userId == null) return;
    try {
      Metrix.setUserCustomId(userId.toString());
    } catch (_) {}
  }

  static void clearIdentity() {
    try {
      Metrix.deleteUserCustomId();
    } catch (_) {}
  }
}
