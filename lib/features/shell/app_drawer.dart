import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/network/connectivity_service.dart';
import '../profile/profile_page.dart';
import '../tasks/delegated_tasks_page.dart';
import '../tasks/manage_tasks_page.dart';
import '../admin/manage_users_page.dart';
import '../admin/manage_sections_sheet.dart';
import '../tasks/widgets/task_group_management_sheet.dart';
import '../admin/attendance_devices_page.dart';
import '../admin/holidays_page.dart';
import '../admin/system_settings_page.dart';
import '../admin/tasks_overview_page.dart';
import '../admin/workflow_monitor_page.dart';
import '../admin/payroll_report_page.dart';
import '../subscription/subscription_page.dart';
import 'widgets/about_sheet.dart';
import '../../main.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_switch.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final avatarPath = (user['avatar_path'] ?? '').toString();

    return Drawer(
      // 🔧 طبق استانداردِ M3، دراور باید یک سطحِ «مرتفع‌تر» از پس‌زمینه‌ی
      // صفحه باشد (نه دقیقاً هم‌رنگ) تا به‌عنوان لایه‌ی جدا حس شود
      backgroundColor: c.surfaceContainerLow,
      child: Column(
        children: [
          // ── کارتِ اطلاعاتِ کاربر — طبقِ طرحِ ارسالی ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.borderSoft),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: c.primary.withValues(alpha: 0.15),
                          // 🔧 عکسِ پروفایل؛ اگر نبود یا بارگذاری نشد، حرفِ اولِ نام
                          foregroundImage: avatarPath.isNotEmpty
                              ? NetworkImage('${ApiClient.baseUrl}/$avatarPath')
                              : null,
                          child: Text(
                            firstName.isNotEmpty ? firstName[0] : 'U',
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isEmpty ? 'کاربر' : fullName,
                                style: TextStyle(
                                  color: c.textStrong,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'آوای شرق ملک',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 🔧 وضعیتِ آنلاین/آفلاینِ واقعی — از همون سرویسِ اتصال
                    // که برای نوارِ «بدون اینترنت» استفاده می‌شود
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService.instance.isOnline,
                      builder: (context, online, _) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (online ? c.success : c.textMuted).withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: online ? c.success : c.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              online ? 'آنلاین' : 'آفلاین',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: online ? c.success : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── لینک‌ها ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 🔧 اصلاح طبق درخواست: فهرستِ اصلیِ منو دقیقاً این ۹ گزینه
                // است، به همین ترتیب. آن‌هایی که هنوز قابلیتِ واقعی در اپ
                // ندارند (مدیریتِ کارها/ورود و خروج/نظارت/مدیریت/گفتگو/
                // پشتیبانی) به‌جای مخفی‌کردن یا جعلی‌بودن، غیرفعال و
                // کم‌رنگ با برچسبِ «به‌زودی» نمایش داده می‌شوند.
                _drawerItem(
                  c: c,
                  icon: Icons.grid_view_rounded,
                  label: 'داشبورد',
                  selected: currentIndex == 0,
                  onTap: () {
                    Get.back();
                    onTabSelected(0);
                  },
                ),
                // 🔧 «خرید و ارتقای اشتراک» — طبقِ طرحِ ارسالی
                _drawerItem(
                  c: c,
                  icon: Icons.workspace_premium_rounded,
                  label: 'خرید و ارتقای اشتراک',
                  color: const Color(0xFFF5B94D),
                  onTap: () {
                    Get.back();
                    Get.to(() => const SubscriptionPage());
                  },
                ),
                _drawerItem(
                  c: c,
                  icon: Icons.fact_check_outlined,
                  label: 'مدیریت کارها',
                  onTap: () {
                    Get.back();
                    Get.to(() => ManageTasksPage(user: user));
                  },
                ),
                // 🔧 ایندکسِ واقعیِ PageView (بعد از تغییرِ ترتیبِ نوارِ
                // پایین): ۰=داشبورد، ۱=تنظیمات، ۲=اعلان‌ها، ۳=کارها
                _drawerItem(
                  c: c,
                  icon: Icons.task_alt_rounded,
                  label: 'کارهای من',
                  selected: currentIndex == 3,
                  onTap: () {
                    Get.back();
                    onTabSelected(3);
                  },
                ),
                _drawerItem(
                  c: c,
                  icon: Icons.send_rounded,
                  label: 'کارهای واگذار شده',
                  onTap: () {
                    Get.back();
                    Get.to(() => const DelegatedTasksPage());
                  },
                ),
                _drawerItem(
                  c: c,
                  icon: Icons.fingerprint_rounded,
                  label: 'ورود و خروج (به‌زودی)',
                  enabled: false,
                  onTap: () {},
                ),
                // 🔧 طبق درخواست: منوی «نظارت» — دقیقاً مثلِ وب یک منویِ
                // بالادستیِ جدا از «مدیریت» است (نه زیرِمجموعه‌اش)، با سه
                // زیرگزینه: نظارت بر کارها، نظارت بر روتین‌های فعال، گزارش
                // حقوق پرسنل
                Builder(
                  builder: (context) {
                    final role = (user['role'] ?? '').toString();
                    final canManage = [
                      'manager',
                      'supervisor',
                      'admin',
                    ].contains(role);
                    return _ExpandableDrawerItem(
                      c: c,
                      icon: Icons.visibility_outlined,
                      label: 'نظارت',
                      children: [
                        _drawerItem(
                          c: c,
                          icon: Icons.list_alt_rounded,
                          label: canManage
                              ? 'نظارت بر کارها'
                              : 'نظارت بر کارها (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(() => const TasksOverviewPage());
                          },
                        ),
                        _drawerItem(
                          c: c,
                          icon: Icons.account_tree_outlined,
                          label: canManage
                              ? 'نظارت بر روتین‌های فعال'
                              : 'نظارت بر روتین‌های فعال (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(() => const WorkflowMonitorPage());
                          },
                        ),
                        _drawerItem(
                          c: c,
                          icon: Icons.payments_outlined,
                          label: canManage
                              ? 'گزارش حقوق پرسنل'
                              : 'گزارش حقوق پرسنل (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(() => const PayrollReportPage());
                          },
                        ),
                      ],
                    );
                  },
                ),
                // 🔧 طبق درخواست: زیرمنویِ «مدیریتِ کاربران» — دقیقاً همان
                // API/فیلدهایِ صفحه‌ی وب (pages/users.php)، فقط برایِ
                // کاربرانی که نقششان اجازه‌ی مدیریت می‌دهد (سرور هم خودش
                // با requirePermission نهایی چک می‌کند؛ این فقط برایِ
                // پنهان‌نگه‌داشتنِ گزینه از کارمندانِ عادی است)
                Builder(
                  builder: (context) {
                    final role = (user['role'] ?? '').toString();
                    final canManage = [
                      'manager',
                      'supervisor',
                      'admin',
                    ].contains(role);
                    return _ExpandableDrawerItem(
                      c: c,
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'مدیریت',
                      children: [
                        _drawerItem(
                          c: c,
                          icon: Icons.people_alt_outlined,
                          label: canManage
                              ? 'مدیریت کاربران'
                              : 'مدیریت کاربران (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(
                              () => ManageUsersPage(currentUserRole: role),
                            );
                          },
                        ),
                        // 🔧 طبق درخواست: «مدیریت واحدهای فعالیت» و «مدیریت
                        // گروه‌ها» هم به همین زیرمنو اضافه شدند — هر دو در
                        // نسخه‌ی وب هم دقیقاً همین‌جا (زیرِ «مدیریت») هستند
                        _drawerItem(
                          c: c,
                          icon: Icons.account_tree_outlined,
                          label: canManage
                              ? 'مدیریت واحدهای فعالیت'
                              : 'مدیریت واحدهای فعالیت (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            showManageActivitySectionsSheet(context);
                          },
                        ),
                        _drawerItem(
                          c: c,
                          icon: Icons.folder_copy_outlined,
                          label: canManage
                              ? 'مدیریت گروه‌ها'
                              : 'مدیریت گروه‌ها (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            showTaskGroupManagementSheet(
                              context,
                              onChanged: () {},
                            );
                          },
                        ),
                        // 🔧 طبق درخواست: «دستگاه‌های حضور و غیاب» هم اضافه
                        // شد — معادلِ pages/attendance-devices.php در وب
                        _drawerItem(
                          c: c,
                          icon: Icons.devices_other_outlined,
                          label: canManage
                              ? 'دستگاه‌های حضور و غیاب'
                              : 'دستگاه‌های حضور و غیاب (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(() => const AttendanceDevicesPage());
                          },
                        ),
                        // 🔧 طبق درخواست: «روزهای تعطیل» — معادلِ
                        // pages/holidays.php در وب
                        _drawerItem(
                          c: c,
                          icon: Icons.event_busy_outlined,
                          label: canManage
                              ? 'روزهای تعطیل'
                              : 'روزهای تعطیل (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(() => const HolidaysPage());
                          },
                        ),
                        // 🔧 طبق درخواست: «تنظیمات سیستم» — معادلِ
                        // attendance_system/pages/settings.php در وب؛ حالا
                        // که API جدایِ آن به وب اضافه شد، از همان استفاده می‌شود
                        _drawerItem(
                          c: c,
                          icon: Icons.tune_rounded,
                          label: canManage
                              ? 'تنظیمات سیستم'
                              : 'تنظیمات سیستم (بدون دسترسی)',
                          enabled: canManage,
                          onTap: () {
                            Get.back();
                            Get.to(() => const SystemSettingsPage());
                          },
                        ),
                      ],
                    );
                  },
                ),
                _drawerItem(
                  c: c,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'گفتگو (به‌زودی)',
                  enabled: false,
                  onTap: () {},
                ),
                // 🔧 طبق درخواست: زیرمنوی «پشتیبانی» یک گزینه‌ی «تیکت»
                // دارد — خودِ بازکردن/بستنِ زیرمنو واقعی است، فقط چون
                // سامانه‌ی تیکت هنوز ساخته نشده، خودِ گزینه‌ی «تیکت»
                // غیرفعال/به‌زودی می‌ماند
                _ExpandableDrawerItem(
                  c: c,
                  icon: Icons.support_agent_rounded,
                  label: 'پشتیبانی',
                  children: [
                    _drawerItem(
                      c: c,
                      icon: Icons.confirmation_number_outlined,
                      label: 'تیکت (به‌زودی)',
                      enabled: false,
                      onTap: () {},
                    ),
                  ],
                ),

                Divider(
                  height: 24,
                  indent: 20,
                  endIndent: 20,
                  color: c.borderSoft,
                ),

                _drawerItem(
                  c: c,
                  icon: Icons.person_outline_rounded,
                  label: 'پروفایل من',
                  onTap: () {
                    Get.back();
                    Get.to(() => ProfilePage(user: user));
                  },
                ),
                _drawerItem(
                  c: c,
                  icon: Icons.settings_outlined,
                  label: 'تنظیمات',
                  selected: currentIndex == 1,
                  onTap: () {
                    Get.back();
                    onTabSelected(1);
                  },
                ),
                const _ThemeToggleTile(),
                _drawerItem(
                  c: c,
                  icon: Icons.info_outline_rounded,
                  label: 'درباره ما',
                  onTap: () {
                    Get.back();
                    showAboutSheet(context);
                  },
                ),
              ],
            ),
          ),

          // ── دکمه خروج ──
          Divider(height: 1, color: c.borderSoft),
          SafeArea(
            top: false,
            child: _drawerItem(
              c: c,
              icon: Icons.logout_rounded,
              label: 'خروج از حساب',
              color: c.danger,
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required AppColors c,
    required IconData icon,
    required String label,
    bool selected = false,
    bool enabled = true,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor = color ?? (selected ? c.primary : c.textStrong);
    // 🔧 طبقِ طرح: آیتمِ فعال یک قرصِ خطی (outline) دارد، نه پرشده —
    // بقیه‌ی آیتم‌ها ردیفِ ساده و بدون قاب هستند
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: c.primary, width: 1.3)
                  : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 21, color: itemColor),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: itemColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // 🔧 گزینه‌های بدون قابلیتِ واقعی، به‌جای پنهان یا جعلی‌بودن، فقط
    // کم‌رنگ و غیرقابلِ‌لمس نمایش داده می‌شوند
    if (!enabled)
      return Opacity(opacity: 0.5, child: IgnorePointer(child: row));
    return row;
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
}

