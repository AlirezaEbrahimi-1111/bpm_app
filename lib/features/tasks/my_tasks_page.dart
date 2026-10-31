import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../../core/utils/task_search.dart';
import '../../core/utils/task_preload.dart';
import '../../core/utils/task_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/task_status_filters.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/plan/plan_access.dart';
import '../../core/plan/org_permissions.dart';
import '../subscription/plan_gate.dart';
import 'task_detail_page.dart';
import 'widgets/task_group_management_sheet.dart';
import 'widgets/task_badges.dart';
import 'widgets/task_list_card.dart';
import '../shell/widgets/nav_bar_metrics.dart';

/// صفحه‌ی «کارها» (قبلاً «کارهای من») — طبق طرح ارسالی (روشن + تاریک).
/// بخشِ منوی بالا/ناوبریِ پایینِ خودِ طرح نادیده گرفته شده (همان چیزی
/// که در پوسته‌ی اصلی اپ از قبل هست، دست‌نخورده می‌ماند).
class MyTasksPage extends StatefulWidget {
  final Map<String, dynamic> user;

  /// حالتِ «مدیریت کارها»: همان صفحه با همان امکانات (جستجو، فیلتر، گروه،
  /// آمار)، ولی داده از /api/tasks/all-tasks.php (همان APIِ صفحه‌ی مدیریت
  /// کارهای وب) و بدونِ نوارِ ناوبریِ پایین (صفحه‌ی push‌شده از دراور)
  final bool manageMode;
  // 🔧 طبق درخواست: «کارهای واگذارشده» هم همین صفحه است (مثلِ «مدیریت
  // کارها») با همان فیلترها — فقط منبعِ داده delegated-tasks.php است
  final bool delegatedMode;
  const MyTasksPage({
    super.key,
    required this.user,
    this.manageMode = false,
    this.delegatedMode = false,
  });
  @override
  State<MyTasksPage> createState() => MyTasksPageState();
}

class MyTasksPageState extends State<MyTasksPage> {
  List<dynamic> _myTasks = [];
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<dynamic> _groups = [];
  int? _selectedGroupId;
  // 🔧 فهرستِ کاملِ پرسنل — برایِ فیلترِ «همه پرسنل» (طبقِ قانونِ
  // نمایشِ نسخه‌ی وب: AssigneePicker از /api/users/list.php پر می‌شود،
  // نه از نام‌هایِ موجود در لیستِ فعلاً بارگذاری‌شده)
  List<dynamic> _users = [];

  // 🔧 فیلترهای شیتِ «فیلتر» (طبق عکس دوم) — null یعنی «همه»
  // 🔧 اصلاح: طبقِ نسخه‌ی وب، این فیلتر بر اساسِ مسئولِ کار (assignee)
  // است، نه ایجادکننده — مقدارش شناسه‌ی کاربر است
  String? _filterAssigneeId;
  String? _filterStatus;
  String? _filterPriority;
  String? _filterTaskType;
  // فقط در delegatedMode — مثلِ چک‌باکسِ «ارجاعات سابق» نسخه‌ی وب
  // (delegated-tasks.php?filter=previous_delegations)
  bool _includePrevious = false;

  // صفحه‌ی جدا (push‌شده) — نه تبِ پوسته‌ی اصلی
  bool get _isStandalone => widget.manageMode || widget.delegatedMode;
  String get _cacheKey => widget.delegatedMode
      ? 'delegated_tasks'
      : (widget.manageMode ? 'manage_tasks' : 'my_tasks');

