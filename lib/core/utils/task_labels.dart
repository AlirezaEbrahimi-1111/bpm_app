import '../theme/theme_controller.dart';
import 'package:flutter/material.dart';

/// نگاشت مرکزی وضعیت‌ها، اکشن‌های تاریخچه، اولویت‌ها و دوره‌های تکرار
/// به برچسب فارسی + رنگ + آیکون.
///
/// ⚠️ منبع مرجع همیشه نسخه وب است (فایل task-detail.php، توابع
/// getStatusLabel / getActionLabel / getPriorityLabel).
/// هر تغییری در متن‌ها باید ابتدا در وب دیده شود، سپس اینجا هماهنگ شود.
///
/// اگر سرور یک status یا action ناشناخته بفرستد (چیزی که در جدول‌های
/// زیر نیست)، به‌جای نمایش برچسب گمراه‌کننده، خودِ متن خام از سرور
/// نمایش داده می‌شود تا حداقل چیز نادرستی به کاربر نشان داده نشود.
class TaskLabels {
  TaskLabels._();

  // ───────────────────── وضعیت کار (status) ─────────────────────
  // 🔧 عیناً مطابقِ نسخه‌ی وب (TF.statusCfg در assets/js/task-filters.js و
  // رنگ‌های .status-* در assets/css/custom.css — رنگِ متنِ هر بج)
  static const Map<String, String> _statusLabels = {
    'not_started': 'شروع نشده',
    'in_progress': 'در حال انجام',
    'pending_approval': 'در انتظار تأیید',
    'completed': 'تکمیل شده',
    'approved': 'تأیید شده',
    'delegated': 'ارجاع شده',
    'rejected': 'متوقف شده(کارهای عادی)',
    'stopped': 'متوقف شده(فرآیندها)',
    'period_done': 'دوره انجام شد',
    'termination_requested': 'در انتظار اتمام',
  };

  static const Map<String, Color> _statusColors = {
    'not_started': Color(0xFF495057),
    'in_progress': Color(0xFF1554D1),
    'pending_approval': Color(0xFFA16207),
    'completed': Color(0xFF1B7B39),
    'approved': Color(0xFF0F7A2E),
    'delegated': Color(0xFF8E57FE),
    'rejected': Color(0xFFC81E1E),
    'stopped': Color(0xFF495057),
    'period_done': Color(0xFF0E7490),
    'termination_requested': Color(0xFF158463),
  };

  /// رنگِ بجِ «عقب افتاده» و «نیازمند تمدید» (وب: .status-overdue / .status-needs_renewal)
  // 🔧 طبق درخواست: همرنگِ بجِ «خروج» در مدیریتِ دستگاه‌ها (c.danger) تا در
  // تمِ تاریک هم متن و زمینه‌اش خوانا باشد — قبلاً قرمزِ تیره بود و روی سطحِ
  // تیره کم‌کنتراست می‌شد
  static const Color overdueColor = Color(0xFFEF4444);
  static const Color needsRenewalColor = Color(0xFF8E57FE);

  /// فهرستِ کاملِ کلیدهایِ خامِ وضعیت — طبقِ همان واژگانِ مشترکِ نسخه‌ی
  /// وب (STATUS_FILTERS گروهِ «کار عادی» در assets/js/task-filters.js)،
  /// برایِ استفاده در فیلترهایی که باید همه‌ی وضعیت‌های ممکن را نشان
  /// دهند، نه فقط آن‌هایی که در لیستِ فعلاً بارگذاری‌شده دیده می‌شوند.
  static const List<String> allStatuses = [
    'not_started',
    'in_progress',
    'pending_approval',
    'delegated',
    'completed',
    'approved',
    'termination_requested',
    'rejected',
    'stopped',
    'period_done',
  ];