/// ردیفِ سوییچِ تمِ روشن/تاریک داخل دراور
class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 🔧 اصلاح: به ValueNotifier اختصاصی گوش می‌دهد (نه Get.isDarkMode
    // مستقیم) — همین باعث می‌شد سوییچ با تأخیر/اصلاً به‌روز نشود؛ حالا
    // بلافاصله با تغییر واقعی سینک است.
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.isDarkNotifier,
      builder: (context, isDark, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 22,
                color: c.textStrong,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'حالت تاریک',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textStrong,
                  ),
                ),
              ),
              AppSwitch(
                value: isDark,
                activeColor: c.primary,
                onChanged: (v) async {
                  await ThemeController.setDark(v);
                  // 🔧 بعد از تغییر تم، دراور خودکار بسته شود
                  Get.back();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// آیتمِ دراورِ قابلِ‌بازشدن — با ضربه، زیرمنوی خودش (children) را
/// باز/بسته می‌کند؛ برایِ مواردی مثل «پشتیبانی» که خودش یک صفحه‌ی
/// مستقل نیست، فقط دربردارنده‌ی زیرگزینه‌هاست.
class _ExpandableDrawerItem extends StatefulWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final List<Widget> children;

  const _ExpandableDrawerItem({
    required this.c,
    required this.icon,
    required this.label,
    required this.children,
  });

  @override
  State<_ExpandableDrawerItem> createState() => _ExpandableDrawerItemState();
}

class _ExpandableDrawerItemState extends State<_ExpandableDrawerItem> {
  bool _expanded = false;
  final _key = GlobalKey();

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      // 🔧 طبق درخواست: با بازشدنِ منو، خودکار به‌اندازه‌ای اسکرول شود
      // که زیرمنوها هم دیده شوند. باید تا بعد از رندرِ فریمِ بعدی صبر
      // کنیم چون ارتفاعِ جدید (با زیرمنوهایِ باز‌شده) هنوز لِی‌اوت نشده
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _key.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      key: _key,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 21, color: c.textStrong),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: c.textStrong,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: c.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          // 🔧 موقتاً: زیرمنوها داخلِ یک کادرِ متمایز با خطِ رنگیِ کنارشون
          // قرار گرفتند تا از منوهایِ اصلی جدا دیده شوند
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 2, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  right: BorderSide(
                    color: c.primary.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                ),
              ),
              child: Column(children: widget.children),
            ),
          ),
      ],
    );
  }
}
