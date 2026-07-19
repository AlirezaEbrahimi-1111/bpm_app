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
  static const Map<String, String> _statusLabels = {
    'not_started': 'شروع نشده',
    'in_progress': 'در حال انجام',
    'completed': 'انجام شد',
    'approved': 'تأیید و انجام شد',
    'pending_approval': 'در انتظار تأیید',
    'delegated': 'ارجاع شد',
    'rejected': 'متوقف شده',
    'termination_requested': 'درخواست اتمام',
    'period_done': 'دوره انجام شد',
  };

  static const Map<String, Color> _statusColors = {
    'not_started': Color(0xFF9CA3AF),
    'in_progress': Color(0xFF3B82F6),
    'completed': Color(0xFF22C55E),
    'approved': Color(0xFF22C55E),
    'pending_approval': Color(0xFFF59E0B),
    'delegated': Color(0xFFF59E0B),
    'rejected': Color(0xFFEF4444),
    'termination_requested': Color(0xFFF59E0B),
    'period_done': Color(0xFF22C55E),
  };

  /// برچسب فارسی وضعیت. اگر ناشناخته بود، خودِ متن خام برمی‌گردد.
  static String statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'نامشخص';
    return _statusLabels[status] ?? status;
  }

  static Color statusColor(String? status) {
    if (status == null) return const Color(0xFF9CA3AF);
    return _statusColors[status] ?? const Color(0xFF9CA3AF);
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
    if (action == null) return const Color(0xFF9CA3AF);
    return _actionColors[action] ?? const Color(0xFF9CA3AF);
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
    if (priority == null) return const Color(0xFF9CA3AF);
    return _priorityColors[priority] ?? const Color(0xFF9CA3AF);
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
