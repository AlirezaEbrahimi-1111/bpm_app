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
  static const Color overdueColor = Color(0xFFB91C1C);
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
