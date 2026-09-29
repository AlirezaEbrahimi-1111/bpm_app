import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../main.dart';
import 'change_password_page.dart';
import 'personal_info_page.dart';

/// صفحه‌ی پروفایل — طبق طرح ارسالی (روشن + تاریک)
/// نکته: بخش «اشتراک و پرداخت» چون بک‌اندِ اشتراک/پرداختی برای این اپِ
/// سازمانی وجود ندارد، به‌صورت غیرفعال/«به‌زودی» نمایش داده می‌شود.
class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const ProfilePage({super.key, required this.user});

  String _roleLabel(String? role, String? section) {
    if (section == 'management' && role == 'supervisor') return 'مدیر سازمان';
    return switch (role) {
      'supervisor' => 'سرپرست',
      'management' => 'مدیر',
      'manager' => 'مدیر',
      'employee' => 'کارمند',
      'admin' => 'ادمین',
      _ => 'کاربر',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();

    return Scaffold(
      backgroundColor: c.bgPage,
      appBar: AppBar(
        backgroundColor: c.bgPage,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textStrong),
        title: Text(
          'پروفایل',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Transform.rotate(
            angle: math.pi, // 🔧 طبق درخواست: ۱۸۰ درجه چرخید
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        // 🔧 اصلاح: قبلاً فاصله‌ی پایین ثابت (۳۲) بود و inset سیستمِ گوشی
        // (دکمه‌های ناوبری) را رعایت نمی‌کرد — دکمه‌ی «خروج از حساب» که
        // آخرین/پایین‌ترین عنصر است، پشتِ آن‌ها می‌رفت
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── کارت اطلاعات کاربر ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.borderSoft),
              ),
              // 🔧 طبق درخواست: عکس سمتِ راست، نام/سِمت سمتِ چپ
              child: Row(
                children: [
                  _avatarCircle(c, firstName, user['avatar_path']?.toString()),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? 'کاربر' : fullName,
                          style: TextStyle(
                            color: c.textStrong,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _roleLabel(user['role'], user['activity_section']),
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'آوای شرق ملک',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _sectionTitle(c, 'اطلاعات حساب'),
            _card(
              c: c,
              children: [
                _settingsRow(
                  c: c,
                  icon: Icons.person_outline_rounded,
                  label: 'اطلاعات شخصی',
                  subtitle: 'نام، شماره تماس، سازمان',
                  onTap: () => Get.to(() => PersonalInfoPage(user: user)),
                ),
                _settingsRow(
                  c: c,
                  icon: Icons.lock_outline_rounded,
                  label: 'تغییر رمز عبور',
                  onTap: () => Get.to(() => const ChangePasswordPage()),
                  isLast: true,
                ),
              ],
            ),

            _sectionTitle(c, 'اشتراک و پرداخت'),
            // 🔧 این اپ سازمانی است و بک‌اند اشتراک/پرداختی ندارد — این
            // بخش فعلاً به‌صورت غیرفعال («به‌زودی») نمایش داده می‌شود.
            Opacity(
              opacity: 0.55,
              child: IgnorePointer(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.primaryLight, c.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.diamond_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'اشتراک حرفه‌ای',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'این قابلیت به‌زودی فعال می‌شود',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'خرید یا تمدید اشتراک',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: 0.55,
              child: IgnorePointer(
                child: _card(
                  c: c,
                  children: [
                    _settingsRow(
                      c: c,
                      icon: Icons.credit_card_rounded,
                      label: 'مدیریت اشتراک',
                      onTap: () {},
                    ),
                    _settingsRow(
                      c: c,
                      icon: Icons.history_rounded,
                      label: 'تاریخچه پرداخت‌ها',
                      onTap: () {},
                    ),
                    _settingsRow(
                      c: c,
                      icon: Icons.confirmation_number_outlined,
                      label: 'کد تخفیف',
                      onTap: () {},
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),

            _sectionTitle(c, 'پشتیبانی'),
            _card(
              c: c,
              children: [
                _settingsRow(
                  c: c,
                  icon: Icons.help_outline_rounded,
                  label: 'راهنما و سوالات متداول',
                  onTap: () => _comingSoon(),
                ),
                _settingsRow(
                  c: c,
                  icon: Icons.support_agent_rounded,
                  label: 'تماس با پشتیبانی',
                  onTap: () => _showChangePasswordInfo(
                    context,
                    c,
                    title: 'تماس با پشتیبانی',
                    message:
                        'برای تماس با پشتیبانی، با مدیر سازمان خود در ارتباط باشید.',
                  ),
                  isLast: true,
                ),
              ],
            ),

            const SizedBox(height: 8),
            // ── دکمه خروج ──
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.borderSoft),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _confirmLogout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: c.danger),
                      const SizedBox(width: 12),
                      Text(
                        'خروج از حساب',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCircle(AppColors c, String firstName, String? avatarPath) {
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasAvatar
            ? null
            : LinearGradient(colors: [c.primaryLight, c.primary]),
        color: c.borderSoft,
        image: hasAvatar
            ? DecorationImage(
                image: NetworkImage('${ApiClient.baseUrl}/$avatarPath'),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasAvatar
          ? null
          : Center(
              child: Text(
                firstName.isNotEmpty ? firstName[0] : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: c.textStrong,
        ),
      ),
    ),
  );

  Widget _card({required AppColors c, required List<Widget> children}) =>
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderSoft),
        ),
        child: Column(children: children),
      );

  Widget _settingsRow({
    required AppColors c,
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: c.borderSoft)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textStrong,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            // 🔧 طبق درخواست: جهتِ فلش برعکس شد
            Icon(Icons.chevron_right_rounded, size: 20, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordInfo(
    BuildContext context,
    AppColors c, {
    String title = 'تغییر رمز عبور',
    String message =
        'برای تغییر رمز عبور با پشتیبانی یا مدیر سازمان خود تماس بگیرید.',
  }) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: c.surface,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: c.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textStrong,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13.5,
                  color: c.textMuted,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('متوجه شدم'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _comingSoon() {
    AppSnack.info('به‌زودی', 'این بخش در حال ساخت است');
  }

  void _confirmLogout() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('خروج از حساب', style: TextStyle(fontSize: 16)),
        content: const Text('آیا می‌خواهید از حساب خود خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'انصراف',
              style: TextStyle(
                color: ThemeController.isDark
                    ? Colors.white
                    : Colors.grey.shade600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _logout();
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

  Future<void> _logout() async {
    await ApiClient.clearToken();
    Get.offAll(() => const LoginPage());
  }
}
