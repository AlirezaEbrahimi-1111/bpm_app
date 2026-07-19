import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../main.dart';

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const ProfilePage({super.key, required this.user});

  static const _primary = Color(0xFF6C63FF);
  static const _ink = Color(0xFF1A1A2E);

  String _roleLabel(String? role) => switch (role) {
    'supervisor' => 'سرپرست',
    'management' => 'مدیر',
    'manager' => 'مدیر',
    'employee' => 'کارمند',
    'admin' => 'ادمین',
    _ => 'کاربر',
  };

  String _sectionLabel(String? s) => switch (s) {
    'management' => 'مدیریت',
    'sales' => 'فروش',
    'purchase' => 'خرید',
    'warehouse' => 'انبار',
    _ => s ?? '—',
  };

  @override
  Widget build(BuildContext context) {
    final firstName = user['first_name'] ?? '';
    final lastName = user['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'پروفایل',
          style: TextStyle(
            color: _ink,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_forward_ios_rounded,
            color: _ink,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── کارت اطلاعات کاربر ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B7FFF), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // آواتار
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      firstName.isNotEmpty ? firstName[0] : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fullName.isEmpty ? 'کاربر' : fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel(user['role']),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── اطلاعات تماس ──
            _card(
              child: Column(
                children: [
                  _infoRow(
                    Icons.phone_outlined,
                    'شماره موبایل',
                    user['phone']?.toString() ?? '—',
                  ),
                  if ((user['username'] ?? '').toString().isNotEmpty) ...[
                    const Divider(height: 20),
                    _infoRow(
                      Icons.person_outline,
                      'نام کاربری',
                      user['username'],
                    ),
                  ],
                  if ((user['email'] ?? '').toString().isNotEmpty) ...[
                    const Divider(height: 20),
                    _infoRow(Icons.email_outlined, 'ایمیل', user['email']),
                  ],
                  const Divider(height: 20),
                  _infoRow(
                    Icons.business_outlined,
                    'واحد',
                    _sectionLabel(user['activity_section']),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── دکمه خروج ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'خروج از حساب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFEF4444,
                  ).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
      ],
    ),
    child: child,
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          textAlign: TextAlign.left,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

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
              style: TextStyle(color: Colors.grey.shade600),
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
    // پاک کردن توکن (خروج اصلی سمت کلاینت)
    await ApiClient.clearToken();
    // برگشت به صفحه login و پاک کردن همه صفحات قبلی
    Get.offAll(() => const LoginPage());
  }
}
