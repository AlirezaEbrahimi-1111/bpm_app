import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_number.dart';
import '../../tasks/task_detail_page.dart';
import '../../tasks/widgets/task_quick_actions_sheet.dart';

/// سه مودالِ «برنامه‌ی فردا/هفته/ماه» که با ضربه روی کارت‌های آماریِ
/// داشبورد باز می‌شوند — منطقِ فیلتر/تراکم دقیقاً هم‌راستا با نسخه‌ی
/// وب (pmInScope و densCls در pages/dashboard-user.php)، داده هم از
/// همان لیستِ کارهایِ از‌قبل‌بارگذاری‌شده‌ی داشبورد است (بدونِ درخواستِ
/// جدید به سرور).

const _weekdaysFa = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];
const _monthsFa = [
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

bool _isDoneTask(dynamic t) =>
    t['status'] == 'completed' || t['status'] == 'approved';

DateTime? _effectiveDue(dynamic task) {
  final v = task['days_remaining'];
  final days = v is int ? v : int.tryParse(v?.toString() ?? '');
  if (days == null) return null;
  final d = DateTime.now().add(Duration(days: days));
  return DateTime(d.year, d.month, d.day);
}

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

// ── چگالیِ کار: ۰=بدون‌وظیفه، ۱-۵=کم‌کار، ۶-۱۰=متوسط، ۱۱+=پرکار ──
int _densityTier(int n) => n == 0 ? 0 : (n <= 5 ? 1 : (n <= 10 ? 2 : 3));
// 🔧 طبق درخواست: پس‌زمینه‌ی روزِ «بدون وظیفه» همیشه سفیدِ کامل است —
// در هر دو تم، نه فقط روشن (قبلاً با c.surface در تمِ تاریک رنگِ سطحِ
// تیره می‌گرفت)
const _densityBg = [
  Colors.white,
  Color(0xFFECE3FF),
  Color(0xFFCCB4FF),
  Color(0xFF8E57FE),
];
const _densityLabels = ['بدون وظیفه', 'کم‌کار', 'متوسط', 'پرکار'];

Color _densityBgFor(AppColors c, int tier) => _densityBg[tier];
// 🔧 چون پس‌زمینه‌ی تیرِ ۰ همیشه سفید است (در هر دو تم)، متنش هم باید
// همیشه همون خاکستریِ ملایمِ ثابت باشد تا رویِ سفید خوانا بماند — نه
// سفیدِ تمامِ تمِ تاریک (که رویِ پس‌زمینه‌ی سفید نامرئی می‌شد)
Color _densityTextFor(AppColors c, int tier) {
  if (tier == 3) return Colors.white;
  if (tier == 0) return const Color(0xFF64748B);
  return const Color(0xFF3B1D73);
}

Widget _legendRow(AppColors c) {
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 12,
    runSpacing: 6,
    children: List.generate(4, (tier) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _densityBgFor(c, tier),
              shape: BoxShape.circle,
              border: tier == 0 ? Border.all(color: c.borderSoft) : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _densityLabels[tier],
            style: TextStyle(fontSize: 11, color: c.textMuted),
          ),
        ],
      );
    }),
  );
}

void _openTask(BuildContext context, dynamic task) {
  Get.to(() => TaskDetailPage(taskId: task['id']));
}

// ═══════════════════════════════════════════════════
// پوسته‌ی مشترک: هدر (عنوان+آیکن، پیمایش اختیاری، بستن) + بدنه + فوتر
// ═══════════════════════════════════════════════════
void _showPlanModal(
  BuildContext context, {
  required String title,
  required IconData icon,
  Widget? navPill,
  required Widget Function(BuildContext) bodyBuilder,
  required VoidCallback onSeeAll,
}) {
  final c = AppColors.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.85,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textStrong,
                      ),
                    ),
                    const Spacer(),
                    if (navPill != null) ...[
                      navPill,
                      const SizedBox(width: 10),
                    ],
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Flexible(child: bodyBuilder(ctx)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    _legendRow(c),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onSeeAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'مشاهده همه کارها',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
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
  );
}