  /// برچسب فارسی وضعیت. اگر ناشناخته بود، خودِ متن خام برمی‌گردد.
  static String statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'نامشخص';
    return _statusLabels[status] ?? status;
  }

  // 🔧 طبق درخواست: در تمِ تاریک هیچ رنگِ خاکستری/طوسی نباشد
  static Color _noGrey(Color c) =>
      (ThemeController.isDark &&
          (c.toARGB32() == 0xFF9CA3AF || c.toARGB32() == 0xFF495057))
      ? Colors.white
      : c;

  static Color statusColor(String? status) {
    if (status == null) return _noGrey(const Color(0xFF9CA3AF));
    return _noGrey(_statusColors[status] ?? const Color(0xFF9CA3AF));
  }

  // آیکن‌ها معادلِ bootstrap-icons در TF.statusCfg وب
  static const Map<String, IconData> _statusIcons = {
    'not_started': Icons.circle_outlined,
    'in_progress': Icons.play_circle_outline_rounded,
    'pending_approval': Icons.hourglass_top_rounded,
    'completed': Icons.check_circle_outline_rounded,
    'approved': Icons.check_circle_rounded,
    'delegated': Icons.swap_horiz_rounded,
    'rejected': Icons.pause_circle_outline_rounded,
    'stopped': Icons.stop_circle_outlined,
    'period_done': Icons.event_available_rounded,
    'termination_requested': Icons.hourglass_top_rounded,
  };

  static IconData statusIcon(String? status) {
    if (status == null) return Icons.circle_outlined;
    return _statusIcons[status] ?? Icons.circle_outlined;
  }

  // ───────────────── اکشن‌های تاریخچه فعالیت‌ها (action) ─────────────────
  static const Map<String, String> _actionLabels = {
    // برچسب‌های زیر عیناً از نسخه وب گرفته شده‌اند
    'created': 'ایجاد',
    'assigned': 'واگذاری',
    'completed': 'تکمیل',
    'pending_approval': 'در انتظار تأیید',
    'approved': 'تأیید',
    'rejected': 'رد',
    'stopped': 'توقف',
    'delegated': 'ارجاع',
    'updated': 'یادآوری',
    'deadline_extended': 'تمدید موعد',
    'termination_requested': 'درخواست اتمام',
    'checklist_sync': 'به‌روزرسانی چک‌لیست',
    'period_done': 'دوره انجام شد',
    // اکشن‌های اضافی که فقط توسط اپ موبایل رصد می‌شوند
    // (در نسخه وب برچسب اختصاصی برایشان تعریف نشده)
    'started': 'شروع شد',
    'reopened': 'بازگشایی شد',
    'deleted': 'حذف شد',
    'completion_approved': 'تأیید شد',
    'completion_rejected': 'رد شد',
    // 🔧 این پنج اکشن قبلاً با کدِ عمومیِ 'updated' ثبت می‌شدند و همه
    // «یادآوری» برچسب می‌گرفتند (باگی که به‌تازگی سمتِ بک‌اند رفع شد —
    // مهاجرتِ ۲۰۲۶۱۰۱۰_۱۰۰۰۰۰)؛ برچسب‌ها عیناً از نسخه‌ی وب گرفته شده‌اند
    'task_edited': 'ویرایش کار',
    'due_date_cleared': 'حذف موعد',
    'overdue_clear_requested': 'درخواست رفع دوره‌ی معوقه',
    'overdue_cleared': 'رفع دوره‌ی معوقه',
    'overdue_clear_rejected': 'رد درخواست رفع دوره‌ی معوقه',
    // 🔧 این ۱۴ اکشن در نسخه‌ی وب (assets/js/task-filters.js) تعریف شده‌اند
    // ولی تا الان در اپ نبودند — همین باعث می‌شد به‌جای برچسبِ فارسی،
    // کدِ خامِ انگلیسی (مثلاً «checklist_assigned» یا «in_progress») در
    // تاریخچه دیده بشه
    'completed_rejected': 'تکمیل ردشده',
    'deadline_requested': 'درخواست تمدید موعد',
    'deadline_rejected': 'رد درخواست تمدید موعد',
    'checklist_assigned': 'ارجاع آیتم چک‌لیست',
    'checklist_done': 'انجام آیتم چک‌لیست',
    'workflow_prev_note': 'توضیحات مرحله‌ی قبل',
    'renewal_applied': 'تمدید دوره',
    'renewal_requested': 'درخواست تمدید دوره',
    'renewal_step_approved': 'تأیید تمدید دوره',
    'renewal_rejected': 'رد تمدید دوره',
    'attachment_added': 'بارگذاری فایل',
    'attachment_removed': 'حذف فایل',
    'in_progress': 'شروع',
    'not_started': 'شروع نشده',
  };

  static const Map<String, Color> _actionColors = {
    'created': Color(0xFF6C63FF),
    'assigned': Color(0xFF3B82F6),
    'completed': Color(0xFF22C55E),
    'pending_approval': Color(0xFFF59E0B),
    'approved': Color(0xFF22C55E),
    'rejected': Color(0xFFEF4444),
    'stopped': Color(0xFF9CA3AF),
    'delegated': Color(0xFFF59E0B),
    'updated': Color(0xFF6C63FF),
    'deadline_extended': Color(0xFFF59E0B),
    'termination_requested': Color(0xFFF59E0B),
    'checklist_sync': Color(0xFF6C63FF),
    'period_done': Color(0xFF22C55E),
    'started': Color(0xFF3B82F6),
    'reopened': Color(0xFF3B82F6),
    'deleted': Color(0xFFEF4444),
    'completion_approved': Color(0xFF22C55E),
    'completion_rejected': Color(0xFFEF4444),
    'task_edited': Color(0xFF6C63FF),
    'due_date_cleared': Color(0xFFF59E0B),
    'overdue_clear_requested': Color(0xFFF59E0B),
    'overdue_cleared': Color(0xFF22C55E),
    'overdue_clear_rejected': Color(0xFFEF4444),
    'completed_rejected': Color(0xFFEF4444),
    'deadline_requested': Color(0xFFF59E0B),
    'deadline_rejected': Color(0xFFEF4444),
    'checklist_assigned': Color(0xFFF59E0B),
    'checklist_done': Color(0xFF22C55E),
    'workflow_prev_note': Color(0xFF22C55E),
    'renewal_applied': Color(0xFF22C55E),
    'renewal_requested': Color(0xFFF59E0B),
    'renewal_step_approved': Color(0xFF22C55E),
    'renewal_rejected': Color(0xFFEF4444),
    'attachment_added': Color(0xFF6C63FF),
    'attachment_removed': Color(0xFFEF4444),
    'in_progress': Color(0xFF6C63FF),
    'not_started': Color(0xFFF59E0B),
  };

  static const Map<String, IconData> _actionIcons = {
    'created': Icons.add_circle_outline,
    'assigned': Icons.person_add_outlined,
    'completed': Icons.check_circle_outline,
    'pending_approval': Icons.hourglass_empty_rounded,
    'approved': Icons.verified_outlined,
    'rejected': Icons.cancel_outlined,
    'stopped': Icons.stop_circle_outlined,
    'delegated': Icons.send_outlined,
    'updated': Icons.notifications_active_outlined,
    'deadline_extended': Icons.event_repeat_rounded,
    'termination_requested': Icons.flag_outlined,
    'checklist_sync': Icons.checklist_rounded,
    'period_done': Icons.task_alt_rounded,
    'started': Icons.play_circle_outline,
    'reopened': Icons.refresh_rounded,
    'deleted': Icons.delete_outline_rounded,
    'completion_approved': Icons.verified_outlined,
    'completion_rejected': Icons.cancel_outlined,
    'task_edited': Icons.edit_outlined,
    'due_date_cleared': Icons.event_busy_outlined,
    'overdue_clear_requested': Icons.hourglass_empty_rounded,
    'overdue_cleared': Icons.event_available_rounded,
    'overdue_clear_rejected': Icons.cancel_outlined,
    'completed_rejected': Icons.cancel_outlined,
    'deadline_requested': Icons.event_repeat_rounded,
    'deadline_rejected': Icons.cancel_outlined,
    'checklist_assigned': Icons.send_outlined,
    'checklist_done': Icons.check_circle_outline,
    'workflow_prev_note': Icons.notes_rounded,
    'renewal_applied': Icons.autorenew_rounded,
    'renewal_requested': Icons.hourglass_empty_rounded,
    'renewal_step_approved': Icons.verified_outlined,
    'renewal_rejected': Icons.cancel_outlined,
    'attachment_added': Icons.attach_file_rounded,
    'attachment_removed': Icons.delete_outline_rounded,
    'in_progress': Icons.play_circle_outline,
    'not_started': Icons.pause_circle_outline,
  };

  /// برچسب فارسی اکشن تاریخچه. اگر ناشناخته بود، خودِ متن خام برمی‌گردد.
  static String actionLabel(String? action) {
    if (action == null || action.isEmpty) return 'نامشخص';
    return _actionLabels[action] ?? action;
  }

  static Color actionColor(String? action) {
    if (action == null) return _noGrey(const Color(0xFF9CA3AF));
    return _noGrey(_actionColors[action] ?? const Color(0xFF9CA3AF));
  }

  static IconData actionIcon(String? action) {
    if (action == null) return Icons.circle_outlined;
    return _actionIcons[action] ?? Icons.circle_outlined;
  }

  // ───────── بجِ رنگیِ تاریخچه (ab-* در assets/css/custom.css) ─────────
  // 🔧 این نگاشت جدا از _actionColors است چون وب برایِ بجِ تاریخچه از
  // ۷ دسته‌یِ رنگیِ ثابت استفاده می‌کند (نه یک رنگِ جداگانه برایِ هر
  // اکشن)؛ عیناً همان دسته‌بندی و همان کدهایِ رنگِ وب
  static const Map<String, String> _actionBadgeClass = {
    'created': 'created',
    'assigned': 'created',
    'completed': 'completed',
    'approved': 'completed',
    'overdue_cleared': 'completed',
    'renewal_applied': 'completed',
    'renewal_step_approved': 'completed',
    'checklist_done': 'completed',
    'period_done': 'completed',
    'workflow_prev_note': 'completed',
    'pending_approval': 'pending',
    'termination_requested': 'pending',
    'overdue_clear_requested': 'pending',
    'renewal_requested': 'pending',
    'not_started': 'pending',
    'rejected': 'rejected',
    'stopped': 'rejected',
    'completed_rejected': 'rejected',
    'overdue_clear_rejected': 'rejected',
    'deadline_rejected': 'rejected',
    'renewal_rejected': 'rejected',
    'deleted': 'rejected',
    'attachment_removed': 'rejected',
    'completion_rejected': 'rejected',
    'delegated': 'delegated',
    'checklist_assigned': 'delegated',
    'updated': 'updated',
    'task_edited': 'updated',
    'checklist_sync': 'updated',
    'attachment_added': 'updated',
    'in_progress': 'updated',
    'started': 'updated',
    'deadline_extended': 'deadline',
    'deadline_requested': 'deadline',
    'due_date_cleared': 'deadline',
  };

  static const Map<String, Color> _badgeBg = {
    'created': Color(0x1F1B7B39), // rgba(27,123,57,0.12)
    'completed': Color(0xFFE3F2FD),
    'pending': Color(0xFFFFF3E0),
    'rejected': Color(0xFFFCE4EC),
    'delegated': Color(0x1F8E57FE), // rgba(142,87,254,0.12)
    'updated': Color(0xFFE0F7FA),
    'deadline': Color(0xFFFFF8E1),
  };

  static const Map<String, Color> _badgeFg = {
    'created': Color(0xFF1B7B39),
    'completed': Color(0xFF1565C0),
    'pending': Color(0xFFE65100),
    'rejected': Color(0xFFB71C1C),
    'delegated': Color(0xFF8E57FE),
    'updated': Color(0xFF006064),
    'deadline': Color(0xFFF57F17),
  };

  static String _badgeCategory(String? action) =>
      _actionBadgeClass[action] ?? 'updated';

  /// رنگِ پس‌زمینه‌یِ بجِ اکشن در تاریخچه — عیناً مطابقِ وب
  static Color historyBadgeBg(String? action) =>
      _badgeBg[_badgeCategory(action)]!;

  /// رنگِ متنِ بجِ اکشن در تاریخچه — عیناً مطابقِ وب
  static Color historyBadgeFg(String? action) =>
      _badgeFg[_badgeCategory(action)]!;

  // ───────────────────────── اولویت کار ─────────────────────────
  static const Map<String, String> _priorityLabels = {
    'high': 'بالا',
    'medium': 'متوسط',
    'low': 'پایین',
  };

  static const Map<String, Color> _priorityColors = {
    'high': Color(0xFFEF4444),
    'medium': Color(0xFFF59E0B),
    'low': Color(0xFF22C55E),
  };

  static String priorityLabel(String? priority) {
    if (priority == null || priority.isEmpty) return 'نامشخص';
    return _priorityLabels[priority] ?? priority;
  }

  static Color priorityColor(String? priority) {
    if (priority == null) return _noGrey(const Color(0xFF9CA3AF));
    return _noGrey(_priorityColors[priority] ?? const Color(0xFF9CA3AF));
  }

  // ───────────────────────── دوره تکرار ─────────────────────────
  static const Map<String, String> _periodLabels = {
    'daily': 'روزانه',
    'weekly': 'هفتگی',
    'monthly': 'ماهانه',
  };

  static String periodLabel(String? period) {
    if (period == null || period.isEmpty) return '—';
    return _periodLabels[period] ?? period;
  }
}
