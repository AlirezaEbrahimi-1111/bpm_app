import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/plan/plan_access.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';

/// تاریخِ شمسیِ کوتاه، مثلاً ۱۴۰۵/۰۷/۱۲
String formatPlanDate(DateTime d) {
  final j = Jalali.fromDateTime(d);
  final m = j.month.toString().padLeft(2, '0');
  final day = j.day.toString().padLeft(2, '0');
  return toPersianDigits('${j.year}/$m/$day');
}

String planLevelLabel(PlanLevel p) => switch (p) {
  PlanLevel.gold => 'طلایی',
  PlanLevel.silver => 'نقره‌ای',
  PlanLevel.free => 'رایگان',
};

/// شیتِ «جزئیاتِ پلنِ فعلی»: پلن، انقضا، سقفِ کاربر، تعدادِ فعلی، دسترسی وب
void showPlanDetailsSheet() {
  Get.bottomSheet(
    const _PlanDetailsSheet(),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );
}

class _PlanDetailsSheet extends StatelessWidget {
  const _PlanDetailsSheet();

  static const _goldColor = Color(0xFFF5B94D);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final level = PlanAccess.level;
    final exp = PlanAccess.expiresAt;
    final cap = PlanAccess.planUsers;
    final used = PlanAccess.usersUsed;
    final trial = PlanAccess.webTrialEndsAt;
    final web = PlanAccess.webAccess;

    final expiryValue = exp == null ? 'بدون انقضا' : formatPlanDate(exp);

    final capValue = cap == null ? '—' : '${toPersianDigits('$cap')} کاربر';
    final usedValue = used == null
        ? '—'
        : cap == null
        ? '${toPersianDigits('$used')} کاربر'
        : '${toPersianDigits('$used')} از ${toPersianDigits('$cap')}';

    final webValue = web
        ? 'فعال'
        : trial != null && trial.isAfter(DateTime.now())
        ? 'آزمایشی تا ${formatPlanDate(trial)}'
        : 'غیرفعال';

    // تمدیدِ طلایی: از چه تاریخی ممکن است
    String? renewLine;
    if (level == PlanLevel.gold && exp != null) {
      final opens = exp.subtract(
        const Duration(days: PlanAccess.goldRenewalWindowDays),
      );
      renewLine = PlanAccess.canPurchase(PlanLevel.gold)
          ? 'تمدید هم‌اکنون امکان‌پذیر است'
          : 'تمدید از ${formatPlanDate(opens)} امکان‌پذیر است';
    }

    final ratio = (cap != null && cap > 0 && used != null)
        ? (used / cap).clamp(0.0, 1.0)
        : null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: _goldColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'پلن ${planLevelLabel(level)}',
                    style: TextStyle(
                      color: c.textStrong,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'فعال',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row(c, Icons.event_outlined, 'تاریخ انقضا', expiryValue),
            _row(c, Icons.group_outlined, 'سقف کاربر', capValue),
            _row(c, Icons.person_outline_rounded, 'کاربران فعلی', usedValue),
            if (ratio != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: c.borderSoft,
                  color: ratio >= 1 ? c.danger : c.primary,
                ),
              ),
            ],
            _row(c, Icons.language_rounded, 'دسترسی به پنل وب', webValue),
            if (renewLine != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.autorenew_rounded, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        renewLine,
                        style: TextStyle(
                          color: c.textStrong,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.borderSoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'بستن',
                  style: TextStyle(
                    color: c.textStrong,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(AppColors c, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: c.textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
