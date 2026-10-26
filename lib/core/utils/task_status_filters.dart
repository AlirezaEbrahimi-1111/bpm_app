import '../../features/tasks/widgets/task_badges.dart';

/// فیلترِ وضعیتِ مشترکِ همه‌ی صفحه‌هایِ لیستِ کار — پورتِ دقیقِ
/// `STATUS_FILTERS` و `matchesStatusFilter` در assets/js/task-filters.js وب.
///
/// بعضی گزینه‌ها «مشتق»‌اند (عقب‌افتاده، نیازمند تمدید، ...) و مقدارِ متناظری
/// در دیتابیس ندارند — منطقشان در [match] است. گروه‌ها (عمومی / کار عادی /
/// روتین) مثلِ optgroupهایِ وب در انتخابگر نمایش داده می‌شوند.
class TaskStatusFilter {
  final String key;
  final String label;
  final String group;
  final bool Function(dynamic t, int? userId) match;
  const TaskStatusFilter(this.key, this.label, this.group, this.match);
}

bool _truthy(dynamic v) => v == 1 || v == true || v == '1';
bool _wf(dynamic t) => _truthy(t['is_workflow_task']);
bool _nwf(dynamic t) => !_wf(t);
bool _isMe(dynamic id, int? u) =>
    u != null && id != null && id.toString() == u.toString();
bool _needsRenewal(dynamic t) => _truthy(t['needs_renewal_decision']);
bool _periodOpenToday(dynamic t) =>
    t['task_type'] == 'continuous' &&
    t['status'] == 'period_done' &&
    t['is_today_done'] == false &&
    !taskIsDone(t);

const _closed = {'completed', 'approved', 'rejected', 'stopped'};

final List<TaskStatusFilter> taskStatusFilters = [
  // ── عمومی ──
  TaskStatusFilter(
    'open',
    'باز',
    'عمومی',
    (t, u) => !_closed.contains(t['status']),
  ),
  TaskStatusFilter('overdue', 'عقب‌افتاده', 'عمومی', (t, u) {
    return taskIsOverdue(t, u);
  }),
  TaskStatusFilter(
    'done',
    'تمام‌شده',
    'عمومی',
    (t, u) => t['status'] == 'completed' || t['status'] == 'approved',
  ),
  // ── کار عادی ──
  TaskStatusFilter(
    't_not_started',
    'شروع نشده',
    'کار عادی',
    (t, u) => _nwf(t) && (t['status'] == 'not_started' || _periodOpenToday(t)),
  ),
  TaskStatusFilter(
    't_in_progress',
    'در حال انجام',
    'کار عادی',
    (t, u) => _nwf(t) && t['status'] == 'in_progress',
  ),
  TaskStatusFilter(
    't_deleg_by_me',
    'واگذار کرده‌ام',
    'کار عادی',
    (t, u) =>
        _nwf(t) && t['status'] == 'delegated' && !_isMe(t['assignee_id'], u),
  ),
  TaskStatusFilter(
    't_deleg_to_me',
    'به من واگذار شده',
    'کار عادی',
    (t, u) =>
        _nwf(t) && t['status'] == 'delegated' && _isMe(t['assignee_id'], u),
  ),
  TaskStatusFilter(
    't_pending',
    'در انتظار تأیید',
    'کار عادی',
    (t, u) => _nwf(t) && t['status'] == 'pending_approval',
  ),
  TaskStatusFilter(
    't_termination',
    'در انتظار اتمام',
    'کار عادی',
    (t, u) => _nwf(t) && t['status'] == 'termination_requested',
  ),
  TaskStatusFilter(
    't_renewal',
    'نیازمند تمدید دوره',
    'کار عادی',
    (t, u) => _nwf(t) && _needsRenewal(t),
  ),
  TaskStatusFilter(
    't_period_today',
    'دوره امروز انجام شد',
    'کار عادی',
    (t, u) =>
        _nwf(t) && t['status'] == 'period_done' && t['is_today_done'] == true,
  ),
  TaskStatusFilter(
    't_completed',
    'تکمیل‌شده (منتظر تأیید)',
    'کار عادی',
    (t, u) => _nwf(t) && t['status'] == 'completed',
  ),
  TaskStatusFilter(
    't_approved',
    'تأییدشده',
    'کار عادی',
    (t, u) => _nwf(t) && t['status'] == 'approved',
  ),
  TaskStatusFilter(
    't_rejected',
    'متوقف‌شده',
    'کار عادی',
    (t, u) => _nwf(t) && t['status'] == 'rejected',
  ),
  // ── روتین ──
  TaskStatusFilter(
    'wf_not_started',
    'مرحله شروع‌نشده',
    'روتین',
    (t, u) =>
        _wf(t) && (t['status'] == 'not_started' || t['status'] == 'delegated'),
  ),
  TaskStatusFilter(
    'wf_active',
    'مرحله در حال انجام',
    'روتین',
    (t, u) => _wf(t) && t['status'] == 'in_progress',
  ),
  TaskStatusFilter(
    'wf_pending',
    'مرحله در انتظار تأیید',
    'روتین',
    (t, u) => _wf(t) && t['status'] == 'pending_approval',
  ),
  TaskStatusFilter(
    'wf_delayed',
    'مرحله دارای تأخیر (گلوگاه)',
    'روتین',
    (t, u) => _wf(t) && taskIsOverdue(t, u),
  ),
  TaskStatusFilter(
    'wf_completed',
    'مرحله تکمیل‌شده (منتظر تأیید)',
    'روتین',
    (t, u) => _wf(t) && t['status'] == 'completed',
  ),
  TaskStatusFilter(
    'wf_approved',
    'مرحله تأییدشده',
    'روتین',
    (t, u) => _wf(t) && t['status'] == 'approved',
  ),
  TaskStatusFilter(
    'wf_stopped',
    'فرآیند متوقف‌شده',
    'روتین',
    (t, u) => _wf(t) && t['status'] == 'stopped',
  ),
];

final Map<String, TaskStatusFilter> _byKey = {
  for (final f in taskStatusFilters) f.key: f,
};

/// کلیدهایِ همه‌ی گزینه‌ها (برایِ انتخابگر)، به ترتیبِ وب
List<String> get taskStatusFilterKeys =>
    taskStatusFilters.map((f) => f.key).toList();

String taskStatusFilterLabel(String key) => _byKey[key]?.label ?? key;
String taskStatusFilterGroup(String key) => _byKey[key]?.group ?? '';

/// معادلِ TF.matchesStatusFilter — کلیدِ ناشناخته = مقایسه‌ی خامِ status
bool taskMatchesStatusFilter(dynamic t, String? key, int? userId) {
  if (key == null || key.isEmpty || key == 'all') return true;
  final f = _byKey[key];
  if (f != null) return f.match(t, userId);
  return t['status'] == key;
}
