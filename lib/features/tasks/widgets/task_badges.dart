import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_number.dart';
import '../../../core/utils/task_labels.dart';

/// منطقِ بجِ وضعیتِ کارها — پورتِ دقیقِ TF.statusBadge / TF.isOverdue از
/// نسخه‌ی وب (assets/js/task-filters.js). وب برای هر کار فقط «یک» بج
/// نشان می‌دهد؛ اولویتش: نیازمند تمدید > در انتظار تأیید > درخواست تمدید
/// موعد (منتظرِ من) > عقب افتاده > وضعیتِ خام (با دو استثنا برای
/// «ارجاع‌شده به من» و «دوره‌ی جدیدِ شروع‌نشده»). بج‌های ساختگیِ قبلی
/// («سررسید امروز»، «تأخیر»، «درخواست در انتظار») در وب وجود ندارند.

bool taskIsDone(dynamic task) =>
    task['status'] == 'completed' || task['status'] == 'approved';

bool _truthy(dynamic v) => v == 1 || v == true || v == '1';

String? _dateOnly(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return s.split(' ').first.split('T').first;
}

String _todayStr() {
  final d = DateTime.now();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)}';
}

bool _same(dynamic a, int? b) =>
    b != null && a != null && a.toString() == b.toString();

/// «تاریخ سررسیدِ مؤثر» — معادلِ TF.effectiveDue
String? taskEffectiveDue(dynamic t) {
  if (t['task_type'] == 'continuous') {
    return _dateOnly(t['next_due_date']) ?? _dateOnly(t['start_date']);
  }
  final dates = [
    t['due_date'],
    t['deadline'],
    t['original_deadline'],
  ].map(_dateOnly).whereType<String>().toList()..sort();
  return dates.isEmpty ? null : dates.last;
}

/// لحظه‌ی کاملِ موعد برای کارهای فرآیندی — معادلِ TF.effectiveDueMs
DateTime? _effectiveDueTime(dynamic t) {
  final raws = [t['due_date'], t['deadline'], t['original_deadline']]
      .where((v) => v != null && v.toString().isNotEmpty)
      .map((v) => v.toString())
      .toList();
  DateTime? latest;
  for (final r in raws) {
    final full = r.length <= 10 ? '$r 23:59:59' : r;
    final d = DateTime.tryParse(full.replaceFirst(' ', 'T'));
    if (d != null && (latest == null || d.isAfter(latest))) latest = d;
  }
  return latest;
}

bool _isWaitingMyApproval(dynamic t, int? userId) {
  if (userId == null || !_truthy(t['is_pending_approval'])) return false;
  return _same(t['creator_id'], userId) ||
      _same(t['current_approver_id'], userId);
}

bool _isWaitingMyDeadline(dynamic t, int? userId) {
  if (userId == null || !_truthy(t['has_pending_deadline_request']))
    return false;
  return _same(t['current_approver_id'], userId);
}

/// معادلِ TF.isOverdue
bool taskIsOverdue(dynamic t, [int? userId]) {
  userId ??= ApiClient.currentUserId;
  final today = _todayStr();
  if (taskIsDone(t)) return false;

  final lastPending = _dateOnly(t['last_pending_date']);
  if (_isWaitingMyApproval(t, userId) &&
      lastPending != null &&
      lastPending.compareTo(today) < 0) {
    return true;
  }
  final reqDate = _dateOnly(t['deadline_request_date']);
  if (_isWaitingMyDeadline(t, userId) &&
      reqDate != null &&
      reqDate.compareTo(today) < 0) {
    return true;
  }

  final status = t['status'];
  if (_truthy(t['is_workflow_task'])) {
    if (status != 'not_started' &&
        status != 'in_progress' &&
        status != 'delegated')
      return false;
    final due = _effectiveDueTime(t);
    if (due == null) return false;
    return DateTime.now().difference(due).inHours > 0;
  }

  if (t['task_type'] == 'continuous') {
    final end = _dateOnly(t['end_date']);
    if (end != null && end.compareTo(today) < 0) return false; // بازه تمام شده
    final op = t['overdue_periods'];
    final n = op is int ? op : int.tryParse(op?.toString() ?? '') ?? 0;
    return n > 0;
  }

  if (t['task_type'] == 'periodic') {
    final due = taskEffectiveDue(t);
    return due != null &&
        due.compareTo(today) < 0 &&
        (status == 'not_started' ||
            status == 'in_progress' ||
            status == 'delegated');
  }
  return false;
}

