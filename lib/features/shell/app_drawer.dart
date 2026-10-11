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
import '../subscription/plan_gate.dart';
import '../../core/plan/plan_access.dart';
import '../../core/plan/org_permissions.dart';
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
class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // 🔧 طبق درخواست: هم‌زمان فقط یکی از منوهایِ بازشونده (نظارت/مدیریت/
  // پشتیبانی) باز بماند — با بازشدنِ یکی، بقیه‌ای که باز بودند بسته شوند
  String? _expandedKey;

  void _toggleExpanded(String key) {
    setState(() => _expandedKey = _expandedKey == key ? null : key);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = widget.user;
    final currentIndex = widget.currentIndex;
    final onTabSelected = widget.onTabSelected;
    final firstName = (user['first_name'] ?? '').toString();
    final lastName = (user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final avatarPath = (user['avatar_path'] ?? '').toString();
    // 🔧 طبق درخواست: اینجا باید نامِ سازمانِ کاربر باشد، نه نامِ اپ
    final organizationName = (user['organization_name'] ?? '').toString();

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
                              if (organizationName.isNotEmpty)
                                Text(
                                  organizationName,
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
                  feature: PlanFeature.delegatedTasks,
                  onTap: () {
                    Get.back();
                    Get.to(() => const DelegatedTasksPage());
                  },
                ),
                _drawerItem(
                  c: c,
                  icon: Icons.fingerprint_rounded,
                  label: 'ورود و خروج (به‌زودی)',
                  planLabel: 'ورود و خروج',
                  feature: PlanFeature.entryExit,
                  enabled: false,
                  onTap: () {},
                ),
                // 🔧 طبق درخواست: گزینه‌هایِ این دو منو دو محورِ کاملاً جدا
                // دارند — (الف) دسترسیِ نقشِ سازمانی (`org_permissions.dart`؛
                // اگر نقش اجازه ندهد، گزینه کاملاً مخفی می‌شود، نه کم‌رنگ)
                // و (ب) قفلِ پلن (`PlanAccess`؛ اگر پلن قفل کند، گزینه
                // کم‌رنگ+قفل‌دار می‌ماند و با ضربه پیامِ ارتقا می‌دهد —
                // مستقلِ از نقش). اگر همه‌ی زیرگزینه‌هایِ یک منو به‌خاطرِ
                // نقش مخفی شوند، خودِ منو هم مخفی می‌شود.
                Builder(
                  builder: (context) {
                    final role = (user['role'] ?? '').toString();
                    final canViewTasks =
                        hasOrgPermission(role, OrgPermission.viewAllOrgTasks) ||
                        hasOrgPermission(role, OrgPermission.viewSectionTasks);
                    final canMonitorRoutines = hasOrgPermission(
                      role,
                      OrgPermission.monitorAllWorkflows,
                    );
                    final canViewPayroll = hasOrgPermission(
                      role,
                      OrgPermission.viewPayroll,
                    );
                    final anyVisible =
                        _itemVisible(
                          feature: PlanFeature.monitoringTasks,
                          roleAllowed: canViewTasks,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.monitoringRoutines,
                          roleAllowed: canMonitorRoutines,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.monitoringPayroll,
                          roleAllowed: canViewPayroll,
                        );
                    if (!anyVisible) return const SizedBox.shrink();
                    return _ExpandableDrawerItem(
                      c: c,
                      icon: Icons.visibility_outlined,
                      label: 'نظارت',
                      expanded: _expandedKey == 'نظارت',
                      onToggle: () => _toggleExpanded('نظارت'),
                      children: [
                        _drawerItem(
                          c: c,
                          icon: Icons.list_alt_rounded,
                          label: 'نظارت بر کارها',
                          feature: PlanFeature.monitoringTasks,
                          planLabel: 'نظارت بر کارها',
                          roleAllowed: canViewTasks,
                          onTap: () {
                            Get.back();
                            Get.to(() => const TasksOverviewPage());
                          },
                        ),
                        _drawerItem(
                          c: c,
                          icon: Icons.account_tree_outlined,
                          label: 'نظارت بر روتین‌های فعال',
                          feature: PlanFeature.monitoringRoutines,
                          planLabel: 'نظارت بر روتین‌های فعال',
                          roleAllowed: canMonitorRoutines,
                          onTap: () {
                            Get.back();
                            Get.to(() => const WorkflowMonitorPage());
                          },
                        ),
                        _drawerItem(
                          c: c,
                          icon: Icons.payments_outlined,
                          label: 'گزارش حقوق پرسنل',
                          feature: PlanFeature.monitoringPayroll,
                          planLabel: 'گزارش حقوق پرسنل',
                          roleAllowed: canViewPayroll,
                          onTap: () {
                            Get.back();
                            Get.to(() => const PayrollReportPage());
                          },
                        ),
                      ],
                    );
                  },
                ),
                // 🔧 طبق درخواست: زیرمنویِ «مدیریت» — همان توضیحِ بالا؛
                // دسترسیِ نقش از `org_permissions.dart`، مستقل از قفلِ پلن
                Builder(
                  builder: (context) {
                    final role = (user['role'] ?? '').toString();
                    final canManageUsers = hasOrgPermission(
                      role,
                      OrgPermission.manageUsers,
                    );
                    final canManageSections = hasOrgPermission(
                      role,
                      OrgPermission.manageActivitySections,
                    );
                    final canManageGroups = hasOrgPermission(
                      role,
                      OrgPermission.manageTaskGroups,
                    );
                    // 🔧 سه گزینه‌یِ آخر («دستگاه‌های حضور و غیاب»، «روزهای
                    // تعطیل»، «تنظیمات سیستم») هر سه دقیقاً همین یک مجوز
                    // را لازم دارند، عیناً مطابقِ سرورِ وب
                    final canViewOrgSettings = hasOrgPermission(
                      role,
                      OrgPermission.viewOrgSettings,
                    );
                    final anyVisible =
                        _itemVisible(
                          feature: PlanFeature.managementUsers,
                          roleAllowed: canManageUsers,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.managementActivitySections,
                          roleAllowed: canManageSections,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.managementGroups,
                          roleAllowed: canManageGroups,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.managementAttendanceDevices,
                          roleAllowed: canViewOrgSettings,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.managementHolidays,
                          roleAllowed: canViewOrgSettings,
                        ) ||
                        _itemVisible(
                          feature: PlanFeature.managementSystemSettings,
                          roleAllowed: canViewOrgSettings,
                        );
                    if (!anyVisible) return const SizedBox.shrink();
                    return _ExpandableDrawerItem(
                      c: c,
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'مدیریت',
                      expanded: _expandedKey == 'مدیریت',
                      onToggle: () => _toggleExpanded('مدیریت'),
                      children: [
                        _drawerItem(
                          c: c,
                          icon: Icons.people_alt_outlined,
                          label: 'مدیریت کاربران',
                          feature: PlanFeature.managementUsers,
                          planLabel: 'مدیریت کاربران',
                          roleAllowed: canManageUsers,
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
                          label: 'مدیریت واحدهای فعالیت',
                          feature: PlanFeature.managementActivitySections,
                          planLabel: 'مدیریت واحدهای فعالیت',
                          roleAllowed: canManageSections,
                          onTap: () {
                            Get.back();
                            showManageActivitySectionsSheet(context);
                          },
                        ),
                        _drawerItem(
                          c: c,
                          icon: Icons.folder_copy_outlined,
                          label: 'مدیریت گروه‌ها',
                          feature: PlanFeature.managementGroups,
                          planLabel: 'مدیریت گروه‌ها',
                          roleAllowed: canManageGroups,
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
                          label: 'دستگاه‌های حضور و غیاب',
                          feature: PlanFeature.managementAttendanceDevices,
                          planLabel: 'دستگاه‌های حضور و غیاب',
                          roleAllowed: canViewOrgSettings,
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
                          label: 'روزهای تعطیل',
                          feature: PlanFeature.managementHolidays,
                          planLabel: 'روزهای تعطیل',
                          roleAllowed: canViewOrgSettings,
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
                          label: 'تنظیمات سیستم',
                          feature: PlanFeature.managementSystemSettings,
                          planLabel: 'تنظیمات سیستم',
                          roleAllowed: canViewOrgSettings,
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
                  planLabel: 'گفتگو',
                  feature: PlanFeature.chat,
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
                  expanded: _expandedKey == 'پشتیبانی',
                  onToggle: () => _toggleExpanded('پشتیبانی'),
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

  // 🔧 آیتمِ منو کِی قابلِ‌مشاهده است؟ — یا به‌خاطرِ پلن قفل است (که
  // همیشه با قفل نشان داده می‌شود)، یا نقش اجازه می‌دهد. از این هم برایِ
  // خودِ `_drawerItem` و هم برایِ تشخیصِ «همه‌ی زیرگزینه‌ها مخفی‌اند» در
  // گروه‌هایِ بالادستی («نظارت»/«مدیریت») استفاده می‌شود
  bool _itemVisible({
    required PlanFeature? feature,
    required bool roleAllowed,
  }) {
    final locked = feature != null && !PlanAccess.allows(feature);
    return locked || roleAllowed;
  }

  Widget _drawerItem({
    required AppColors c,
    required IconData icon,
    required String label,
    bool selected = false,
    bool enabled = true,
    // 🔧 طبق درخواست: دسترسیِ نقشِ سازمانی (مدیر/سوپروایزر در مقابلِ
    // کارمندِ عادی) — مستقل از پلن. اگر false باشد و قفلِ پلن هم در کار
    // نباشد، گزینه کاملاً از منو حذف می‌شود (نه کم‌رنگ)
    bool roleAllowed = true,
    Color? color,
    PlanFeature? feature,
    String? planLabel,
    required VoidCallback onTap,
  }) {
    // 🔧 قفل طبقِ پلن: کم‌رنگ+قفل‌دار می‌شود و با ضربه، پیامِ دقیقِ پلنِ
    // لازم را نشان می‌دهد — این همیشه اولویت دارد، چون مستقل از نقش است
    final locked = feature != null && !PlanAccess.allows(feature);
    // 🔧 اگر نه قفلِ پلن در کار است و نه نقش اجازه می‌دهد، گزینه اصلاً
    // رندر نمی‌شود
    if (!locked && !roleAllowed) return const SizedBox.shrink();
    final itemColor = color ?? (selected ? c.primary : c.textStrong);
    // 🔧 طبقِ طرح: آیتمِ فعال یک قرصِ خطی (outline) دارد، نه پرشده —
    // بقیه‌ی آیتم‌ها ردیفِ ساده و بدون قاب هستند
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked
              ? () => showPlanUpgradeSheet(
                  label: planLabel ?? label,
                  feature: feature,
                )
              : onTap,
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
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: itemColor,
                    ),
                  ),
                ),
                // 🔧 طبق درخواست: آیکونِ قفل بعدِ هر گزینه‌ای که فقط به‌خاطرِ
                // پلن غیرفعال است
                if (locked) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.lock_outline_rounded, size: 17, color: itemColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    // 🔧 گزینه‌های قفل‌شده به‌خاطرِ پلن، کم‌رنگ ولی قابل‌لمس می‌مانند
    // (با ضربه، پیامِ ارتقا را نشان می‌دهند)
    if (locked) return Opacity(opacity: 0.5, child: row);
    // گزینه‌ای که هنوز «به‌زودی» است و قفلِ پلن ندارد، فقط غیرفعال می‌ماند
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

  /// 🔧 کنترل‌شده از والد (AppDrawer) — تا هم‌زمان فقط یکی باز بماند
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandableDrawerItem({
    required this.c,
    required this.icon,
    required this.label,
    required this.children,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_ExpandableDrawerItem> createState() => _ExpandableDrawerItemState();
}

class _ExpandableDrawerItemState extends State<_ExpandableDrawerItem> {
  final _key = GlobalKey();

  @override
  void didUpdateWidget(covariant _ExpandableDrawerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) {
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
    final expanded = widget.expanded;
    return Column(
      key: _key,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onToggle,
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
                      expanded
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
        if (expanded)
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
