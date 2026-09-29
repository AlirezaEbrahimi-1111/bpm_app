import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../profile/profile_page.dart';
import '../../../core/theme/app_colors.dart';

/// نوار بالای صفحه: دکمه‌ی همبرگری (باز کردن Drawer) + آیکون پروفایل.
///
/// این ویجت یک‌بار در پوسته‌ی اصلی اپ (MainShell) رندر می‌شود — بیرون
/// از PageView تب‌ها — تا با جابه‌جایی/کشیدن بین تب‌ها ثابت بماند و
/// جابه‌جا نشود، دقیقاً مثل هدر یک سایت. رنگ‌هایش با تم روشن/تاریک
/// دستگاه هماهنگ می‌شوند.
class AppTopBar extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onMenuTap;
  const AppTopBar({super.key, required this.user, this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: Icon(Icons.menu_rounded, size: 26, color: c.textStrong),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
