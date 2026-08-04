import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../../core/utils/task_search.dart';
import 'task_detail_page.dart';
import 'widgets/task_card.dart';
import 'widgets/task_list_header.dart';

class MyTasksPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const MyTasksPage({super.key, required this.user});
  @override
  State<MyTasksPage> createState() => MyTasksPageState();
}

class MyTasksPageState extends State<MyTasksPage> {
  List<dynamic> _myTasks = [];
  bool _isLoading = true;
  String? _loadError;
  String _filter = 'همه';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<dynamic> _groups = [];
  int? _selectedGroupId;

  static const _primary = Color(0xFF6D28D9);
  static const _bg = Color(0xFFF7F7FB);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // متد عمومی برای refresh از بیرون (مثلاً بعد از ساخت کار)
  void reload() => _loadData();

  // 🔧 اصلاح سرعت: «کارها» و «گروه‌ها» دو درخواست کاملاً مستقل‌اند —
  // قبلاً پشت‌سرهم (sequential) گرفته می‌شدند (و حتی یک درخواست سوم،
  // stats.php، هم می‌گرفتیم که اصلاً جایی در این صفحه نمایش داده
  // نمی‌شد — کاملاً حذف شد). حالا هم‌زمان (parallel) گرفته می‌شوند تا
  // زمان لود تقریباً برابر با کندترینِ این دو باشد، نه مجموعشان.
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    await Future.wait([_fetchTasks(), _fetchGroups()]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchTasks() async {
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
  }

  Future<void> _fetchGroups() async {
    // فقط برای مدیران — اگر خطا داد مهم نیست (کاربر عادی به گروه‌ها
    // دسترسی ندارد و این طبیعی است)
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
      _groups = [];
    }
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

    // 🔧 اصلاح ۴: جستجو بر اساس شناسه، عنوان یا توضیحات (چندکلمه‌ای)
    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((t) => taskMatchesQuery(t, _searchQuery)).toList();
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
                      sliver: SliverToBoxAdapter(
                        // 🔧 هدر مشترک: عنوان + جستجو + فیلترها
                        // (دقیقاً همان چیزی که در صفحه‌ی کارهای واگذارشده استفاده می‌شود)
                        child: TaskListHeader(
                          title: 'کارهای من',
                          subtitle: _getShamsiDate(),
                          searchController: _searchController,
                          onSearchChanged: (v) =>
                              setState(() => _searchQuery = v),
                          filters: const [
                            'همه',
                            'امروز',
                            'عقب افتاده',
                            'انجام شده',
                          ],
                          selectedFilter: _filter,
                          onFilterChanged: (f) => setState(() => _filter = f),
                        ),
                      ),
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

  Widget _buildTaskSliver() {
    if (_loadError != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تلاش مجدد'),
                  style: TextButton.styleFrom(foregroundColor: _primary),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        (ctx, i) => TaskCard(
          task: tasks[i],
          showAssignee: false,
          onTap: () async {
            final result = await Get.to(
              () => TaskDetailPage(
                taskId: tasks[i]['id'],
                currentUserId: widget.user['id'],
              ),
            );
            if (result == true) _loadData();
          },
        ),
        childCount: tasks.length,
      ),
    );
  }
}
