/// ماتریسِ مجوزِ نقش‌هایِ سازمانی — دقیقاً هم‌معنا با ماتریسِ واقعیِ سمتِ
/// سرور (`includes/permissions.php` در نسخه‌ی وب)، نه چکِ سطحیِ جاوااسکریپتِ
/// سایدبار که با آن ناهماهنگ است (مثلاً «manager» در سایدبارِ وب دیده
/// نمی‌شود ولی واقعاً مجوزِ `manage_users`/`view_section_tasks` را دارد).
///
/// 🔧 طبق درخواست: این فایل فقط برایِ تشخیصِ «دسترسیِ نقش» است — کاملاً
/// مستقل از سطحِ پلن (`PlanAccess`). مخفی‌سازیِ گزینه‌هایِ منو طبقِ همین
/// فایل است؛ قفلِ پلن (برایِ کاربرِ رایگان/نقره‌ای) طبقِ `PlanAccess` است.
enum OrgPermission {
  viewAllOrgTasks,
  viewSectionTasks,
  monitorAllWorkflows,
  viewPayroll,
  manageUsers,
  manageActivitySections,
  manageTaskGroups,
  viewOrgSettings,
}

const Set<OrgPermission> _supervisorPermissions = {
  OrgPermission.viewAllOrgTasks,
  OrgPermission.viewSectionTasks,
  OrgPermission.monitorAllWorkflows,
  OrgPermission.viewPayroll,
  OrgPermission.manageUsers,
  OrgPermission.manageActivitySections,
  OrgPermission.manageTaskGroups,
  OrgPermission.viewOrgSettings,
};

const Map<String, Set<OrgPermission>> _orgPermissionMatrix = {
  'supervisor': _supervisorPermissions,
  // 🔧 طبق سرور: نامِ قدیمی/جایگزینِ «supervisor»، دقیقاً همان مجوزها
  'admin': _supervisorPermissions,
  'manager': {OrgPermission.viewSectionTasks, OrgPermission.manageUsers},
  'employee': <OrgPermission>{},
};

/// نقشِ ناشناخته (مثلِ «management» قدیمی) طبقِ همان قانونِ سرور، بدونِ
/// هیچ مجوزی حساب می‌شود (fail-closed)
bool hasOrgPermission(String? role, OrgPermission permission) =>
    (_orgPermissionMatrix[role] ?? const <OrgPermission>{}).contains(
      permission,
    );
