import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/plan/plan_access.dart';
import '../../core/theme/app_colors.dart';
import 'plan_detail_page.dart';
import 'plan_details_sheet.dart';
import 'free_plan_detail_page.dart';
import '../shell/widgets/app_bottom_nav.dart';

/// «خرید و ارتقای اشتراک» — طبقِ طرحِ ارسالی (روشن + تاریک).
///
/// پلنِ فعالِ سازمان (از [PlanAccess]) مشخص می‌شود. پلنِ طلایی فعال فقط
/// در بازه‌ی تمدید (چند روز قبل از انقضا) قابلِ انتخاب دوباره است.
class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  static const _goldColor = Color(0xFFF5B94D);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = PlanAccess.level;
    final expiry = PlanAccess.expiresAt;

    String? statusFor(PlanLevel p) {
      if (current != p) return null;
      return expiry == null ? 'فعال' : 'فعال تا ${formatPlanDate(expiry)}';
    }

    // ── طلایی ──
    final goldIsCurrent = current == PlanLevel.gold;
    final goldRenewable = PlanAccess.canPurchase(PlanLevel.gold);
    final goldButton = (goldIsCurrent && !goldRenewable)
        ? _PlanButton(
            c: c,
            label: 'پلن فعلی شما',
            filled: false,
            accent: c.primary,
            trailingCheck: true,
            onTap: showPlanDetailsSheet,
          )
        : _PlanButton(
            c: c,
            label: goldIsCurrent ? 'تمدید پلن طلایی' : 'انتخاب پلن طلایی',
            filled: true,
            accent: c.primary,
            onTap: () => Get.to(
              () => const PlanDetailPage(plan: SubscriptionPlanType.gold),
            ),
          );

    // ── نقره‌ای ──
    final silverIsCurrent = current == PlanLevel.silver;
    final silverButton = silverIsCurrent
        ? _PlanButton(
            c: c,
            label: 'پلن فعلی شما',
            filled: false,
            accent: c.primary,
            trailingCheck: true,
            onTap: showPlanDetailsSheet,
          )
        : _PlanButton(
            c: c,
            label: 'انتخاب پلن نقره‌ای',
            filled: true,
            accent: c.primary,
            onTap: () => Get.to(
              () => const PlanDetailPage(plan: SubscriptionPlanType.silver),
            ),
          );

    // ── رایگان ──
    final freeIsCurrent = current == PlanLevel.free;
    final freeButton = _PlanButton(
      c: c,
      label: freeIsCurrent ? 'پلن فعلی شما' : 'مشاهده پلن رایگان',
      filled: false,
      accent: c.textMuted,
      trailingCheck: freeIsCurrent,
      // 🔧 طبق درخواست: وقتی پلنِ رایگان، پلنِ فعلیِ کاربر است، جزئیاتش هم
      // (عینِ طلایی/نقره‌ایِ فعال) در همان شیتِ «جزئیاتِ پلن» دیده شود؛
      // برایِ کسی که رایگان نیست و فقط می‌خواهد پلنِ رایگان را از نزدیک
      // ببیند، همچنان صفحه‌یِ کاملِ معرفی باز می‌شود
      onTap: freeIsCurrent
          ? showPlanDetailsSheet
          : () => Get.to(() => const FreePlanDetailPage()),
    );

    return AppShellOverlays(
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: c.textStrong),
          title: Text(
            'خرید و ارتقای اشتراک',
            style: TextStyle(
              color: c.textStrong,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          leading: IconButton(
            icon: Transform.rotate(
              angle: math.pi,
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
            ),
            onPressed: () => Get.back(),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            14 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            _PlanCard(
              c: c,
              isDark: isDark,
              accent: _goldColor,
              iconAsset: 'assets/images/subscription/plan_gold.webp',
              title: 'پلن طلایی',
              subtitle: 'سازمانی و پیشرفته',
              features: const [
                'داشبورد و نظارت مدیریتی',
                'تحلیل گلوگاه‌ها',
                'روتین‌های چند مرحله‌ای',
                'تعریف واحدها و ارجاع نامحدود',
                'دسترسیِ پنلِ وب',
              ],
              badgeAsset: 'assets/images/subscription/badge_special_offer.webp',
              glowIntensity: 1,
              isCurrent: goldIsCurrent,
              statusText: statusFor(PlanLevel.gold),
              button: goldButton,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              c: c,
              isDark: isDark,
              accent: c.primary,
              iconAsset: 'assets/images/subscription/plan_silver.webp',
              title: 'پلن نقره‌ای',
              subtitle: 'تیمی و همکاران',
              features: const [
                'نمای برنامه روزانه، هفتگی و ماهانه',
                'کارِ تیمی و آنلاین',
                'ایجادِ کار برایِ همکاران',
              ],
              glowIntensity: 0.55,
              isCurrent: silverIsCurrent,
              statusText: statusFor(PlanLevel.silver),
              button: silverButton,
            ),
            const SizedBox(height: 8),
            _PlanCard(
              c: c,
              isDark: isDark,
              accent: c.textMuted,
              iconAsset: 'assets/images/subscription/plan_free.webp',
              title: 'پلن رایگان',
              subtitle: 'پایه شخصی',
              features: const [
                'مدیریتِ کارهایِ شخصی',
                'نمایِ ساده و پایه',
                'دسترسیِ محدود',
              ],
              glowIntensity: 0.25,
              isCurrent: freeIsCurrent,
              statusText: statusFor(PlanLevel.free),
              button: freeButton,
            ),
          ],
        ),
        // 🔧 طبق درخواست: نوارِ ناوبرییِ پایین در همه‌ی صفحاتِ اپ — چون این صفحه با Get.to باز می‌شود، Scaffoldِ پوسته‌ی اصلی را نمی‌بیند
        // 🔧 طبق درخواست: دکمهِ شناورِ افزودنِ کار هم مثلِ پوستهِ اصلی
        floatingActionButton: const AppCreateTaskFab(),
        floatingActionButtonLocation: const LoweredDockedFabLocation(),
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final AppColors c;
  final bool isDark;
  final Color accent;
  final String iconAsset;
  final String title;
  final String subtitle;
  final List<String> features;
  final String? badgeAsset;
  final double glowIntensity;
  final bool isCurrent;
  final String? statusText;
  final Widget button;

  const _PlanCard({
    required this.c,
    required this.isDark,
    required this.accent,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.glowIntensity,
    required this.button,
    this.isCurrent = false,
    this.statusText,
    this.badgeAsset,
  });

  @override
  Widget build(BuildContext context) {
    // نورِ دورِ کارت همیشه بنفش است؛ «accent» فقط برایِ زیرنویس است.
    // پلنِ فعال با قابِ پررنگ‌تر مشخص می‌شود.
    final glowColor = c.primary;
    final glowAlpha = (isDark ? 0.32 : 0.16) * glowIntensity;
    final borderAlpha = isCurrent
        ? (isDark ? 0.95 : 0.8)
        : (isDark ? 0.55 : 0.35) * math.max(glowIntensity, 0.4);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: badgeAsset != null ? const EdgeInsets.only(top: 14) : null,
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: glowColor.withValues(alpha: borderAlpha),
              width: isCurrent ? 2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: glowAlpha),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: c.textStrong,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Flexible(child: _currentPill()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...features.map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: c.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: c.textStrong,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 35,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(iconAsset, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              button,
            ],
          ),
        ),
        if (badgeAsset != null)
          Positioned(
            top: -40,
            left: -10,
            child: Transform.rotate(
              angle: -0.12,
              child: Image.asset(badgeAsset!, width: 108),
            ),
          ),
      ],
    );
  }

  Widget _currentPill() {
    final text = statusText ?? 'پلن فعلی';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  final AppColors c;
  final String label;
  final bool filled;
  final Color accent;
  final bool trailingCheck;
  final VoidCallback? onTap;

  const _PlanButton({
    required this.c,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onTap,
    this.trailingCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (trailingCheck) ...[
          Icon(Icons.check_rounded, size: 17, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: filled ? Colors.white : accent,
            ),
          ),
        ] else ...[
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: filled ? Colors.white : accent,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: filled ? Colors.white : accent,
          ),
        ],
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: 40,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: content,
            ),
    );
  }
}
