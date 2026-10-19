import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/plan/plan_access.dart';
import '../../core/theme/app_colors.dart';
import 'subscription_page.dart';
import '../../core/navigation/app_nav.dart';

/// اگر امکانی در پلنِ فعلی قفل باشد، ویجت کم‌رنگ و غیرفعال می‌شود و با
/// ضربه، شیتِ تبلیغاتیِ خرید اشتراک باز می‌شود. اگر قفل نبود، خودِ child
/// بدون هیچ تغییری نمایش داده می‌شود.
class PlanGate extends StatelessWidget {
  final PlanFeature feature;
  final String? label;
  final Widget child;

  const PlanGate({
    super.key,
    required this.feature,
    required this.child,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (PlanAccess.allows(feature)) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showPlanUpgradeSheet(label: label, feature: feature),
      child: Opacity(opacity: 0.5, child: IgnorePointer(child: child)),
    );
  }
}

/// برای جاهایی که ویجتِ قفل‌شده نیست (مثلاً قبل از باز کردنِ یک شیت).
/// اگر امکان قفل بود، شیتِ ارتقا را نشان می‌دهد و false برمی‌گرداند.
bool checkPlanAccess(PlanFeature feature, {String? label}) {
  if (PlanAccess.allows(feature)) return true;
  showPlanUpgradeSheet(label: label, feature: feature);
  return false;
}

/// [message] پیامِ خودِ سرور (فیلدِ message در خطای PLAN_RESTRICTED) است؛
/// اگر باشد به‌جای متنِ پیش‌فرض نشان داده می‌شود. [feature] وقتی مشخص
/// باشد (و [message] نباشد)، طبقِ درخواست، پیام دقیقاً پلنِ لازم (نقره‌ای
/// یا طلایی، یا فقط طلایی) را می‌گوید، نه عبارتِ کلی.
void showPlanUpgradeSheet({
  String? label,
  String? message,
  PlanFeature? feature,
}) {
  Get.bottomSheet(
    _PlanUpgradeSheet(label: label, message: message, feature: feature),
    backgroundColor: Colors.transparent,
  );
}

class _PlanUpgradeSheet extends StatelessWidget {
  final String? label;
  final String? message;
  final PlanFeature? feature;

  const _PlanUpgradeSheet({this.label, this.message, this.feature});

  static const _goldColor = Color(0xFFF5B94D);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planLabel = feature != null
        ? PlanAccess.requiredPlanLabel(feature!)
        : null;
    final featureLine = (message != null && message!.trim().isNotEmpty)
        ? message!.trim()
        : label == null
        ? (planLabel != null
              ? 'این امکان فقط در پلن $planLabel قابل استفاده است.'
              : 'این امکان در پلن فعلی شما فعال نیست.')
        : (planLabel != null
              ? '«$label» فقط در پلن $planLabel قابل استفاده است.'
              : '«$label» در پلن فعلی شما فعال نیست.');

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
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
            const SizedBox(height: 22),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFFFD98A), _goldColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _goldColor.withValues(alpha: isDark ? 0.45 : 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'برین اشتراک تهیه کنین',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textStrong,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              featureLine,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textStrong, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Text(
              'با تهیه‌ی اشتراک، این بخش و امکانات بیشتری را یک‌جا فعال کنین.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.6),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  AppNav.back();
                  Get.to(() => const SubscriptionPage());
                },
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                label: const Text(
                  'رفتن به خرید اشتراک',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => AppNav.back(),
              child: Text(
                'فعلا نه',
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
