import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_number.dart';
import '../../../core/plan/plan_access.dart';
import '../../../core/network/api_client.dart';
import '../../subscription/plan_gate.dart';
import '../../tasks/create_task_page.dart';
import 'global_search_sheet.dart';
import '../main_shell.dart';

/// نوارِ ناوبریِ پایین — همان طراحیِ پوسته‌ی اصلی (MainShell)، ولی
/// به‌صورتِ یک ویجتِ مستقل تا هر صفحه‌ی دیگری (که با Get.to باز می‌شود و
/// Scaffoldِ خودش را دارد، پس نوارِ پوسته را به‌طورِ خودکار نمی‌بیند) هم
/// بتواند همین نوار را نشان دهد.
///
/// 🔧 طبق درخواست: «نوار ناوبری باید در تمامِ صفحاتِ اپ نمایش داده شود».
/// چون این صفحات خودشان تبی از MainShell نیستند، [selectedIndex] را
/// null می‌گذارند (هیچ‌کدام از ۴ گزینه فعال/پررنگ نیست) و با ضربه روی
/// هرکدام، به همان تبِ MainShell برمی‌گردند (با [navigateToShellTab]).
class AppBottomNav extends StatelessWidget {
  /// ایندکسِ تبِ فعلی، اگر این صفحه خودش یکی از ۴ تبِ پوسته باشد؛ برای
  /// صفحاتِ دیگر، null بگذارید تا هیچ گزینه‌ای پررنگ نشود.
  final int? selectedIndex;

  /// تعدادِ اعلانِ نخوانده — فقط در خودِ MainShell به‌روز نگه داشته
  /// می‌شود؛ در بقیه‌ی صفحات پیش‌فرض صفر است (بجِ قرمز نشان داده نمی‌شود)
  final int unreadCount;

  const AppBottomNav({super.key, this.selectedIndex, this.unreadCount = 0});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        widthFactor: 0.9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: ColoredBox(
              color: c.navBarBg.withValues(alpha: 0.75),
              child: SizedBox(
                height: 70,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _navItem(
                        c: c,
                        icon: Icons.grid_view_rounded,
                        label: 'داشبورد',
                        selected: selectedIndex == 0,
                        onTap: () => navigateToShellTab(0),
                      ),
                      _navItem(
                        c: c,
                        icon: Icons.settings_outlined,
                        label: 'تنظیمات',
                        selected: selectedIndex == 1,
                        onTap: () => navigateToShellTab(1),
                      ),
                      const SizedBox(width: 64),
                      _navItem(
                        c: c,
                        icon: Icons.notifications_rounded,
                        label: 'اعلان‌ها',
                        selected: selectedIndex == 2,
                        locked: !PlanAccess.allows(PlanFeature.notifications),
                        feature: PlanFeature.notifications,
                        showBadge: unreadCount > 0,
                        onTap: () => navigateToShellTab(2),
                      ),
                      _navItem(
                        c: c,
                        icon: Icons.task_alt_rounded,
                        label: 'کارها',
                        selected: selectedIndex == 3,
                        onTap: () => navigateToShellTab(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required AppColors c,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool showBadge = false,
    bool locked = false,
    PlanFeature? feature,
  }) {
    return GestureDetector(
      onTap: locked
          ? () => showPlanUpgradeSheet(label: label, feature: feature)
          : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: SizedBox(
          width: 44,
          child: OverflowBox(
            maxHeight: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: selected ? c.primary : c.textMuted,
                    ),
                    // 🔧 طبق درخواست: آیکونِ قفل برایِ گزینه‌هایِ قفل‌شده
                    // به‌خاطرِ پلن — روی بجِ تعدادِ نخوانده اولویت دارد
                    if (locked)
                      Positioned(
                        right: -4,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: c.navBarBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.navBarBg, width: 1.5),
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 11,
                            color: c.textMuted,
                          ),
                        ),
                      )
                    else if (showBadge)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.navBarBg, width: 1.5),
                          ),
                          child: Text(
                            unreadCount > 99
                                ? '${toPersianDigits('99')}+'
                                : toPersianDigits(unreadCount.toString()),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected ? c.primary : c.textMuted,
                    fontFamily: 'Vazir',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// از هر صفحه‌ای (حتی صفحاتی که با Get.to بازشده‌اند) به تبِ شماره‌یِ
/// [index] از پوسته‌ی اصلی برمی‌گردد — بدونِ از نو ساختنِ MainShell
/// (همان نمونه‌یِ زنده‌اش که پایینِ پشته‌ی ناوبری مانده، فقط popهای رویِ
/// آن برداشته می‌شوند تا دوباره دیده شود).
void navigateToShellTab(int index) {
  MainShell.requestedTab.value = index;
  Get.until((route) => route.isFirst);
}

/// همان مکانِ استانداردِ centerDocked، فقط کمی پایین‌تر — نسخه‌ی عمومیِ
/// همان کلاسِ خصوصیِ MainShell، تا صفحاتِ دیگر هم بتوانند دقیقاً همین
/// چیدمان را برایِ دکمه‌ی شناورشان استفاده کنند.
class LoweredDockedFabLocation extends FloatingActionButtonLocation {
  const LoweredDockedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final standard = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    return Offset(standard.dx, standard.dy + 12);
  }
}

/// دکمه‌ی شناورِ «+» (افزودنِ کار) — نسخه‌ی عمومی برایِ صفحاتی که خودشان
/// مستقیماً اطلاعاتِ کاربر را ندارند؛ از ApiClient.currentUser (که همیشه
/// بعد از لاگین پر است) می‌خواند.
class AppCreateTaskFab extends StatelessWidget {
  const AppCreateTaskFab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: 64,
      height: 64,
      child: FittedBox(
        child: FloatingActionButton(
          onPressed: () {
            final user = ApiClient.currentUser;
            Get.to(
              () => CreateTaskPage(
                userRole: user?['role'] ?? '',
                currentUserId: user?['id'],
              ),
            );
          },
          backgroundColor: c.primary,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// دکمه‌ی شناورِ «فلش رو به بالا»یِ جستجویِ سراسری — همان طراحیِ پوسته‌ی
/// اصلی (با انیمیشنِ bob)، به‌صورتِ ویجتِ مستقل.
class AppGlobalSearchButton extends StatefulWidget {
  const AppGlobalSearchButton({super.key});

  @override
  State<AppGlobalSearchButton> createState() => _AppGlobalSearchButtonState();
}

class _AppGlobalSearchButtonState extends State<AppGlobalSearchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _bob = Tween<double>(
    begin: 0,
    end: -6,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => showGlobalSearchSheet(context),
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _bob.value), child: child),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            color: c.primary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// پوششِ یک صفحه با دکمه‌ی شناورِ جستجویِ سراسری — چون این دکمه باید
/// روی همه‌چیز (حتی نوارِ ناوبری/دکمه‌ی +) شناور بماند، دورِ کلِ
/// Scaffoldِ صفحه یک Stack می‌کشد، دقیقاً مثلِ خودِ MainShell.
///
/// 🔧 طبق درخواست: «دکمه‌ی افزودنِ تسک و سرچِ سراسری... باید در تمامیِ
/// صفحاتِ دارایِ navigationbar نمایش داده بشه» — هر صفحه‌ای که
/// AppBottomNav دارد، با همین ویجت هم پوشانده می‌شود.
class AppShellOverlays extends StatelessWidget {
  final Widget child;

  const AppShellOverlays({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        child,
        Positioned(
          bottom: 62 + MediaQuery.of(context).padding.bottom + 36,
          child: const AppGlobalSearchButton(),
        ),
      ],
    );
  }
}
