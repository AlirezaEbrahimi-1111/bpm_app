import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import 'plan_detail_page.dart';

/// «خرید و ارتقای اشتراک» — طبقِ طرحِ ارسالی (روشن + تاریک).
///
/// 🔧 فعلاً هیچ API واقعی برایِ پلن‌ها/پرداخت در بک‌اند وجود ندارد (چک شد:
/// نه در وب و نه در موبایل چیزی به نامِ «پلن طلایی/نقره‌ای» نیست) — پس این
/// صفحه فقط UI است، دقیقاً طبقِ طرح؛ دکمه‌های «انتخاب پلن» فعلاً یک
/// پیامِ «به‌زودی» نشان می‌دهند تا بعداً که API پرداخت/ارتقا مشخص شد،
/// به همین دکمه‌ها وصل شود.
class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  static const _goldColor = Color(0xFFF5B94D);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
            button: _PlanButton(
              c: c,
              label: 'انتخاب پلن طلایی',
              filled: true,
              accent: c.primary,
              onTap: () => Get.to(
                () => const PlanDetailPage(plan: SubscriptionPlanType.gold),
              ),
            ),
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
            button: _PlanButton(
              c: c,
              label: 'انتخاب پلن نقره‌ای',
              filled: true,
              accent: c.primary,
              onTap: () => Get.to(
                () => const PlanDetailPage(plan: SubscriptionPlanType.silver),
              ),
            ),
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
            button: _PlanButton(
              c: c,
              label: 'پلن فعلی شما',
              filled: false,
              accent: c.textMuted,
              trailingCheck: true,
              onTap: null,
            ),
          ),
        ],
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
    this.badgeAsset,
  });

  @override
  Widget build(BuildContext context) {
    // 🔧 طبق درخواست: نورِ دورِ کارت همیشه بنفش است (نه رنگِ اختصاصیِ پلن)؛
    // «accent» فقط برایِ رنگِ زیرنویس استفاده می‌شود. در تمِ تاریک پررنگ‌تر
    // (طبقِ طرح)، در تمِ روشن کم‌رنگ‌تر تا به‌جایِ افکتِ نئون، فقط یک
    // تأکیدِ ظریف باشد
    final glowColor = c.primary;
    final glowAlpha = (isDark ? 0.32 : 0.16) * glowIntensity;
    final borderAlpha = (isDark ? 0.55 : 0.35) * math.max(glowIntensity, 0.4);

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
              width: 1.4,
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
              // 🔧 طبق درخواست: کلاً دو ستون — راست: نام+ویژگی‌ها، چپ:
              // فقط عکسِ پلن (با AspectRatio، هم‌عرضِ ستونش، یعنی تقریباً
              // نیمِ کارت)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: c.textStrong,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
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
          // 🔧 طبق عکس: روی لبه‌ی بالا-چپِ کارت سوار می‌شود (نه بالاترِ
          // آن با فاصله)، و کمی کج. چون تصویرِ منبع مربعی و بیشترِ فضایش
          // شفاف است، اندازه‌دهی با width (نه height) لازم است تا خودِ
          // برچسب ریز دیده نشود
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
          // 🔧 طبق درخواست: فلش بعد از متن بیاید و جهتش عوض شود
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