// ═══════════════════════════════════════════════════
// ۱) برنامه‌ی فردا
// ═══════════════════════════════════════════════════
void showTomorrowPlanModal(
  BuildContext context, {
  required List<dynamic> tasks,
  required VoidCallback onSeeAll,
}) {
  final currentUserId = ApiClient.currentUserId ?? -1;
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final tomorrowDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  final list =
      tasks
          .where(
            (t) => !_isDoneTask(t) && _sameDay(_effectiveDue(t), tomorrowDate),
          )
          .toList()
        ..sort(
          (a, b) => quickActionsFor(
            b,
            currentUserId,
          ).length.compareTo(quickActionsFor(a, currentUserId).length),
        );

  _showPlanModal(
    context,
    title: 'برنامه فردا',
    icon: Icons.calendar_today_outlined,
    onSeeAll: onSeeAll,
    bodyBuilder: (ctx) => _taskListBody(
      ctx,
      list: list,
      emptyText: 'کاری برای فردا وجود ندارد',
      onSeeAll: onSeeAll,
    ),
  );
}

/// لیستِ کارهای یک روز — مشترکِ مودالِ فردا و مودالِ «کارهای یک روزِ ماه»
Widget _taskListBody(
  BuildContext ctx, {
  required List<dynamic> list,
  required String emptyText,
  required VoidCallback onSeeAll,
}) {
  final c = AppColors.of(ctx);
  if (list.isEmpty) return _emptyState(c, emptyText);
  return ListView.separated(
    shrinkWrap: true,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    itemCount: list.length,
    separatorBuilder: (_, _) => Divider(height: 1, color: c.borderSoft),
    itemBuilder: (_, i) {
      final t = list[i];
      return InkWell(
        onTap: () => _openTask(ctx, t),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t['title'] ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.textStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showTaskQuickActionsSheet(
                  ctx,
                  task: t,
                  onChanged: onSeeAll,
                ),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: c.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// مودالِ کارهای یک روزِ مشخص (با لمسِ طولانیِ یک سلول در مودالِ ماه)
void _showDayTasksModal(
  BuildContext context, {
  required DateTime day,
  required List<dynamic> tasks,
  required VoidCallback onSeeAll,
}) {
  final currentUserId = ApiClient.currentUserId ?? -1;
  final list =
      tasks
          .where((t) => !_isDoneTask(t) && _sameDay(_effectiveDue(t), day))
          .toList()
        ..sort(
          (a, b) => quickActionsFor(
            b,
            currentUserId,
          ).length.compareTo(quickActionsFor(a, currentUserId).length),
        );
  final j = Jalali.fromDateTime(day);
  _showPlanModal(
    context,
    title: toPersianDigits('کارهای ${j.day} ${_monthsFa[j.month - 1]}'),
    icon: Icons.event_note_rounded,
    onSeeAll: onSeeAll,
    bodyBuilder: (ctx) => _taskListBody(
      ctx,
      list: list,
      emptyText: 'کاری برای این روز وجود ندارد',
      onSeeAll: onSeeAll,
    ),
  );
}

Widget _emptyState(AppColors c, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 36),
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 36, color: c.textMuted),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(color: c.textMuted, fontSize: 13)),
      ],
    ),
  ),
);

// ═══════════════════════════════════════════════════
// ۲) برنامه‌ی هفتگی
// ═══════════════════════════════════════════════════
void showWeekPlanModal(
  BuildContext context, {
  required List<dynamic> tasks,
  required VoidCallback onSeeAll,
  required void Function(DateTime day) onDaySelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WeekPlanSheet(
      tasks: tasks,
      onSeeAll: onSeeAll,
      onDaySelected: onDaySelected,
    ),
  );
}

