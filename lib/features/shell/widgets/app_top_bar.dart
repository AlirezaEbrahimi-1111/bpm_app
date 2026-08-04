import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../profile/profile_page.dart';

/// نوار بالای صفحه: دکمه‌ی همبرگری (باز کردن Drawer) + آیکون پروفایل.
///
/// این ویجت یک‌بار در پوسته‌ی اصلی اپ (MainShell) رندر می‌شود — بیرون
/// از PageView تب‌ها — تا با جابه‌جایی/کشیدن بین تب‌ها ثابت بماند و
/// جابه‌جا نشود، دقیقاً مثل هدر یک سایت.
class AppTopBar extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onMenuTap;
  const AppTopBar({super.key, required this.user, this.onMenuTap});

  static const _primary = Color(0xFF6D28D9);
  static const _ink = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu_rounded, size: 26, color: _ink),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          GestureDetector(
            onTap: () => Get.to(() => ProfilePage(user: user)),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: _primary.withValues(alpha: 0.15),
              child: const Icon(
                Icons.person_rounded,
                color: _primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
