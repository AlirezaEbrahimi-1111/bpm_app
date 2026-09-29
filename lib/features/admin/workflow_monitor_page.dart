import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/scrollable_chip_row.dart';

/// «نظارت بر روتین‌های فعال» — پورتِ pages/workflow-monitor.php برایِ
/// موبایل. آدرسِ داده دقیقاً همان API نسخه‌ی وب است:
///   GET  /api/workflows/list.php            فهرستِ همه‌ی نمونه‌های روتین
///   GET  /api/workflows/routines-list.php   فهرستِ قالب‌ها (برایِ فیلتر)
///   GET  /api/workflows/detail.php?id=      جزئیات + مراحل یک نمونه
///   POST /api/workflows/delete.php          حذفِ نرم {instance_id}
///   POST /api/workflows/restore.php         بازگردانی {instance_id}
///
/// 🔧 محدودیتِ عمدی: نسخه‌ی وب مراحلِ روتین را با یک نمودارِ گرافیکیِ
/// قابلِ‌کشیدن (drawflow.js) نشان می‌دهد — یک کتابخانه‌ی ترسیمِ فلوچارتِ
/// دسکتاپی که معادلِ موبایلی معنادار ندارد. به‌جایش این‌جا همان اطلاعات
/// (وضعیتِ هر مرحله، مسئول، مدت، تأخیر) به‌صورتِ یک تایم‌لاینِ عمودی
/// نشان داده می‌شود — از نظرِ محتوا کامل، فقط شکلِ نمایش ساده‌تر است.
class WorkflowMonitorPage extends StatefulWidget {
  const WorkflowMonitorPage({super.key});

  @override
  State<WorkflowMonitorPage> createState() => _WorkflowMonitorPageState();
}

const _statusLabels = {
  'in_progress': 'در حال اجرا',
  'delayed': 'دارای تأخیر',
  'completed': 'تکمیل شده',
  'cancelled': 'لغو شده',
};
const _stepStatusLabels = {
  'completed': 'تکمیل شده',
  'active': 'در حال انجام',
  'delayed': 'تأخیر',
  'pending': 'در انتظار',
};

Color _statusColor(AppColors c, String s) {
  switch (s) {
    case 'in_progress':
      return c.info;
    case 'delayed':
      return c.danger;
    case 'completed':
      return c.success;
    case 'cancelled':
      return c.textMuted;
    default:
      return c.textMuted;
  }
}