class _WeekPlanSheet extends StatefulWidget {
  final List<dynamic> tasks;
  final VoidCallback onSeeAll;
  final void Function(DateTime day) onDaySelected;
  const _WeekPlanSheet({
    required this.tasks,
    required this.onSeeAll,
    required this.onDaySelected,
  });

  @override
  State<_WeekPlanSheet> createState() => _WeekPlanSheetState();
}

class _WeekPlanSheetState extends State<_WeekPlanSheet> {
  int _offset = 0;

  DateTime _weekStart(int offset) {
    final today = DateTime.now();
    final todayJ = Jalali.fromDateTime(today);
    final base = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: todayJ.weekDay - 1));
    return base.add(Duration(days: offset * 7));
  }

  String get _label {
    if (_offset == 0) return 'این هفته';
    if (_offset == -1) return 'هفته قبل';
    if (_offset == 1) return 'هفته بعد';
    return '${toPersianDigits(_offset.abs())} هفته ${_offset < 0 ? 'قبل' : 'بعد'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final start = _weekStart(_offset);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    // 🔧 طبق درخواست: آیکنِ مناسب‌تر — این مودال یک ردیفِ
                    // ۷ستونیِ روزها را نشان می‌دهد، نه یک برگه‌ی تقویم
                    Icon(Icons.view_week_rounded, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    Text(
                      'برنامه هفتگی',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textStrong,
                      ),
                    ),
                    const Spacer(),
                    _weekNav(c),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(6, (i) {
                      final day = start.add(Duration(days: i));
                      final j = Jalali.fromDateTime(day);
                      final monthName = _monthsFa[j.month - 1];
                      final shortMonth = monthName.length > 4
                          ? monthName.substring(0, 4)
                          : monthName;
                      final dayTasks = widget.tasks
                          .where(
                            (t) =>
                                !_isDoneTask(t) &&
                                _sameDay(_effectiveDue(t), day),
                          )
                          .toList();
                      final tier = _densityTier(dayTasks.length);
                      final isToday =
                          day.year == todayDate.year &&
                          day.month == todayDate.month &&
                          day.day == todayDate.day;
                      return Expanded(
                        // 🔧 طبق درخواست: ضربه روی خودِ ستونِ روز هم (نه
                        // فقط تک‌تکِ کارها) همان روز را روی داشبورد انتخاب
                        // می‌کند و مودال را می‌بندد — چیپ‌های کار خودشان
                        // GestureDetectorِ جدا دارند و اولویت می‌گیرند
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onDaySelected(day);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            constraints: const BoxConstraints(minHeight: 140),
                            decoration: BoxDecoration(
                              color: _densityBgFor(c, tier),
                              borderRadius: BorderRadius.circular(12),
                              border: isToday
                                  ? Border.all(color: c.primary, width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              // 🔧 رفعِ باگِ «مودالِ هفته چیزی نمایش نمی‌دهد»:
                              // این ستون داخلِ یک SingleChildScrollViewِ عمودی
                              // (ارتفاعِ نامحدود) است — با mainAxisSize
                              // پیش‌فرض (max) روی محدودیتِ نامحدود کرش
                              // می‌کرد؛ min یعنی فقط به‌اندازه‌ی محتوا بلند شود
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _weekdaysFa[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _densityTextFor(c, tier),
                                  ),
                                ),
                                Text(
                                  toPersianDigits('${j.day} $shortMonth'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _densityTextFor(
                                      c,
                                      tier,
                                    ).withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ...dayTasks
                                    .take(6)
                                    .map(
                                      (t) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => _openTask(context, t),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: c.primary.withValues(
                                                alpha: tier == 3 ? 0.35 : 0.16,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              t['title'] ?? '',
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: tier == 3
                                                    ? Colors.white
                                                    : _densityTextFor(c, tier),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                if (dayTasks.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      '—',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _densityTextFor(
                                          c,
                                          tier,
                                        ).withValues(alpha: 0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    _legendRow(c),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSeeAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'مشاهده همه کارها',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
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
    );
  }

  Widget _weekNav(AppColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            color: c.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => setState(() => _offset -= 1),
          ),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.textStrong,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            color: c.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => setState(() => _offset += 1),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ۳) برنامه‌ی ماهانه
// ═══════════════════════════════════════════════════
void showMonthPlanModal(
  BuildContext context, {
  required List<dynamic> tasks,
  required void Function(DateTime day) onDaySelected,
  required VoidCallback onSeeAll,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MonthPlanSheet(
      tasks: tasks,
      onDaySelected: onDaySelected,
      onSeeAll: onSeeAll,
    ),
  );
}

class _MonthPlanSheet extends StatefulWidget {
  final List<dynamic> tasks;
  final void Function(DateTime day) onDaySelected;
  final VoidCallback onSeeAll;
  const _MonthPlanSheet({
    required this.tasks,
    required this.onDaySelected,
    required this.onSeeAll,
  });

  @override
  State<_MonthPlanSheet> createState() => _MonthPlanSheetState();
}

class _MonthPlanSheetState extends State<_MonthPlanSheet> {
  int _offset = 0;

  Jalali _monthStart(int offset) {
    final now = Jalali.now();
    var y = now.year;
    var m = now.month + offset;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    return Jalali(y, m, 1);
  }

  String _label(Jalali monthStart) => _offset == 0
      ? 'این ماه'
      : '${_monthsFa[monthStart.month - 1]} ${toPersianDigits(monthStart.year)}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final monthStart = _monthStart(_offset);
    final daysCount = monthStart.monthLength;
    // شنبه=۰ برای چیدمانِ گرید
    final firstWeekday = monthStart.weekDay - 1;
    final today = Jalali.now();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: c.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'برنامه این ماه',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textStrong,
                      ),
                    ),
                    const Spacer(),
                    _monthNav(c, monthStart),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: _weekdaysFa.reversed
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: c.textMuted,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 5,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: firstWeekday + daysCount,
                    itemBuilder: (ctx, index) {
                      if (index < firstWeekday) return const SizedBox();
                      final dayNum = index - firstWeekday + 1;
                      final jDate = Jalali(
                        monthStart.year,
                        monthStart.month,
                        dayNum,
                      );
                      final gDate = jDate.toDateTime();
                      final gDay = DateTime(gDate.year, gDate.month, gDate.day);
                      final dayTasks = widget.tasks
                          .where(
                            (t) =>
                                !_isDoneTask(t) &&
                                _sameDay(_effectiveDue(t), gDay),
                          )
                          .toList();
                      final tier = _densityTier(dayTasks.length);
                      final isToday =
                          jDate.year == today.year &&
                          jDate.month == today.month &&
                          jDate.day == today.day;
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDaySelected(gDay);
                        },
                        onLongPress: () => _showDayTasksModal(
                          context,
                          day: gDay,
                          tasks: widget.tasks,
                          onSeeAll: () {
                            Navigator.of(context).pop();
                            widget.onSeeAll();
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _densityBgFor(c, tier),
                            borderRadius: BorderRadius.circular(10),
                            border: isToday
                                ? Border.all(color: c.primary, width: 1.5)
                                : Border.all(
                                    color: c.borderSoft,
                                    width: tier == 0 ? 1 : 0,
                                  ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                toPersianDigits(dayNum),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _densityTextFor(c, tier),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _densityLabels[tier],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: _densityTextFor(
                                    c,
                                    tier,
                                  ).withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    _legendRow(c),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSeeAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'مشاهده همه کارها',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
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
    );
  }

  Widget _monthNav(AppColors c, Jalali monthStart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            color: c.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => setState(() => _offset -= 1),
          ),
          Text(
            _label(monthStart),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.textStrong,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            color: c.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => setState(() => _offset += 1),
          ),
        ],
      ),
    );
  }
}
