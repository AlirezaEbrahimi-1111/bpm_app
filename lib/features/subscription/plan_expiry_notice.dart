import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import 'subscription_page.dart';

/// هشدارهای پایانِ پلن / دورهٔ رایگانِ ۱۴ روزه — هم‌منطق با وب.
///
/// - [remindIfNeeded]: فقط برای سرپرستِ سازمان، وقتی ۷ روز یا کمتر مانده؛ روزی یک بار.
///   منبع: GET /api/organization/check-subscription.php (همان API هشدارِ وب؛ سرور
///   روزهای مانده را با تاریخ تهران و از سیستمِ پلن حساب می‌کند).
/// - [showExpired]: وقتی سرور 403 با کد PLAN_EXPIRED می‌دهد (سازمان قفل شده)؛
///   در هر اجرای اپ فقط یک بار.
class PlanExpiryNotice {
  PlanExpiryNotice._();

  static const _storage = FlutterSecureStorage();
  static const _lastReminderKey = 'plan_expiry_reminder_date';
  static const _warningDays = 7;
  static bool _expiredShown = false;
  static bool _checking = false;

  static String _fa(Object s) => s.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)],
      );

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// یادآوریِ «رو به پایان» — از پوستهٔ اصلی بعد از ورود صدا زده می‌شود.
  static Future<void> remindIfNeeded() async {
    if (_checking) return;
    _checking = true;
    try {
      if (await _storage.read(key: _lastReminderKey) == _today()) return;
      final res = await ApiClient.dio.get(
        '/api/organization/check-subscription.php',
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] != true ||
          data['can_manage'] != true ||
          data['has_subscription'] != true) {
        return;
      }
      final days = int.tryParse('${data['days_remaining']}');
      if (days == null || days <= 0 || days > _warningDays) return;

      final isTrial = data['kind'] == 'trial';
      final what = isTrial ? 'دورهٔ رایگان سازمان شما' : 'اشتراک سازمان شما';
      final when = days == 1 ? 'فردا' : '${_fa(days)} روز دیگر';
      final verb = isTrial ? 'خریداری' : 'تمدید';
      await _storage.write(key: _lastReminderKey, value: _today());
      await _dialog(
        title: isTrial ? 'پایان نزدیک دورهٔ رایگان' : 'پایان نزدیک اشتراک',
        message:
            '$what $when تمام می‌شود. برای اینکه کار سازمان متوقف نشود، پلن سازمان را $verb کنید.',
        canBuy: true,
        buyLabel: isTrial ? 'خرید پلن' : 'تمدید پلن',
        laterLabel: 'بعداً',
        danger: days <= 1,
      );
    } catch (_) {
      // هشدار اختیاری است؛ خطای شبکه نباید کاربر را اذیت کند
    } finally {
      _checking = false;
    }
  }

  /// سازمان قفل شده (PLAN_EXPIRED) — سرپرست به صفحهٔ خرید هدایت می‌شود.
  static Future<void> showExpired(String? message) async {
    if (_expiredShown) return;
    _expiredShown = true;
    final role = ApiClient.currentUser?['role']?.toString() ?? '';
    final canBuy = role == 'supervisor' || role == 'admin';
    await _dialog(
      title: 'اشتراک سازمان تمام شده است',
      message: canBuy
          ? '${message ?? 'دورهٔ اشتراک سازمان شما به پایان رسیده است. برای ادامه، پلن سازمان را تمدید کنید.'}'
              '\nبا خرید پلن، همهٔ کارها و اطلاعات بدون تغییر برمی‌گردد.'
          : 'دورهٔ اشتراک سازمان شما به پایان رسیده است. لطفاً به سرپرست سازمان اطلاع دهید تا پلن را تمدید کند.',
      canBuy: canBuy,
      buyLabel: 'خرید یا تمدید پلن',
      laterLabel: canBuy ? 'بعداً' : 'باشه',
      danger: true,
    );
  }

  static Future<void> _dialog({
    required String title,
    required String message,
    required bool canBuy,
    required String buyLabel,
    required String laterLabel,
    bool danger = false,
  }) async {
    final ctx = Get.context;
    if (ctx == null) return;
    final buy = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: Icon(
            danger ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            color: danger ? Colors.red : const Color(0xFFF59E0B),
            size: 34,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, style: const TextStyle(height: 1.7)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(laterLabel),
            ),
            if (canBuy)
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: Text(buyLabel),
              ),
          ],
        ),
      ),
    );
    if (buy == true) Get.to(() => const SubscriptionPage());
  }
}