class _WorkflowMonitorPageState extends State<WorkflowMonitorPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _workflows = [];
  List<dynamic> _routines = [];

  String _filter =
      'active'; // all|active|in_progress|delayed|completed|cancelled
  String? _routineId;
  bool _onlyMine = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.dio.get('/api/workflows/list.php'),
        ApiClient.dio.get('/api/workflows/routines-list.php'),
      ]);
      final data = results[0].data;
      if (data['success'] == true) {
        setState(() {
          _workflows = data['workflows'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافتِ روتین‌ها';
          _isLoading = false;
        });
      }
      final routinesData = results[1].data;
      if (routinesData['success'] == true) {
        _routines = routinesData['routines'] as List? ?? [];
      }
    } catch (_) {
      setState(() {
        _error = 'خطا در اتصال به سرور — احتمالاً دسترسیِ لازم را ندارید';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    var list = _workflows;
    if (_filter == 'active') {
      list = list
          .where(
            (w) => w['status'] == 'in_progress' || w['status'] == 'delayed',
          )
          .toList();
    } else if (_filter != 'all') {
      list = list.where((w) => w['status'] == _filter).toList();
    }
    if (_routineId != null) {
      list = list
          .where((w) => w['workflow_id']?.toString() == _routineId)
          .toList();
    }
    if (_onlyMine) {
      final myId = ApiClient.currentUserId;
      list = list
          .where((w) => w['created_by']?.toString() == myId?.toString())
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (w) =>
                (w['title'] ?? '').toString().toLowerCase().contains(q) ||
                w['id'].toString() == q,
          )
          .toList();
    }
    return list;
  }

  int get _avgProgress {
    if (_workflows.isEmpty) return 0;
    final sum = _workflows.fold<num>(
      0,
      (s, w) => s + (w['progress'] is num ? w['progress'] as num : 0),
    );
    return (sum / _workflows.length).round();
  }

  Future<void> _confirmDelete(dynamic w) async {
    final c = AppColors.of(context);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        title: Text(
          'حذفِ روتین',
          style: TextStyle(color: c.textStrong, fontSize: 15),
        ),
        content: Text(
          '«${w['title'] ?? ''}» حذف شود؟ این کار قابلِ بازگشت است.',
          style: TextStyle(color: c.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.dio.post(
        '/api/workflows/delete.php',
        data: {'instance_id': w['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success(
          '🗑️ حذف شد',
          'روتین حذف شد',
          mainButton: TextButton(
            onPressed: () => _restore(w['id']),
            child: const Text(
              'بازگردانی',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در حذف');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _restore(dynamic id) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/workflows/restore.php',
        data: {'instance_id': id},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ بازگردانده شد', 'روتین بازگردانی شد');
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در بازگردانی',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _openDetail(dynamic w) {
    Get.bottomSheet(
      _WorkflowDetailSheet(instanceId: w['id'], onDeleted: _load),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bgPage,
      appBar: AppBar(
        backgroundColor: c.bgPage,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textStrong),
        title: Text(
          'نظارت بر روتین‌های فعال',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
        ),
        leading: IconButton(
          icon: Transform.rotate(
            angle: math.pi,
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: c.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textMuted),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _load,
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: c.primary,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          c,
                          'تعداد',
                          toPersianDigits(_workflows.length),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          c,
                          'میانگین پیشرفت',
                          toPersianDigits('$_avgProgress٪'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: c.textStrong, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'جستجو بر اساسِ عنوان یا شناسه...',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: c.textMuted,
                      ),
                      filled: true,
                      fillColor: c.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.borderSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: c.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ScrollableChipRow(
                      children: [
                        _pill(c, 'all', 'همه'),
                        _pill(c, 'active', 'جاری'),
                        _pill(c, 'in_progress', 'در حال اجرا'),
                        _pill(c, 'delayed', 'تأخیردار'),
                        _pill(c, 'completed', 'تکمیل‌شده'),
                        _pill(c, 'cancelled', 'لغوشده'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_routines.isNotEmpty)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _routineId,
                            isExpanded: true,
                            dropdownColor: c.surface,
                            style: TextStyle(
                              color: c.textStrong,
                              fontSize: 12.5,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              filled: true,
                              fillColor: c.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: c.borderSoft),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('همه روتین‌ها'),
                              ),
                              ..._routines.map(
                                (r) => DropdownMenuItem(
                                  value: r['id'].toString(),
                                  child: Text(
                                    r['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _routineId = v),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _onlyMine = !_onlyMine),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _onlyMine ? c.primary : c.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _onlyMine ? c.primary : c.borderSoft,
                            ),
                          ),
                          child: Text(
                            'روتین‌های من',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _onlyMine ? Colors.white : c.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'روتینی یافت نشد',
                          style: TextStyle(color: c.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((w) => _workflowCard(c, w)),
                ],
              ),
            ),
    );
  }

  Widget _statCard(AppColors c, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.borderSoft),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
      ],
    ),
  );

  Widget _pill(AppColors c, String key, String label) {
    final selected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.primary : c.borderSoft),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _workflowCard(AppColors c, dynamic w) {
    final status = (w['status'] ?? '').toString();
    final progress = (w['progress'] is num ? w['progress'] as num : 0)
        .toDouble();
    final assignee =
        '${w['assignee_first_name'] ?? ''} ${w['assignee_last_name'] ?? ''}'
            .trim();
    return GestureDetector(
      onTap: () => _openDetail(w),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                Expanded(
                  child: Text(
                    (w['title'] ?? '').toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: c.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(c, status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabels[status] ?? status,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: _statusColor(c, status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _confirmDelete(w),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: c.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'مرحله فعلی: ${w['current_stage_name'] ?? '—'}',
              style: TextStyle(fontSize: 12, color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (assignee.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'مسئول فعلی: $assignee',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (progress / 100).clamp(0, 1),
                minHeight: 6,
                backgroundColor: c.borderSoft,
                valueColor: AlwaysStoppedAnimation(_statusColor(c, status)),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  toPersianDigits('${w['total_stages'] ?? '—'} مرحله'),
                  style: TextStyle(fontSize: 10.5, color: c.textMuted),
                ),
                Text(
                  toPersianDigits('${progress.round()}٪'),
                  style: TextStyle(fontSize: 10.5, color: c.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// شیتِ جزئیاتِ یک نمونه‌ی روتین — اطلاعاتِ کلی + تایم‌لاینِ عمودیِ مراحل
/// (به‌جایِ نمودارِ درگ‌اند‌دراپِ وب که معادلِ موبایلی ندارد)
class _WorkflowDetailSheet extends StatefulWidget {
  final dynamic instanceId;
  final VoidCallback onDeleted;
  const _WorkflowDetailSheet({
    required this.instanceId,
    required this.onDeleted,
  });

  @override
  State<_WorkflowDetailSheet> createState() => _WorkflowDetailSheetState();
}

class _WorkflowDetailSheetState extends State<_WorkflowDetailSheet> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _workflow;
  List<dynamic> _steps = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/workflows/detail.php',
        queryParameters: {'id': widget.instanceId},
      );
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _workflow = (data['workflow'] as Map).cast<String, dynamic>();
          _steps = data['steps'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافتِ جزئیات';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'خطا در اتصال به سرور';
        _isLoading = false;
      });
    }
  }

  String _toShamsi(String? gregorian) {
    if (gregorian == null || gregorian.isEmpty) return '—';
    try {
      final date = DateTime.parse(gregorian.replaceFirst(' ', 'T'));
      final j = Jalali.fromDateTime(date);
      const mo = [
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
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return toPersianDigits('${j.day} ${mo[j.month - 1]} $h:$m');
    } catch (_) {
      return '—';
    }
  }

  String _duration(dynamic mins) {
    final m = mins is num ? mins.round() : 0;
    if (m <= 0) return '—';
    final h = m ~/ 60;
    final r = m % 60;
    if (h >= 24) {
      final d = h ~/ 24;
      final rh = h % 24;
      return toPersianDigits('$d روز${rh > 0 ? ' $rh ساعت' : ''}');
    }
    if (h > 0) return toPersianDigits('$h ساعت${r > 0 ? ' $r دقیقه' : ''}');
    return toPersianDigits('$m دقیقه');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: _isLoading
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: c.primary),
                  ),
                )
              : _error != null
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(_error!, style: TextStyle(color: c.textMuted)),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.borderSoft,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        (_workflow?['title'] ?? '').toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: c.textStrong,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      toPersianDigits('${_workflow?['progress'] ?? 0}٪ پیشرفت'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < _steps.length; i++)
                              _stepTile(
                                c,
                                _steps[i],
                                isLast: i == _steps.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        12 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Get.back();
                          _confirmDeleteFromSheet(context);
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: c.danger,
                        ),
                        label: Text(
                          'حذفِ این روتین',
                          style: TextStyle(color: c.danger),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: c.danger.withValues(alpha: 0.4),
                          ),
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _confirmDeleteFromSheet(BuildContext parentContext) async {
    final c = AppColors.of(parentContext);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        title: Text(
          'حذفِ روتین',
          style: TextStyle(color: c.textStrong, fontSize: 15),
        ),
        content: Text(
          'این روتین حذف شود؟',
          style: TextStyle(color: c.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.dio.post(
        '/api/workflows/delete.php',
        data: {'instance_id': widget.instanceId},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('🗑️ حذف شد', 'روتین حذف شد');
        widget.onDeleted();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در حذف');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Widget _stepTile(AppColors c, dynamic step, {required bool isLast}) {
    final status = (step['status'] ?? 'pending').toString();
    final color = status == 'completed'
        ? c.success
        : status == 'active'
        ? c.info
        : status == 'delayed'
        ? c.danger
        : c.textMuted;
    final assignee =
        '${step['assignee_first_name'] ?? ''} ${step['assignee_last_name'] ?? ''}'
            .trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: status == 'completed'
                    ? Icon(Icons.check, size: 14, color: color)
                    : null,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: c.borderSoft)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (step['step_name'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.textStrong,
                          ),
                        ),
                      ),
                      Text(
                        _stepStatusLabels[status] ?? status,
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (assignee.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'مسئول: $assignee',
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ],
                  if (step['started_at'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'شروع: ${_toShamsi(step['started_at']?.toString())}',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                  if (step['completed_at'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'پایان: ${_toShamsi(step['completed_at']?.toString())}',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                  if (step['duration_minutes'] != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'مدت: ${_duration(step['duration_minutes'])}',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
