import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../profile/profile_page.dart';
import '../../subscription/plan_gate.dart';
import '../../../core/plan/plan_access.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_number.dart';

/// نوار بالای صفحه: دکمه‌ی همبرگری (باز کردن Drawer) + زنگوله‌ی اعلان‌ها + آیکون پروفایل.
///
/// این ویجت یک‌بار در پوسته‌ی اصلی اپ (MainShell) رندر می‌شود — بیرون
/// از PageView تب‌ها — تا با جابه‌جایی/کشیدن بین تب‌ها ثابت بماند و
/// جابه‌جا نشود، دقیقاً مثل هدر یک سایت. رنگ‌هایش با تم روشن/تاریک
/// دستگاه هماهنگ می‌شوند.
///
/// 🔧 زنگوله: «اعلان‌ها» از نوار پایین به این‌جا آمد تا «چت» جایش در نوار پایین باشد.
class AppTopBar extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationsTap;
  final int notificationsUnread;
  final bool notificationsSelected;

  const AppTopBar({
    super.key,
    required this.user,
    this.onMenuTap,
    this.onNotificationsTap,
    this.notificationsUnread = 0,
    this.notificationsSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final locked = !PlanAccess.allows(PlanFeature.notifications);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: Icon(Icons.menu_rounded, size: 26, color: c.textStrong),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Spacer(),
          if (onNotificationsTap != null)
            GestureDetector(
              onTap: locked
                  ? () => showPlanUpgradeSheet(label: 'اعلان‌ها', feature: PlanFeature.notifications)
                  : onNotificationsTap,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: locked ? 0.5 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        notificationsSelected ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                        size: 26,
                        color: notificationsSelected ? c.primary : c.textStrong,
                      ),
                      if (locked)
                        Positioned(
                          right: -3,
                          top: -2,
                          child: Icon(Icons.lock_rounded, size: 11, color: c.textMuted),
                        )
                      else if (notificationsUnread > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.bgPage, width: 1.5),
                            ),
                            child: Text(
                              notificationsUnread > 99
                                  ? '${toPersianDigits('99')}+'
                                  : toPersianDigits(notificationsUnread.toString()),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => Get.to(() => ProfilePage(user: user)),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.person_rounded, color: c.iconAccent, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