/// معادلِ TF.isDueToday — «امروز نیاز به اقدام دارد؟»
bool taskIsDueToday(dynamic t, [int? userId]) {
  userId ??= ApiClient.currentUserId;
  final today = _todayStr();
  if (taskIsDone(t)) return false;
  if (_isWaitingMyApproval(t, userId)) return true;
  if (_isWaitingMyDeadline(t, userId)) return true;

  final status = t['status'];
  if (_truthy(t['is_workflow_task']) &&
      (status == 'in_progress' || status == 'not_started')) {
    final due = taskEffectiveDue(t);
    if (due != null && due.compareTo(today) > 0) return false;
    return true;
  }

  if (t['task_type'] == 'continuous') {
    if (_truthy(t['needs_renewal_decision'])) return true;
    final end = _dateOnly(t['end_date']);
    if (end != null && end.compareTo(today) < 0) return false;
    final op = t['overdue_periods'];
    final n = op is int ? op : int.tryParse(op?.toString() ?? '') ?? 0;
    if (n > 0) return true;
    return taskEffectiveDue(t) == today;
  }

  if (t['task_type'] == 'periodic') {
    final due = taskEffectiveDue(t);
    return due != null && due.compareTo(today) <= 0;
  }
  return false;
}

/// یک بجِ وضعیت (آیکن، برچسب، رنگ) — معادلِ TF.statusBadge؛ همیشه دقیقاً
/// یک عضو برمی‌گرداند (به‌صورت لیست، تا فراخوانی‌های قبلی تغییر نکنند).
List<(IconData, String, Color)> badgesForTask(dynamic task) {
  final userId = ApiClient.currentUserId;
  final status = (task['status'] ?? 'not_started').toString();

  (IconData, String, Color) of(String key) => (
    TaskLabels.statusIcon(key),
    TaskLabels.statusLabel(key),
    TaskLabels.statusColor(key),
  );

  if (_truthy(task['needs_renewal_decision'])) {
    return [
      (Icons.autorenew_rounded, 'نیازمند تمدید', TaskLabels.needsRenewalColor),
    ];
  }
  if (status == 'pending_approval') return [of('pending_approval')];
  if (_isWaitingMyDeadline(task, userId)) {
    return [
      (
        Icons.hourglass_top_rounded,
        'درخواست تمدید موعد',
        TaskLabels.statusColor('pending_approval'),
      ),
    ];
  }
  if (taskIsOverdue(task, userId)) {
    return [
      (Icons.warning_amber_rounded, 'عقب افتاده', TaskLabels.overdueColor),
    ];
  }
  if (status == 'delegated' && _same(task['assignee_id'], userId)) {
    return [of('not_started')];
  }
  if (task['task_type'] == 'continuous' &&
      status == 'period_done' &&
      task['is_today_done'] == false &&
      !taskIsDone(task)) {
    return [of('not_started')];
  }
  return [of(status)];
}

Widget taskBadgeChip({
  required IconData icon,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

const _jalaliMonths = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// تاریخ موعدِ نمایشی — همان «تاریخ سررسیدِ مؤثر» وب (TF.effectiveDue)،
/// مثلاً «۲۸ مهر»؛ اگر تاریخی نبود null.
String? taskDueLabel(dynamic task) {
  final d = taskEffectiveDue(task) ?? _dateOnly(task['start_date']);
  if (d == null) return null;
  try {
    final j = Jalali.fromDateTime(DateTime.parse(d));
    return toPersianDigits('${j.day} ${_jalaliMonths[j.month - 1]}');
  } catch (_) {
    return null;
  }
}

/// ردیفِ «آیکن تقویم + تاریخِ موعد» — همه‌جا دقیقاً زیرِ عنوان و راست‌چین
/// (در راست‌به‌چپ، start یعنی سمتِ راست).
Widget taskDueRow(AppColors c, dynamic task) {
  final label = taskDueLabel(task);
  if (label == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 12, color: c.textMuted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
        ],
      ),
    ),
  );
}
