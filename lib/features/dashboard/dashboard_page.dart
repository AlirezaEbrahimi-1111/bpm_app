import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/persian_number.dart';
import '../tasks/task_detail_page.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/widgets/task_badges.dart';
import '../tasks/widgets/task_quick_actions_sheet.dart';
import '../shell/widgets/nav_bar_metrics.dart';
import 'widgets/plan_modals.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;
  // 🔧 برای دکمه‌ی «مشاهده همه کارها» در مودال‌های برنامه‌ی فردا/هفته/ماه
  // — پوسته‌ی اصلی این را برای جابه‌جایی به تبِ «کارها» پاس می‌دهد
  final VoidCallback? onSeeAllTasks;
  const DashboardPage({super.key, required this.user, this.onSeeAllTasks});
  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  // 🔧 null یعنی هیچ‌کدام از فیلترهای همه/امروز/عقب‌افتاده فعال نیست
  // (چون یک روزِ خاص از نوارِ تقویم انتخاب شده)
  String? _filter = 'همه';

  // 🔧 روزِ انتخاب‌شده از نوارِ تقویم — null یعنی هیچ روزی به‌طورِ خاص
  // انتخاب نشده و فیلترِ همه/امروز/عقب‌افتاده حاکم است
  DateTime? _selectedDay;
  // 🔧 طبق درخواست: نوارِ تقویم حالا شبیهِ یک چرخِ تاریخ است — همیشه
  // دقیقاً ۵ روز دیده می‌شود (۲ قبل + وسط + ۲ بعد)، با اسکرول روزِ
  // وسط عوض می‌شود و بزرگ/پررنگ می‌ماند؛ PageViewِ با viewportFraction
  // ۰.۲ دقیقاً همین جلوه را می‌سازد (صفحه‌ی جاری همیشه در وسطِ‌ویوپورت)
  late final PageController _dayPageController;
  double _dayPageValue = _dayWindowRadius.toDouble();
  static const _dayWindowRadius = 60; // ۶۰ روز قبل تا ۶۰ روز بعد

  // 🔧 آفلاین سبک: وقتی اینترنت نیست، آخرین داده‌ی ذخیره‌شده نمایش داده می‌شود
  bool _isOfflineData = false;

  static const _weekdays = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];
  static const _months = [
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

  @override
  void initState() {
    super.initState();
    _loadData();
    // 🔧 با viewportFraction=۰.۲ (=۱/۵)، صفحه‌ی جاری همیشه خودش در
    // وسطِ ویوپورت می‌نشیند — یعنی «امروز» از همان اول، وسطِ ۵تایی است
    _dayPageController = PageController(
      viewportFraction: 0.2,
      initialPage: _dayWindowRadius,
    );
    _dayPageController.addListener(_onDayPageScroll);
  }

  @override
  void dispose() {
    _dayPageController.removeListener(_onDayPageScroll);
    _dayPageController.dispose();
    super.dispose();
  }

  void _onDayPageScroll() {
    final page = _dayPageController.page;
    if (page == null) return;
    setState(() => _dayPageValue = page);
  }

  void reload() => _loadData();

  void _goToTasksTab() => widget.onSeeAllTasks?.call();

  // 🔧 طبق درخواست: انتخابِ یک روز از مودالِ هفته/ماه، هم لیستِ کارها
  // را فیلتر می‌کند (قبلاً بود) و هم خودِ چرخِ تقویمِ بالای داشبورد را
  // به همان روز می‌برد (قبلاً فقط لیست تغییر می‌کرد، چرخ ثابت می‌ماند)
  void _selectDay(DateTime day) {
    final base = DateTime.now();
    final baseMidnight = DateTime(base.year, base.month, base.day);
    final dayMidnight = DateTime(day.year, day.month, day.day);
    final offset = dayMidnight.difference(baseMidnight).inDays;
    final index = (_dayWindowRadius + offset).clamp(0, _dayWindowRadius * 2);
    setState(() {
      _selectedDay = dayMidnight;
      _filter = null;
    });
    if (_dayPageController.hasClients) {
      _dayPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.dio.get('/api/tasks/my-tasks.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] != true) {
        throw Exception(data['message']?.toString() ?? 'خطا در دریافت کارها');
      }
      final list = data['data']?['tasks'];
      final tasks = list is List ? List<dynamic>.from(list) : [];
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isOfflineData = false;
          _isLoading = false;
        });
      }
      // 🔧 آفلاین سبک: کش آخرین لیست موفق، فقط برای مشاهده وقتی
      // بعداً اینترنت نبود
      ApiClient.saveOfflineCache('dashboard', {'tasks': tasks});
    } catch (_) {
      final cached = await ApiClient.readOfflineCache('dashboard');
      if (!mounted) return;
      if (cached != null && cached['data'] is Map) {
        final data = cached['data'] as Map;
        setState(() {
          _tasks = data['tasks'] ?? [];
          _isOfflineData = true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── کمکی‌های تاریخ ──────────────────────────────────────────

  int? _daysRemaining(dynamic task) {
    final v = task['days_remaining'];
    if (v == null) return null;
    return v is int ? v : int.tryParse(v.toString());
  }

  bool _isDone(dynamic task) =>
      task['status'] == 'completed' || task['status'] == 'approved';

  DateTime? _dueDateOf(dynamic task) {
    final days = _daysRemaining(task);
    if (days == null) return null;
    final d = DateTime.now().add(Duration(days: days));
    return DateTime(d.year, d.month, d.day);
  }

  // 🔧 بازه‌ی روزهایِ نوارِ تقویمِ اسکرول‌شونده: ۶۰ روز قبل تا ۶۰ روز بعد از امروز
  List<DateTime> _dayWindow() {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    return List.generate(
      _dayWindowRadius * 2 + 1,
      (i) => base.add(Duration(days: i - _dayWindowRadius)),
    );
  }

  int _countThisMonth() {
    final todayJ = Jalali.now();
    return _tasks.where((t) {
      if (_isDone(t)) return false;
      final days = _daysRemaining(t);
      if (days == null) return false;
      final due = Jalali.fromDateTime(DateTime.now().add(Duration(days: days)));
      return due.year == todayJ.year && due.month == todayJ.month;
    }).length;
  }

  int _countThisWeek() {
    final today = DateTime.now();
    final todayJ = Jalali.fromDateTime(today);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: todayJ.weekDay - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _tasks.where((t) {
      if (_isDone(t)) return false;
      final days = _daysRemaining(t);
      if (days == null) return false;
      final due = DateTime.now().add(Duration(days: days));
      final dd = DateTime(due.year, due.month, due.day);
      return !dd.isBefore(weekStart) && !dd.isAfter(weekEnd);
    }).length;
  }

  int _countTomorrow() {
    return _tasks.where((t) {
      if (_isDone(t)) return false;
      return _daysRemaining(t) == 1;
    }).length;
  }

  List<dynamic> get _filteredTasks {
    // 🔧 وقتی روزی از نوارِ تقویم انتخاب شده، اولویت با همان روز است —
    // فیلترهای همه/امروز/عقب‌افتاده در این حالت غیرفعال (خاموش) می‌شوند
    if (_selectedDay != null) {
      final sel = _selectedDay!;
      return _tasks.where((t) {
        final due = _dueDateOf(t);
        return due != null &&
            due.year == sel.year &&
            due.month == sel.month &&
            due.day == sel.day;
      }).toList();
    }
    if (_filter == 'امروز') {
      return _tasks.where((t) => taskIsDueToday(t)).toList();
    }
    if (_filter == 'عقب افتاده') {
      return _tasks.where((t) => taskIsOverdue(t)).toList();
    }
    return List.from(_tasks);
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
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    bottomNavClearance(context),
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: ConnectivityService.instance.isOnline,
                    builder: (context, online, _) {
                      final hasNothingToShow =
                          !online && !_isOfflineData && _tasks.isEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: hasNothingToShow
                            ? [_buildOfflineEmptyState(c)]
                            : [
                                _buildCalendarStrip(c),
                                const SizedBox(height: 24),
                                _buildScheduleCards(c),
                                const SizedBox(height: 24),
                                _buildTaskListHeader(c),
                                const SizedBox(height: 14),
                                ..._buildTaskList(c),
                              ],
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }

  // ── حالتی که هنوز هیچ کشی نداریم و آفلاین هم هستیم ──
  Widget _buildOfflineEmptyState(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.borderSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded, size: 36, color: c.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              'شما آفلاین هستید',
              style: TextStyle(
                color: c.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'هنوز داده‌ای برای نمایش آفلاین ذخیره نشده',
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── نوار تقویم بالای صفحه — طبق عکسِ ارسالی: همیشه ۵ روز دیده
  // می‌شود (۲ قبل + وسط + ۲ بعد)، با اسکرول روزِ وسط عوض/بزرگ می‌شود؛
  // با ضربه یا تسویه‌شدنِ اسکرول روی یک روز، لیستِ کارها بر همان روز
  // فیلتر می‌شود ──
  Widget _buildCalendarStrip(AppColors c) {
    final days = _dayWindow();
    final centerIndex = _dayPageValue.round().clamp(0, days.length - 1);
    final centerJ = Jalali.fromDateTime(days[centerIndex]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          toPersianDigits('${_months[centerJ.month - 1]} ${centerJ.year}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
        // const SizedBox(height: 10),
        SizedBox(
          height: 66,
          child: PageView.builder(
            controller: _dayPageController,
            itemCount: days.length,
            onPageChanged: (page) => setState(() {
              _selectedDay = days[page];
              _filter = null;
            }),
            itemBuilder: (context, i) {
              final d = days[i];
              final j = Jalali.fromDateTime(d);
              final now = DateTime.now();
              final isToday =
                  d.year == now.year &&
                  d.month == now.month &&
                  d.day == now.day;
              // 🔧 فاصله‌ی زنده از مرکزِ ویوپورت (۰ = دقیقاً وسط) — برایِ
              // انیمیشنِ نرمِ بزرگ/کوچک‌شدن حین خودِ اسکرول (نه فقط بعد از تسویه)
              final distance = (i - _dayPageValue).abs().clamp(0.0, 1.0);
              final numberSize = 26 - (26 - 15) * distance;
              final weekdaySize = 12 - (12 - 10) * distance;
              final isCenter = distance < 0.05;
              return GestureDetector(
                onTap: () => _dayPageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      toPersianDigits(j.day),
                      style: TextStyle(
                        fontSize: numberSize,
                        fontWeight: isCenter
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isCenter
                            ? c.textStrong
                            : c.textMuted.withValues(alpha: 0.55),
                      ),
                    ),
                    // const SizedBox(height: 1),
                    Text(
                      _weekdays[j.weekDay - 1],
                      style: TextStyle(
                        fontSize: weekdaySize,
                        fontWeight: isCenter
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isCenter
                            ? (isToday ? c.primary : c.textStrong)
                            : c.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── ردیف «برنامه کاری» (این ماه/این هفته/فردا) ──
  Widget _buildScheduleCards(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'برنامه کاری',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: c.textStrong,
          ),
        ),
        const SizedBox(height: 12),
        // 🔧 اصلاح: جای «این ماه» و «فردا» عوض شد
        // 🔧 طبق درخواست: این ۳ کارت حالا قابل‌کلیک‌اند و مودالِ
        // برنامه‌ی مربوطه را باز می‌کنند
        Row(
          children: [
            Expanded(
              child: _scheduleCard(
                c: c,
                count: _countTomorrow(),
                label: 'فردا',
                color: c.primary,
                onTap: () => showTomorrowPlanModal(
                  context,
                  tasks: _tasks,
                  onSeeAll: _goToTasksTab,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _scheduleCard(
                c: c,
                count: _countThisWeek(),
                label: 'این هفته',
                color: const Color(0xFFF59E0B),
                onTap: () => showWeekPlanModal(
                  context,
                  tasks: _tasks,
                  onSeeAll: _goToTasksTab,
                  onDaySelected: _selectDay,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _scheduleCard(
                c: c,
                count: _countThisMonth(),
                label: 'این ماه',
                color: const Color(0xFF3B82F6),
                onTap: () => showMonthPlanModal(
                  context,
                  tasks: _tasks,
                  onSeeAll: _goToTasksTab,
                  onDaySelected: _selectDay,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scheduleCard({
    required AppColors c,
    required int count,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.calendar_month_rounded, color: color, size: 30),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      toPersianDigits(count),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── هدر لیست کار: فیلترها + عنوان «همه کارها» ──
  Widget _buildTaskListHeader(AppColors c) {
    return Row(
      children: [
        Text(
          'همه کارها',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: c.textStrong,
          ),
        ),
        const Spacer(),
        // 🔧 اصلاح طبق درخواست: ترتیب از راست = همه، امروز، عقب‌افتاده
        _filterChip(c, 'همه'),
        const SizedBox(width: 8),
        _filterChip(c, 'امروز'),
        const SizedBox(width: 8),
        _filterChip(c, 'عقب افتاده'),
      ],
    );
  }

  Widget _filterChip(AppColors c, String label) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() {
        _filter = label;
        // 🔧 انتخابِ یک فیلترِ ثابت، انتخابِ روزِ خاص را لغو می‌کند
        // (این دو حالت، همدیگر را نقض می‌کنند)
        _selectedDay = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.transparent : Colors.transparent,
          border: Border.all(
            color: selected ? c.primary : c.borderSoft,
            width: 1.3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? c.primary : c.textMuted,
          ),
        ),
      ),
    );
  }

  // ── لیست کارها ──
  List<Widget> _buildTaskList(AppColors c) {
    final tasks = _filteredTasks;
    if (tasks.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'کاری یافت نشد',
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ),
        ),
      ];
    }
    return tasks.map((t) => _taskRow(c, t)).toList();
  }

  Widget _taskRow(AppColors c, dynamic task) {
    final taskId = task['id'];
    return GestureDetector(
      onTap: () async {
        final result = await Get.to(
          () =>
              TaskDetailPage(taskId: taskId, currentUserId: widget.user['id']),
        );
        if (result == true) _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        // 🔧 طبق درخواست: عنوان + نشان‌ها + سه‌نقطه همه در ردیفِ اول؛
        // موعدِ انجام دقیقاً زیرِ همین ردیف (زیرِ عنوان) می‌آید و با
        // هیچ‌چیزِ دیگری هم‌ردیف نمی‌شود — دقیقاً هم‌راستا با کارتِ
        // صفحه‌ی «کارها»
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    task['title'] ?? '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in badgesForTask(task)) ...[
                      taskBadgeChip(icon: b.$1, label: b.$2, color: b.$3),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: () => showTaskQuickActionsSheet(
                    context,
                    task: task,
                    onChanged: _loadData,
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: c.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            taskDueRow(c, task),
          ],
        ),
      ),
    );
  }
}
