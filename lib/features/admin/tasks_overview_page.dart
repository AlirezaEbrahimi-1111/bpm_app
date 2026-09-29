import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/task_labels.dart';
import '../../core/utils/task_search.dart';
import '../tasks/task_detail_page.dart';
import '../tasks/widgets/task_list_card.dart';

/// «نظارت بر کارها» — پورتِ pages/tasks-overview.php برایِ موبایل.
/// همان API وب: GET /api/tasks/overview.php?include_my_tasks=0|1
/// برایِ supervisor/is_manager=1: همه‌ی کارهایِ سازمان. برایِ manager:
/// فقط کارهایِ زیردستانِ مستقیم+غیرمستقیم (+خودش).
class TasksOverviewPage extends StatefulWidget {
  const TasksOverviewPage({super.key});

  @override
  State<TasksOverviewPage> createState() => _TasksOverviewPageState();
}

class _TasksOverviewPageState extends State<TasksOverviewPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _tasks = [];
  List<dynamic> _users = [];
  String? _userRole; // 'supervisor' | 'manager' — از پاسخِ سرور
  int? _subordinatesCount;

  String _query = '';
  bool _includeMyTasks = true;
  String? _filterCreatorId;
  String? _filterAssigneeId;
  String? _filterStatus;
  String? _filterType;

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
        ApiClient.dio.get(
          '/api/tasks/overview.php',
          queryParameters: {'include_my_tasks': _includeMyTasks ? '1' : '0'},
        ),
        ApiClient.dio.get('/api/users/list.php'),
      ]);
      final data = results[0].data;
      if (data['success'] == true) {
        setState(() {
          _tasks = data['tasks'] as List? ?? [];
          _userRole = data['user_role']?.toString();
          _subordinatesCount = data['subordinates_count'] is int
              ? data['subordinates_count']
              : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافتِ کارها';
          _isLoading = false;
        });
      }
      final usersData = results[1].data;
      if (usersData['success'] == true) {
        _users = usersData['users'] as List? ?? [];
      }
    } catch (_) {
      setState(() {
        _error = 'خطا در اتصال به سرور — احتمالاً دسترسیِ لازم را ندارید';
        _isLoading = false;
      });
    }
  }

  String _userLabel(dynamic u) {
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
  }

  List<dynamic> get _filtered {
    var list = _tasks;
    if (_filterCreatorId != null) {
      list = list
          .where((t) => t['creator_id']?.toString() == _filterCreatorId)
          .toList();
    }
    if (_filterAssigneeId != null) {
      list = list
          .where((t) => t['assignee_id']?.toString() == _filterAssigneeId)
          .toList();
    }
    if (_filterStatus != null) {
      list = list.where((t) => t['status'] == _filterStatus).toList();
    }
    if (_filterType != null) {
      list = list.where((t) => t['task_type'] == _filterType).toList();
    }
    if (_query.trim().isNotEmpty) {
      list = list.where((t) => taskMatchesQuery(t, _query)).toList();
    }
    return list;
  }

  bool get _hasActiveFilters =>
      _filterCreatorId != null ||
      _filterAssigneeId != null ||
      _filterStatus != null ||
      _filterType != null;

  void _openDetail(dynamic task) async {
    final result = await Get.to(() => TaskDetailPage(taskId: task['id']));
    if (result == true) _load();
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
          'نظارت بر کارها',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
                  if (_userRole == 'manager')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _subordinatesCount == null
                            ? 'کارهای زیردستان شما'
                            : 'کارهای زیردستان شما — $_subordinatesCount نفر',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ),
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: c.textStrong, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'جستجو در عنوان، توضیحات، شناسه...',
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
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showFilterSheet(c),
                      icon: Icon(
                        _hasActiveFilters
                            ? Icons.filter_alt_rounded
                            : Icons.filter_alt_outlined,
                        size: 18,
                        color: c.primary,
                      ),
                      label: Text(
                        _hasActiveFilters ? 'فیلتر (فعال)' : 'فیلتر',
                        style: TextStyle(
                          color: c.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: c.primary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  // 🔧 طبق وب: فقط برایِ manager معنا دارد (supervisor خودش
                  // همه‌چیز را می‌بیند)
                  if (_userRole == 'manager') ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() => _includeMyTasks = !_includeMyTasks);
                        _load();
                      },
                      child: Row(
                        children: [
                          Checkbox(
                            value: _includeMyTasks,
                            onChanged: (v) {
                              setState(() => _includeMyTasks = v ?? true);
                              _load();
                            },
                            activeColor: c.primary,
                          ),
                          Text(
                            'نمایش کارهای من',
                            style: TextStyle(fontSize: 13, color: c.textStrong),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'کاری یافت نشد',
                          style: TextStyle(color: c.textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map(
                      (t) => TaskListCard(
                        task: t,
                        showPeople: true,
                        onTap: () => _openDetail(t),
                        onChanged: _load,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _showFilterSheet(AppColors c) {
    String? creatorId = _filterCreatorId;
    String? assigneeId = _filterAssigneeId;
    String? status = _filterStatus;
    String? type = _filterType;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'فیلترها',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.textStrong,
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Column(
                        children: [
                          _filterRow(
                            c: c,
                            icon: Icons.person_search_outlined,
                            label: creatorId != null
                                ? _userLabel(
                                    _users.firstWhere(
                                      (u) => u['id'].toString() == creatorId,
                                      orElse: () => {},
                                    ),
                                  )
                                : 'همه تعریف‌کننده‌ها',
                            active: creatorId != null,
                            onTap: () async {
                              final picked = await _pickUser(
                                c,
                                title: 'تعریف‌کننده',
                                current: creatorId,
                              );
                              if (picked != _sentinel)
                                setSheetState(() => creatorId = picked);
                            },
                          ),
                          const SizedBox(height: 10),
                          _filterRow(
                            c: c,
                            icon: Icons.person_outline_rounded,
                            label: assigneeId != null
                                ? _userLabel(
                                    _users.firstWhere(
                                      (u) => u['id'].toString() == assigneeId,
                                      orElse: () => {},
                                    ),
                                  )
                                : 'همه مسئولین',
                            active: assigneeId != null,
                            onTap: () async {
                              final picked = await _pickUser(
                                c,
                                title: 'مسئول انجام',
                                current: assigneeId,
                              );
                              if (picked != _sentinel)
                                setSheetState(() => assigneeId = picked);
                            },
                          ),
                          const SizedBox(height: 10),
                          _filterRow(
                            c: c,
                            icon: Icons.flag_outlined,
                            label: status != null
                                ? TaskLabels.statusLabel(status)
                                : 'همه وضعیت‌ها',
                            active: status != null,
                            onTap: () async {
                              final picked = await _pickFromList(
                                c,
                                title: 'وضعیت',
                                options: TaskLabels.allStatuses,
                                current: status,
                                labelBuilder: TaskLabels.statusLabel,
                              );
                              if (picked != _sentinel)
                                setSheetState(() => status = picked);
                            },
                          ),
                          const SizedBox(height: 10),
                          _filterRow(
                            c: c,
                            icon: Icons.grid_view_rounded,
                            label: type == 'periodic'
                                ? 'مقطعی'
                                : type == 'continuous'
                                ? 'دوره‌ای'
                                : 'همه انواع',
                            active: type != null,
                            onTap: () async {
                              final picked = await _pickFromList(
                                c,
                                title: 'نوع کار',
                                options: const ['periodic', 'continuous'],
                                current: type,
                                labelBuilder: (v) =>
                                    v == 'periodic' ? 'مقطعی' : 'دوره‌ای',
                              );
                              if (picked != _sentinel)
                                setSheetState(() => type = picked);
                            },
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
                      4 + MediaQuery.of(ctx).padding.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _filterCreatorId = creatorId;
                                _filterAssigneeId = assigneeId;
                                _filterStatus = status;
                                _filterType = type;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'اعمال فیلتر',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setSheetState(() {
                            creatorId = null;
                            assigneeId = null;
                            status = null;
                            type = null;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18, bottom: 2),
                            child: Text(
                              'پاک‌سازی',
                              style: TextStyle(
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  static const _sentinel = '__unset__';

  Future<String?> _pickUser(
    AppColors c, {
    required String title,
    required String? current,
  }) {
    return _pickFromList(
      c,
      title: title,
      options: _users.map((u) => u['id'].toString()).toList(),
      current: current,
      labelBuilder: (id) => _userLabel(
        _users.firstWhere((u) => u['id'].toString() == id, orElse: () => {}),
      ),
    );
  }

  Future<String?> _pickFromList(
    AppColors c, {
    required String title,
    required List<String> options,
    required String? current,
    String Function(String)? labelBuilder,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: c.textStrong,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    children: [
                      ListTile(
                        title: Text(
                          'همه',
                          style: TextStyle(fontSize: 13.5, color: c.textStrong),
                        ),
                        trailing: current == null
                            ? Icon(Icons.check_rounded, color: c.primary)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(''),
                      ),
                      ...options.map(
                        (o) => ListTile(
                          title: Text(
                            labelBuilder?.call(o) ?? o,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: c.textStrong,
                            ),
                          ),
                          trailing: current == o
                              ? Icon(Icons.check_rounded, color: c.primary)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(o),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return _sentinel;
    return result.isEmpty ? null : result;
  }

  Widget _filterRow({
    required AppColors c,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? c.primary.withValues(alpha: 0.5) : c.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.textMuted),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: active ? c.primary : c.textStrong,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            Icon(Icons.expand_more_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