  // 🔧 فیلترِ سریع با ضربه روی کارت‌های آماری — یکی از:
  // 'done' | 'overdue' | 'in_progress' | 'pending_approval' | null
  String? _quickFilter;

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    await Future.wait([_fetchTasks(), _fetchGroups(), _fetchUsers()]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchTasks() async {
    try {
      final tasksRes = await ApiClient.dio.get(
        widget.delegatedMode
            ? '/api/tasks/delegated-tasks.php'
            : widget.manageMode
            ? '/api/tasks/all-tasks.php'
            : '/api/tasks/my-tasks.php',
        queryParameters: (widget.delegatedMode && _includePrevious)
            ? {'filter': 'previous_delegations'}
            : null,
      );
      final data = ApiClient.parseResponse(tasksRes.data);
      if (data['success'] == true) {
        // all-tasks.php لیست را مستقیم زیرِ «tasks» می‌دهد، my-tasks.php زیرِ data.tasks
        final list = _isStandalone ? data['tasks'] : data['data']?['tasks'];
        _myTasks = list is List ? List<dynamic>.from(list) : [];
        // 🔧 آفلاین سبک: کش آخرین لیست موفق، فقط برای مشاهده وقتی
        // بعداً اینترنت نبود
        ApiClient.saveOfflineCache(_cacheKey, _myTasks);
        // 🔧 آفلاین سبک: جزئیات کامل هر کار هم در پس‌زمینه کش شود — بدون
        // await، تا لود لیست منتظرش نماند
        if (!widget.manageMode) preloadTaskDetails(_myTasks);
      } else {
        _loadError = data['message']?.toString() ?? 'خطا در دریافت کارها';
      }
    } catch (e) {
      final cached = await ApiClient.readOfflineCache(_cacheKey);
      if (cached != null && cached['data'] is List) {
        _myTasks = List<dynamic>.from(cached['data']);
      } else {
        // 🔧 اصلاح: اگر واقعاً پاسخی از سرور نرسیده (نه خطای اپلیکیشنی)
        // و هنوز کشی هم نداریم، پیام روشن‌تری از «خطای عمومی» نشان بده
        _loadError = (e is DioException && e.response == null)
            ? 'اینترنت ندارید و هنوز داده‌ای برای نمایش آفلاین ذخیره نشده'
            : 'خطا در اتصال به سرور';
      }
    }
  }

  Future<void> _fetchGroups() async {
    // 🔧 رفعِ باگ: list-all.php مخصوصِ صفحه‌ی مدیریتِ گروه‌هاست و نیازِ
    // مجوزِ manage_task_groups دارد؛ فیلترِ گروه در «کارها» یک قابلیتِ
    // مدیریتی نیست — همه‌ی کاربران باید بتوانند بر اساسِ گروه‌های
    // شخصیِ خودشان + گروه‌های سازمانی فیلتر کنند. list.php دقیقاً همین
    // را بدونِ نیازِ مجوز برمی‌گرداند.
    try {
      final groupsRes = await ApiClient.dio.get('/api/task-groups/list.php');
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

  Future<void> _fetchUsers() async {
    try {
      final res = await ApiClient.dio.get('/api/users/list.php');
      if (res.data['success'] == true) {
        _users = res.data['users'] as List? ?? [];
      }
    } catch (_) {
      _users = [];
    }
  }

  bool _isDone(dynamic t) =>
      t['status'] == 'completed' ||
      t['status'] == 'approved' ||
      t['status'] == 'period_done';
  // 🔧 مطابقِ وب (TF.isOverdue)، نه صرفاً days_remaining < 0
  bool _isOverdue(dynamic t) => taskIsOverdue(t);

  // 🔧 طبق درخواست: کارهایِ بسته‌شده (تکمیل/تأیید/دوره‌انجام‌شده + لغوشده
  // «rejected» + متوقف‌شده «stopped») نباید پیش‌فرض در لیست باشند — قبلاً
  // فقط ته‌لیست می‌رفتند (مرتب‌سازیِ _isDone)، ولی هنوز نمایش داده می‌شدند
  bool _isClosed(dynamic t) =>
      _isDone(t) || t['status'] == 'rejected' || t['status'] == 'stopped';

  List<dynamic> get _filteredTasks {
    List<dynamic> list = List.from(_myTasks);

    // کارهایِ بسته‌شده فقط وقتی دیده می‌شوند که کاربر صریحاً بخواهدشان:
    // فیلترِ سریعِ «تکمیل‌شده» یا انتخابِ همان وضعیت از فیلترِ پیشرفته
    // 🔧 فیلترِ وضعیت عیناً مثلِ وب (TF.matchesStatusFilter)
    // وقتی وضعیتی صریحاً انتخاب شده، مثلِ وب خودِ همان فیلتر روی کلِ فهرست
    // اعمال می‌شود (پنهان‌سازیِ پیش‌فرضِ کارهایِ بسته فقط برایِ حالتِ «همه»)
    final wantsClosed = _quickFilter == 'done' || _filterStatus != null;
    if (!wantsClosed) {
      list = list.where((t) => !_isClosed(t)).toList();
    }

    if (_quickFilter == 'done') {
      list = list.where(_isDone).toList();
    } else if (_quickFilter == 'overdue') {
      list = list.where(_isOverdue).toList();
    } else if (_quickFilter == 'in_progress') {
      list = list.where((t) => t['status'] == 'in_progress').toList();
    } else if (_quickFilter == 'pending_approval') {
      list = list.where((t) => t['status'] == 'pending_approval').toList();
    }

    if (_filterAssigneeId != null) {
      list = list
          .where((t) => t['assignee_id']?.toString() == _filterAssigneeId)
          .toList();
    }
    if (_filterStatus != null) {
      final uid = ApiClient.currentUserId;
      list = list
          .where((t) => taskMatchesStatusFilter(t, _filterStatus, uid))
          .toList();
    }
    if (_filterPriority != null) {
      list = list.where((t) => t['priority'] == _filterPriority).toList();
    }
    if (_filterTaskType != null) {
      list = list.where((t) => t['task_type'] == _filterTaskType).toList();
    }

    if (_selectedGroupId != null) {
      list = list
          .where((t) => t['group_id'].toString() == _selectedGroupId.toString())
          .toList();
    }

    // 🔧 جستجو بر اساس شناسه، عنوان یا توضیحات (چندکلمه‌ای)
    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((t) => taskMatchesQuery(t, _searchQuery)).toList();
    }

    list.sort((a, b) {
      final aDone = _isDone(a);
      final bDone = _isDone(b);
      if (aDone && !bDone) return 1;
      if (!aDone && bDone) return -1;
      final aDays = (a['days_remaining'] ?? 9999) as int;
      final bDays = (b['days_remaining'] ?? 9999) as int;
      return aDays.compareTo(bDays);
    });

    // 🔧 طبق درخواست: موقعِ جستجو، نزدیک‌ترین نتیجه اول
    if (_searchQuery.trim().isNotEmpty) {
      return rankTasksBySearch(list, _searchQuery);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      color: c.bgPage,
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: c.primary,
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildHeader(c)),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildStatCards(c)),
                    ),
                    if (_groups.isNotEmpty || true)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        sliver: SliverToBoxAdapter(child: _buildGroupFilter(c)),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        _isStandalone
                            ? 24 + MediaQuery.of(context).padding.bottom
                            : bottomNavClearance(context),
                      ),
                      sliver: _buildTaskSliver(c),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 🔧 اصلاح: عنوان «کارها» طبق درخواست از بالای صفحه برداشته شد —
  // هدر حالا مستقیم با جستجو شروع می‌شود
  Widget _buildHeader(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(color: c.textStrong, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.delegatedMode
                ? 'جستجو در کارهای واگذارشده...'
                : widget.manageMode
                ? 'جستجو در همه کارها...'
                : 'جستجو در کارها...',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: c.textMuted,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: c.textMuted,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showFilterSheet(c),
            icon: Icon(
              _hasActiveFieldFilters
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              size: 18,
              color: c.primary,
            ),
            label: Text(
              _hasActiveFieldFilters ? 'فیلتر (فعال)' : 'فیلتر',
              style: TextStyle(
                color: c.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        // 🔧 طبق درخواست: دکمه‌ی «افزودن وظیفه» از «مدیریت کارها» هم حذف شد —
        // آن صفحه حالا دکمه‌ی شناورِ «+» نوارِ پایین (AppCreateTaskFab) را دارد
      ],
    );
  }

  bool get _hasActiveFieldFilters =>
      _filterAssigneeId != null ||
      _filterStatus != null ||
      _filterPriority != null ||
      _filterTaskType != null ||
      _includePrevious;

  // ── کارت‌های آماری (تکمیل‌شده/معوق/در جریان/نیاز به تأیید) ──
  Widget _buildStatCards(AppColors c) {
    final done = _myTasks.where(_isDone).length;
    final overdue = _myTasks.where(_isOverdue).length;
    final inProgress = _myTasks
        .where((t) => t['status'] == 'in_progress')
        .length;
    final pending = _myTasks
        .where((t) => t['status'] == 'pending_approval')
        .length;

    return Row(
      children: [
        _statCard(
          c: c,
          icon: Icons.check_rounded,
          color: const Color(0xFF22C55E),
          count: done,
          label: 'تکمیل‌شده',
          filterKey: 'done',
        ),
        const SizedBox(width: 8),
        _statCard(
          c: c,
          icon: Icons.access_time_rounded,
          color: c.danger,
          count: overdue,
          label: 'معوق',
          filterKey: 'overdue',
        ),
        const SizedBox(width: 8),
        _statCard(
          c: c,
          icon: Icons.autorenew_rounded,
          color: const Color(0xFF3B82F6),
          count: inProgress,
          label: 'در جریان',
          filterKey: 'in_progress',
        ),
        const SizedBox(width: 8),
        _statCard(
          c: c,
          icon: Icons.shield_outlined,
          color: c.primary,
          count: pending,
          label: 'نیاز به تأیید',
          filterKey: 'pending_approval',
        ),
      ],
    );
  }

  Widget _statCard({
    required AppColors c,
    required IconData icon,
    required Color color,
    required int count,
    required String label,
    required String filterKey,
  }) {
    final selected = _quickFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _quickFilter = selected ? null : filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : c.borderSoft,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(height: 8),
              Text(
                toPersianDigits(count.toString()),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: c.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: c.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupFilter(AppColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _groupChip(
            c,
            label: 'همه گروه‌ها',
            // 🔧 رفعِ باگ: c.textMuted در تمِ تاریک سفیدِ کامل است — چون
            // این چیپ وقتی انتخاب شده پس‌زمینه‌اش رو همین رنگ پر می‌کنه و
            // متن/نقطه‌اش هم سفیدِ هاردکده، متن رویِ پس‌زمینه‌ی سفید کاملاً
            // محو می‌شد. یک خاکستریِ ثابت (مستقل از تم) جایگزین شد
            color: const Color(0xFF64748B),
            selected: _selectedGroupId == null,
            onTap: () => setState(() => _selectedGroupId = null),
          ),
          ..._groups.map((g) {
            final color = _parseGroupColor(c, g['color']);
            return _groupChip(
              c,
              label: g['name'] ?? '',
              color: color,
              selected: _selectedGroupId == g['id'],
              onTap: () => setState(() => _selectedGroupId = g['id']),
            );
          }),
          // 🔧 این آیکون دقیقاً همان شیتِ مدیریتیِ کاملِ گروه‌هاست (مثلِ
          // منوی کناری) — پس همان دو محورِ نقش+پلن را دارد: اگر نقش اجازه
          // ندهد، آیکون کاملاً مخفی می‌شود؛ اگر پلن قفل کند، کم‌رنگ+قفل‌دار می‌ماند
          if (hasOrgPermission(
            ApiClient.currentUser?['role']?.toString(),
            OrgPermission.manageTaskGroups,
          ))
            PlanGate(
              feature: PlanFeature.managementGroups,
              label: 'مدیریت گروه‌ها',
              child: GestureDetector(
                onTap: () => showTaskGroupManagementSheet(
                  context,
                  onChanged: _fetchGroups,
                ),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 16,
                    color: c.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _parseGroupColor(AppColors c, String? hex) {
    if (hex == null || hex.isEmpty) return c.primary;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return c.primary;
    }
  }

  Widget _groupChip(
    AppColors c, {
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
          borderRadius: BorderRadius.circular(12),
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

  Widget _buildTaskSliver(AppColors c) {
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
                    color: c.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: c.danger,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('تلاش مجدد'),
                  style: TextButton.styleFrom(foregroundColor: c.primary),
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
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inbox_outlined, size: 36, color: c.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  'کاری یافت نشد',
                  style: TextStyle(color: c.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _taskCard(c, tasks[i]),
        childCount: tasks.length,
      ),
    );
  }

  // ── کارتِ هر کار — عنوان/تاریخ سمتِ راست، سه‌نقطه+نشان‌ها سمتِ چپ ──
  Widget _taskCard(AppColors c, dynamic task) {
    return TaskListCard(
      task: task,
      onChanged: _loadData,
      onTap: () async {
        final result = await Get.to(
          () => TaskDetailPage(
            taskId: task['id'],
            currentUserId: widget.user['id'],
          ),
        );
        if (result == true) _loadData();
      },
    );
  }

  String _userLabel(dynamic u) {
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
  }

  void _showFilterSheet(AppColors c) {
    String? assigneeId = _filterAssigneeId;
    String? status = _filterStatus;
    String? priority = _filterPriority;
    String? taskType = _filterTaskType;
    bool includePrevious = _includePrevious;

    // 🔧 اصلاح: طبقِ قانونِ نمایشِ نسخه‌ی وب (AssigneePicker از
    // /api/users/list.php)، نه فقط نام‌هایِ موجود در لیستِ فعلاً
    // بارگذاری‌شده
    final personnelIds = _users.map((u) => u['id'].toString()).toList();
    String personnelLabel(String id) {
      final u = _users.firstWhere(
        (u) => u['id'].toString() == id,
        orElse: () => null,
      );
      return u == null ? id : _userLabel(u);
    }

    // 🔧 طبق درخواست: همان گزینه‌هایِ گروه‌بندی‌شده‌ی وب (STATUS_FILTERS)
    final statuses = taskStatusFilterKeys;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (ctx2, scrollController) => StatefulBuilder(
              builder: (ctx2, setSheetState) => Container(
                decoration: BoxDecoration(
                  color: c.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
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
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          _filterRow(
                            c: c,
                            icon: Icons.person_outline_rounded,
                            label: assigneeId != null
                                ? personnelLabel(assigneeId!)
                                : 'همه پرسنل',
                            active: assigneeId != null,
                            onTap: () async {
                              final picked = await _pickOption(
                                c,
                                title: 'انتخاب پرسنل',
                                options: personnelIds,
                                current: assigneeId,
                                labelBuilder: personnelLabel,
                              );
                              if (picked != _sentinel)
                                setSheetState(() => assigneeId = picked);
                            },
                          ),
                          _filterRow(
                            c: c,
                            icon: Icons.flag_outlined,
                            label: status != null
                                ? taskStatusFilterLabel(status!)
                                : 'همه وضعیت‌ها',
                            active: status != null,
                            onTap: () async {
                              final picked = await _pickOption(
                                c,
                                title: 'انتخاب وضعیت',
                                options: statuses,
                                current: status,
                                labelBuilder: taskStatusFilterLabel,
                                groupOf: taskStatusFilterGroup,
                              );
                              if (picked != _sentinel)
                                setSheetState(() => status = picked);
                            },
                          ),
                          _filterRow(
                            c: c,
                            icon: Icons.priority_high_rounded,
                            label: priority != null
                                ? TaskLabels.priorityLabel(priority)
                                : 'همه اولویت‌ها',
                            active: priority != null,
                            onTap: () async {
                              final picked = await _pickOption(
                                c,
                                title: 'انتخاب اولویت',
                                options: const ['high', 'medium', 'low'],
                                current: priority,
                                labelBuilder: TaskLabels.priorityLabel,
                              );
                              if (picked != _sentinel)
                                setSheetState(() => priority = picked);
                            },
                          ),
                          _filterRow(
                            c: c,
                            icon: Icons.grid_view_rounded,
                            label: taskType == 'periodic'
                                ? 'مقطعی'
                                : taskType == 'continuous'
                                ? 'دوره‌ای'
                                : 'همه انواع',
                            active: taskType != null,
                            onTap: () async {
                              final picked = await _pickOption(
                                c,
                                title: 'انتخاب نوع کار',
                                options: const ['periodic', 'continuous'],
                                current: taskType,
                                labelBuilder: (v) =>
                                    v == 'periodic' ? 'مقطعی' : 'دوره‌ای',
                              );
                              if (picked != _sentinel)
                                setSheetState(() => taskType = picked);
                            },
                          ),
                          // مثلِ وب: «ارجاعات سابق» — کارهایی که قبلاً واگذار
                          // کرده‌اید و الان دستِ کسِ دیگری است
                          if (widget.delegatedMode)
                            _filterRow(
                              c: c,
                              icon: Icons.history_rounded,
                              label: 'ارجاعات سابق',
                              active: includePrevious,
                              trailing: AppSwitch(
                                value: includePrevious,
                                activeColor: c.primary,
                                onChanged: (v) =>
                                    setSheetState(() => includePrevious = v),
                              ),
                              onTap: () => setSheetState(
                                () => includePrevious = !includePrevious,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 🔧 اصلاح: قبلاً هیچ فاصله‌ای از inset سیستمِ گوشی رعایت
                    // نمی‌شد و دکمه پشتِ دکمه‌های ناوبریِ گوشی می‌رفت —
                    // علاوه‌بر رعایتِ safe-area، طبقِ درخواست ۳۰٪ ارتفاعِ
                    // خودِ دکمه هم اضافه‌تر بالا آورده شده
                    // 🔧 طبق درخواست: «پاک‌سازی» درست زیرِ «اعمال فیلتر» و
                    // هر دو داخلِ یک بلوک با فاصله‌ی safe-area، تا دیگر
                    // پشتِ دکمه‌های گوشی نیفتد
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
                                final reload =
                                    includePrevious != _includePrevious;
                                setState(() {
                                  _filterAssigneeId = assigneeId;
                                  _filterStatus = status;
                                  _filterPriority = priority;
                                  _filterTaskType = taskType;
                                  _includePrevious = includePrevious;
                                });
                                if (reload) _loadData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                              assigneeId = null;
                              status = null;
                              priority = null;
                              taskType = null;
                              includePrevious = false;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 18,
                                bottom: 2,
                              ),
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
        ],
      ),
    );
  }

  static const _sentinel = '__unset__';

  Widget _filterRow({
    required AppColors c,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
            trailing ??
                Icon(Icons.expand_more_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickOption(
    AppColors c, {
    required String title,
    required List<String> options,
    required String? current,
    String Function(String)? labelBuilder,
    String Function(String)? groupOf,
  }) async {
    // 🔧 طبق درخواست: به‌جای دیالوگِ وسطِ صفحه، شیتِ پایین‌رونده
    // (Bottom Sheet) — با سقفِ ارتفاع و لیستِ اسکرول‌شونده، پس با لیستِ
    // بلندِ پرسنل هم دیگر «bottom overflowed» نمی‌دهد.
    // «همه» با رشته‌ی خالی برمی‌گردد (تا از بستنِ بدونِ انتخاب که null
    // است تفکیک شود).
    return showModalBottomSheet<String>(
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
                              style: TextStyle(
                                fontSize: 13.5,
                                color: c.textStrong,
                              ),
                            ),
                            trailing: current == null
                                ? Icon(Icons.check_rounded, color: c.primary)
                                : null,
                            onTap: () => Navigator.of(ctx).pop(''),
                          ),
                          ...() {
                            // 🔧 مثلِ optgroupهایِ وب: عنوانِ گروه (عمومی/کار عادی/روتین)
                            final rows = <Widget>[];
                            String? prev;
                            for (final o in options) {
                              final g = groupOf?.call(o);
                              if (g != null && g.isNotEmpty && g != prev) {
                                rows.add(
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      4,
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: c.primary,
                                      ),
                                    ),
                                  ),
                                );
                                prev = g;
                              }
                              rows.add(
                                ListTile(
                                  title: Text(
                                    labelBuilder?.call(o) ?? o,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: c.textStrong,
                                    ),
                                  ),
                                  trailing: current == o
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: c.primary,
                                        )
                                      : null,
                                  onTap: () => Navigator.of(ctx).pop(o),
                                ),
                              );
                            }
                            return rows;
                          }(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .then((v) => v == null ? _sentinel : (v.isEmpty ? null : v))
        .catchError((_) => _sentinel);
  }
}
