import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import 'task_detail_page.dart';
import '../profile/profile_page.dart';
import '../../core/utils/task_labels.dart';

class MyTasksPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onMenuTap;
  const MyTasksPage({super.key, required this.user, this.onMenuTap});
  @override
  State<MyTasksPage> createState() => MyTasksPageState();
}

class MyTasksPageState extends State<MyTasksPage> {
  Map<String, dynamic>? _stats;
  List<dynamic> _myTasks = [];
  bool _isLoading = true;
  String? _loadError;
  String _filter = 'همه';
  List<dynamic> _groups = [];
  int? _selectedGroupId;

  static const _primary = Color(0xFF6D28D9);
  static const _ink = Color(0xFF1A1A2E);
  static const _bg = Color(0xFFF7F7FB);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // متد عمومی برای refresh از بیرون (مثلاً بعد از ساخت کار)
  void reload() => _loadData();

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    // ── ۱) آمار (مستقل) ──
    try {
      final statsRes = await ApiClient.dio.get('/api/tasks/stats.php');
      if (statsRes.data['success'] == true) {
        _stats = statsRes.data['stats'];
      }
    } catch (_) {
      // خطای آمار نباید بقیه را متوقف کند
    }

    // ── ۲) کارهای من (مهم‌ترین — مستقل) ──
    // ── ۲) کارهای من ──
    try {
      final tasksRes = await ApiClient.dio.get('/api/tasks/my-tasks.php');
      final data = ApiClient.parseResponse(tasksRes.data);
      if (data['success'] == true) {
        final list = data['data']?['tasks'];
        _myTasks = list is List ? List<dynamic>.from(list) : [];
      } else {
        _loadError = data['message']?.toString() ?? 'خطا در دریافت کارها';
      }
    } catch (e) {
      _loadError = 'خطا در اتصال به سرور';
    }

    // ── ۳) گروه‌ها (فقط برای مدیران — اگر خطا داد مهم نیست) ──
    try {
      final groupsRes = await ApiClient.dio.get(
        '/api/task-groups/list-all.php',
      );
      if (groupsRes.data['success'] == true) {
        final all = groupsRes.data['groups'] as List? ?? [];
        final myId = widget.user['id'];
        _groups = all.where((g) {
          final scope = g['scope'];
          if (scope == 'org') return true;
          return g['created_by']?.toString() == myId.toString();
        }).toList();
      }
    } catch (_) {
      // کاربر عادی به گروه‌ها دسترسی ندارد — طبیعی است
      _groups = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _getShamsiDate() {
    final now = Jalali.now();
    const wd = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
    ];
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
    return toPersianDigits(
      '${wd[now.weekDay - 1]}، ${now.day} ${mo[now.month - 1]} ${now.year}',
    );
  }

  List<dynamic> get _filteredTasks {
    List<dynamic> list;
    if (_filter == 'همه') {
      list = List.from(_myTasks);
    } else if (_filter == 'امروز') {
      list = _myTasks.where((t) => t['days_remaining'] == 0).toList();
    } else if (_filter == 'عقب افتاده') {
      list = _myTasks
          .where(
            (t) =>
                t['status'] != 'completed' &&
                t['status'] != 'approved' &&
                (t['days_remaining'] ?? 0) < 0,
          )
          .toList();
    } else if (_filter == 'انجام شده') {
      list = _myTasks
          .where((t) => t['status'] == 'completed' || t['status'] == 'approved')
          .toList();
    } else {
      list = List.from(_myTasks);
    }

    if (_selectedGroupId != null) {
      list = list
          .where((t) => t['group_id'].toString() == _selectedGroupId.toString())
          .toList();
    }

    list.sort((a, b) {
      final aDone = a['status'] == 'completed' || a['status'] == 'approved';
      final bDone = b['status'] == 'completed' || b['status'] == 'approved';
      if (aDone && !bDone) return 1;
      if (!aDone && bDone) return -1;
      final aDays = (a['days_remaining'] ?? 9999) as int;
      final bDays = (b['days_remaining'] ?? 9999) as int;
      return aDays.compareTo(bDays);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      sliver: SliverToBoxAdapter(child: _buildTopBar()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      sliver: SliverToBoxAdapter(child: _buildTitle()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      sliver: SliverToBoxAdapter(child: _buildFilters()),
                    ),
                    if (_groups.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        sliver: SliverToBoxAdapter(child: _buildGroupFilter()),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                      sliver: _buildTaskSliver(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    final first = widget.user['first_name'] ?? 'U';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: widget.onMenuTap,
          icon: const Icon(Icons.menu_rounded, size: 26, color: _ink),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        GestureDetector(
          onTap: () => Get.to(() => ProfilePage(user: widget.user)),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: _primary.withValues(alpha: 0.15),
            child: Text(
              first.toString().isNotEmpty ? first.toString()[0] : 'U',
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'کارهای من',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: _ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _getShamsiDate(),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildGroupFilter() {
    Color parseColor(String? hex) {
      if (hex == null || hex.isEmpty) return _primary;
      try {
        return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
      } catch (_) {
        return _primary;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _groupChip(
            label: 'همه گروه‌ها',
            color: Colors.grey.shade600,
            selected: _selectedGroupId == null,
            onTap: () => setState(() => _selectedGroupId = null),
          ),
          ..._groups.map((g) {
            final color = parseColor(g['color']);
            return _groupChip(
              label: g['name'] ?? '',
              color: color,
              selected: _selectedGroupId == g['id'],
              onTap: () => setState(() => _selectedGroupId = g['id']),
            );
          }),
        ],
      ),
    );
  }

  Widget _groupChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['همه', 'امروز', 'عقب افتاده', 'انجام شده'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? _primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? _primary : Colors.grey.shade500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskSliver() {
    final tasks = _filteredTasks;
    if (tasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0EEFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inbox_outlined,
                    size: 36,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'کاری یافت نشد',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _buildTaskCard(tasks[i]),
        childCount: tasks.length,
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final status = task['status'] as String? ?? '';
    final priority = task['priority'] as String? ?? '';
    final isDone = status == 'completed' || status == 'approved';
    final statusLbl = TaskLabels.statusLabel(status);
    final statusClr = TaskLabels.statusColor(status);

    return GestureDetector(
      onTap: () async {
        final result = await Get.to(
          () => TaskDetailPage(
            taskId: task['id'],
            currentUserId: widget.user['id'],
          ),
        );
        if (result == true) _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF0EFF7) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDone
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _primary : Colors.transparent,
                border: isDone
                    ? null
                    : Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDone ? Colors.grey.shade400 : _ink,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusClr,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLbl,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if ((task['group_name'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.folder_outlined,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            task['group_name'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            TaskLabels.priorityColor(priority),
          ],
        ),
      ),
    );
  }
}
