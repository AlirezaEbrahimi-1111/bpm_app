import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../profile/profile_page.dart';
import '../../main.dart';

/// منوی کشویی کناری (Drawer)
/// - هدر گرادیان با اطلاعات کاربر (نام، نقش، واحد، موبایل)
/// - لینک به تب‌ها (از طریق callback به Shell)
/// - پروفایل، تنظیمات، درباره ما
/// - دکمه خروج
class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> user;
  final int currentIndex;
  final void Function(int index) onTabSelected;

  const AppDrawer({
    super.key,
    required this.user,
    required this.currentIndex,
    required this.onTabSelected,
  });

  static const _primary = Color(0xFF6D28D9);
  static const _primaryLight = Color(0xFF8B5CF6);
  static const _ink = Color(0xFF1A1A2E);

  // ترجمه نقش به فارسی (هماهنگ با صفحه پروفایل)
  String _roleLabel() {
    final role = (user['role'] ?? '').toString();
    final section = (user['activity_section'] ?? '').toString();
    if (section == 'management' && role == 'supervisor') {
      return 'مدیر سازمان';
    }
    return switch (role) {
      'supervisor' => 'سرپرست',
      'management' => 'مدیر',
      'manager' => 'مدیر',
      'employee' => 'کارمند',
      'admin' => 'ادمین',
      _ => 'کاربر',
    };
  }

  // ترجمه واحد سازمانی به فارسی (هماهنگ با صفحه پروفایل)
  String _sectionLabel() {
    final section = (user['activity_section'] ?? '').toString();
    if (section.isEmpty) return '';
    return switch (section) {
      'management' => 'مدیریت',
      'sales' => 'فروش',
      'purchase' => 'خرید',
      'warehouse' => 'انبار',
      _ => section,
    };
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final phone = (user['phone'] ?? '').toString();
    final section = _sectionLabel();

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── هدر گرادیان ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryLight, _primary],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    firstName.isNotEmpty ? firstName[0] : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  fullName.isEmpty ? 'کاربر' : fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // نقش + واحد
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _roleLabel(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                    if (section.isNotEmpty) ...[
                      Text(
                        '  •  ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.apartment_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                // شماره موبایل
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        toPersianDigits(phone),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── لینک‌ها ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(
                  icon: Icons.grid_view_rounded,
                  label: 'داشبورد',
                  selected: currentIndex == 0,
                  onTap: () {
                    Get.back();
                    onTabSelected(0);
                  },
                ),
                _drawerItem(
                  icon: Icons.task_alt_rounded,
                  label: 'کارهای من',
                  selected: currentIndex == 1,
                  onTap: () {
                    Get.back();
                    onTabSelected(1);
                  },
                ),
                _drawerItem(
                  icon: Icons.send_rounded,
                  label: 'کارهای واگذارشده',
                  selected: currentIndex == 2,
                  onTap: () {
                    Get.back();
                    onTabSelected(2);
                  },
                ),
                _drawerItem(
                  icon: Icons.notifications_rounded,
                  label: 'اعلان‌ها',
                  selected: currentIndex == 3,
                  onTap: () {
                    Get.back();
                    onTabSelected(3);
                  },
                ),

                const Divider(height: 24, indent: 20, endIndent: 20),

                _drawerItem(
                  icon: Icons.person_outline_rounded,
                  label: 'پروفایل من',
                  onTap: () {
                    Get.back();
                    Get.to(() => ProfilePage(user: user));
                  },
                ),
                _drawerItem(
                  icon: Icons.settings_outlined,
                  label: 'تنظیمات',
                  onTap: () {
                    Get.back();
                    Get.snackbar(
                      'به‌زودی',
                      'بخش تنظیمات در حال ساخت است',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.grey.shade200,
                    );
                  },
                ),
                _drawerItem(
                  icon: Icons.info_outline_rounded,
                  label: 'درباره ما',
                  onTap: () {
                    Get.back();
                    _showAboutSheet();
                  },
                ),
              ],
            ),
          ),

          // ── دکمه خروج ──
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: _drawerItem(
              icon: Icons.logout_rounded,
              label: 'خروج از حساب',
              color: const Color(0xFFEF4444),
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    bool selected = false,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor = color ?? (selected ? _primary : _ink);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: selected ? _primary.withValues(alpha: 0.08) : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 22, color: itemColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('خروج از حساب', style: TextStyle(fontSize: 16)),
        content: const Text('آیا مطمئن هستید که می‌خواهید خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'انصراف',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await ApiClient.clearToken();
              Get.offAll(() => const LoginPage());
            },
            child: const Text(
              'خروج',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, Color(0xFF22D3EE)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'یکتا همراهان ملک',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'سامانه مدیریت یکپارچه فرآیندها',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              toPersianDigits('نسخه ۴.۰'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
