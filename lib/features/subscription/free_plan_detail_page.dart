import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snack.dart';
import '../shell/widgets/app_bottom_nav.dart';
import 'plan_feature_list.dart';
import '../../core/navigation/app_nav.dart';

/// صفحه‌ی «پلن رایگان» — بدون انتخابِ مدت/تعدادِ کاربر و بدون نوارِ قیمت،
/// چون فقط نمایشِ امکاناتِ این پلن و گزینه‌ی ارتقا لازم است.
class FreePlanDetailPage extends StatelessWidget {
  const FreePlanDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppShellOverlays(
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: c.textStrong),
          title: Text(
            'پلن رایگان (شخصی)',
            style: TextStyle(
              color: c.textStrong,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          leading: IconButton(
            icon: Transform.rotate(
              angle: math.pi,
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
            ),
            onPressed: () => AppNav.back(),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.share_rounded, color: c.textStrong, size: 20),
              onPressed: () => AppSnack.info(
                'به‌زودی',
                'اشتراک‌گذاری پلن هنوز فعال نشده است',
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _header(c, isDark),
                  const SizedBox(height: 16),
                  _featuresCard(c),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.borderSoft)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => AppNav.back(),
                      icon: const Icon(Icons.trending_up_rounded, size: 18),
                      label: const Text(
                        'ارتقا به پلن‌های پیشرفته',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: c.textMuted,
                      ),
                      label: Text(
                        'پلن فعلی شما فعال است',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: c.textMuted,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.borderSoft),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _header(AppColors c, bool isDark) {
    final glowAlpha = isDark ? 0.32 : 0.14;
    final borderAlpha = isDark ? 0.55 : 0.32;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: c.primary.withValues(alpha: borderAlpha),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: glowAlpha),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پلن رایگان',
                  style: TextStyle(
                    color: c.textStrong,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'پایه و مدیریت شخصی',
                  style: TextStyle(
                    color: c.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'مدیریت ساده برنامه‌ها و کارهای فردی',
                  style: TextStyle(color: c.textStrong, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 38,
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(
                'assets/images/subscription/plan_free.webp',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuresCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: c.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'امکانات و قابلیت‌ها',
                style: TextStyle(
                  color: c.textStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final f in freePlanFeatures)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(f.$1, size: 17, color: c.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.$2,
                      style: TextStyle(fontSize: 12.5, color: c.textStrong),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, size: 17, color: c.success),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
