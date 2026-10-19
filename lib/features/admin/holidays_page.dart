import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';
import '../tasks/widgets/persian_date_picker_sheet.dart';
import '../shell/widgets/app_bottom_nav.dart';
import '../../core/navigation/app_nav.dart';

// همان ترتیبِ استانداردِ اپ (شنبه=۱ در Jalali.weekDay)
const _weekdaysFa = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];
// معادلِ PHP date('w') برایِ همین ترتیب — یکشنبه=۰...شنبه=۶
// رنگ‌هایِ تقویمِ تعطیلات — همان rgba(239,68,68) و #8e57fe نسخه‌ی وب
const _red = Color(0xFFEF4444);
const _purple = Color(0xFF8E57FE);
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

/// «روزهای تعطیل» — پورتِ pages/holidays.php برایِ موبایل. همان API وب:
///   GET  /api/holidays/list.php?start_date=&end_date=
///   POST /api/holidays/add.php     {scope, type, title, holiday_date | day_of_week}
///   POST /api/holidays/delete.php  {id}
class HolidaysPage extends StatefulWidget {
  const HolidaysPage({super.key});

  @override
  State<HolidaysPage> createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _holidays = [];

  // ── تقویمِ بالای صفحه (طبق نسخهٔ وب) ──
  late Jalali _calMonth;
  Map<String, dynamic> _calHolidays = {};
  bool _calLoading = false;

  static String _fmtGregorian(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    _calMonth = Jalali(now.year, now.month, 1);
    _load();
    _loadCalendarMonth();
  }

  Future<void> _loadCalendarMonth() async {
    setState(() => _calLoading = true);
    final first = _calMonth;
    final last = Jalali(first.year, first.month, first.monthLength);
    try {
      final res = await ApiClient.dio.get(
        '/api/holidays/list.php',
        queryParameters: {
          'start_date': _fmtGregorian(first.toDateTime()),
          'end_date': _fmtGregorian(last.toDateTime()),
        },
      );
      final data = res.data;
      final map = <String, dynamic>{};
      if (data['success'] == true) {
        for (final h in (data['holidays'] as List? ?? [])) {
          map[(h['holiday_date'] ?? '').toString()] = h;
        }
      }
      if (mounted) {
        setState(() {
          _calHolidays = map;
          _calLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _calLoading = false);
    }
  }

  void _changeCalMonth(int delta) {
    setState(() {
      var y = _calMonth.year;
      var m = _calMonth.month + delta;
      if (m < 1) {
        m = 12;
        y -= 1;
      } else if (m > 12) {
        m = 1;
        y += 1;
      }
      _calMonth = Jalali(y, m, 1);
    });
    _loadCalendarMonth();
  }

  Future<void> _afterChange() async {
    _load();
    _loadCalendarMonth();
  }

  void _onCalDayTap(Jalali day) {
    final gDate = day.toDateTime();
    final dateStr = _fmtGregorian(gDate);
    final isFriday = day.weekDay == 7;
    final holiday = _calHolidays[dateStr];
    if (holiday != null) {
      if (holiday['can_delete'] == true) {
        _confirmDelete(holiday);
      } else {
        AppSnack.info('توجه', 'شما اجازهٔ حذف این تعطیلی را ندارید');
      }
    } else if (isFriday) {
      AppSnack.info('توجه', 'جمعه‌ها پیش‌فرض تعطیل هستند');
    } else {
      _openAddSheet(initialDate: gDate);
    }
  }

  Widget _buildCalendar(AppColors c) {
    final daysInMonth = _calMonth.monthLength;
    final firstWeekDay = _calMonth.weekDay - 1; // شنبه=۰
    final today = Jalali.now();

    return GestureDetector(
      // 🔧 طبق درخواست: فلش‌ها و سوایپ برعکس شدند — به چپ = ماهِ قبل،
      // به راست = ماهِ بعد
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -200) {
          _changeCalMonth(-1);
        } else if (v > 200) {
          _changeCalMonth(1);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderSoft),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Transform.rotate(
                    angle: math.pi,
                    child: Icon(Icons.chevron_right_rounded, color: c.primary),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeCalMonth(-1),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_jalaliMonths[_calMonth.month - 1]} ${toPersianDigits(_calMonth.year.toString())}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: c.textStrong,
                      ),
                    ),
                    if (_calLoading) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: Transform.rotate(
                    angle: math.pi,
                    child: Icon(Icons.chevron_left_rounded, color: c.primary),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeCalMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: _weekdaysFa
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d.substring(0, 1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: d == 'جمعه' ? c.danger : c.textMuted,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            // 🔧 خودِ سلول‌ها (شکل/فاصله‌شان) دقیقاً به حالتِ قبل برگشت.
            // برایِ کم‌کردنِ فاصله‌ی خالیِ زیرِ شماره‌ی روزها تا ردیفِ
            // راهنما، این‌بار به‌جایِ تغییرِ شکلِ سلول‌ها یا paddingِ منفی
            // (که کرش می‌داد)، فقط همان فضایِ خالیِ انتهاییِ گرید — که هیچ
            // محتوایی داخلش نیست — با LayoutBuilder+Align(heightFactor)
            // به‌صورتِ واقعی (نه فقط ظاهری) از فضای لِی‌اوت کم می‌شود
            // 🔧 رفعِ باگ: قبلاً ۱۶ پیکسل از پایینِ گرید بریده می‌شد (برایِ
            // حذفِ فضایِ خالیِ زیرش) — در ماه‌هایی که روزها در ۵ ردیف بودند،
            // همین برش ردیفِ آخر را ناقص می‌کرد. علتِ آن فضایِ خالی، paddingِ
            // خودکارِ GridView (به‌اندازه‌ی نوارِ پایینِ گوشی) بود؛ حالا صفر است
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: firstWeekDay + daysInMonth,
              itemBuilder: (ctx, index) {
                if (index < firstWeekDay) return const SizedBox();
                final day = index - firstWeekDay + 1;
                final jDate = Jalali(_calMonth.year, _calMonth.month, day);
                final dateStr = _fmtGregorian(jDate.toDateTime());
                final holiday = _calHolidays[dateStr];
                final isFriday = jDate.weekDay == 7;
                final isToday =
                    jDate.year == today.year &&
                    jDate.month == today.month &&
                    jDate.day == today.day;
                final dark = Theme.of(context).brightness == Brightness.dark;

                // 🔧 طبق درخواست: رنگ‌ها عیناً مثلِ وب (.calendar-day در custom.css)
                Color bg = dark
                    ? c.surfaceContainerLow
                    : const Color(0xFFF8F9FC);
                Color? border;
                Color textColor = c.textStrong;
                if (holiday != null) {
                  bg = _red.withValues(alpha: dark ? 0.22 : 0.15);
                  border = _red.withValues(alpha: 0.3);
                  textColor = dark
                      ? const Color(0xFFF87171)
                      : const Color(0xFFDC2626);
                } else if (isFriday) {
                  bg = _red.withValues(alpha: dark ? 0.14 : 0.08);
                }
                if (isToday) {
                  border = _purple;
                  if (holiday == null) {
                    bg = dark
                        ? const Color(0xFF744CA4).withValues(alpha: 0.18)
                        : _purple.withValues(alpha: 0.08);
                  }
                }

                return GestureDetector(
                  onTap: () => _onCalDayTap(jDate),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                        color: border ?? Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      toPersianDigits(day.toString()),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
            // 🔧 طبق درخواست: فاصله‌ی بیشتر بینِ آخرین ردیفِ روزها و موارد راهنما
            const SizedBox(height: 16),
            // 🔧 طبق درخواست: راهنما مثلِ وب (.legend-color) — مربعِ گردگوشه
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 8,
              children: [
                _legendDot(
                  c,
                  _red.withValues(alpha: 0.15),
                  'جمعه (تعطیل پیش‌فرض)',
                  border: _red.withValues(alpha: 0.3),
                ),
                _legendDot(c, _red.withValues(alpha: 0.3), 'تعطیل رسمی'),
                _legendDot(
                  c,
                  _purple.withValues(alpha: 0.15),
                  'امروز',
                  border: _purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(AppColors c, Color color, String label, {Color? border}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border != null ? Border.all(color: border, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
      ],
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 1, now.day);
    final end = DateTime(now.year, now.month + 6, now.day);
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      final res = await ApiClient.dio.get(
        '/api/holidays/list.php',
        queryParameters: {'start_date': fmt(start), 'end_date': fmt(end)},
      );
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _holidays = data['holidays'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافت تعطیلات';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ApiClient.errorMessage(e, 'خطا در اتصال به سرور');
        _isLoading = false;
      });
    }
  }

  String _shamsi(String gregorian) {
    try {
      final j = Jalali.fromDateTime(DateTime.parse(gregorian));
      return toPersianDigits(
        '${_weekdaysFa[j.weekDay - 1]} ${j.day} ${_jalaliMonths[j.month - 1]} ${j.year}',
      );
    } catch (_) {
      return gregorian;
    }
  }

  Future<void> _confirmDelete(dynamic h) async {
    final c = AppColors.of(context);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        content: Text(
          '«${h['title'] ?? ''}» حذف شود؟',
          style: TextStyle(color: c.textStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => AppNav.back(result: true),
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.dio.post(
        '/api/holidays/delete.php',
        data: {'id': h['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success(
          '🗑️ حذف شد',
          data['message']?.toString() ?? 'تعطیلی حذف شد',
        );
        _afterChange();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در حذف');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _openAddSheet({DateTime? initialDate}) {
    final c = AppColors.of(context);
    Get.bottomSheet(
      _AddHolidaySheet(c: c, onAdded: _afterChange, initialDate: initialDate),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 🔧 اصلاحیه طبق درخواست: هیچ دکمه‌ی جداگانه‌ای برایِ افزودنِ تعطیلی
    // نیست — همان رفتارِ قبلی کافی‌ست: زدن رویِ یک روزِ خالی در تقویمِ
    // بالایِ صفحه، شیتِ افزودن را با همان تاریخ باز می‌کند (خطِ ۱۳۷)
    return AppShellOverlays(
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: c.textStrong),
          title: Text(
            'روزهای تعطیل',
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
            onPressed: () => AppNav.back(),
          ),
        ),
        // 🔧 طبق درخواست: دکمه‌ی «+» قبلی مخصوصِ افزودنِ تعطیلی بود، نه
        // افزودنِ کار — این‌جا دکمه‌ی عمومیِ افزودنِ کار (هم‌مثلِ بقیه‌ی
        // صفحات) گذاشته شد، و افزودنِ تعطیلی به یک دکمه‌ی بزرگ و ثابت
        // در پایینِ صفحه منتقل شد (پایین‌تر)
        floatingActionButton: const AppCreateTaskFab(),
        floatingActionButtonLocation: const LoweredDockedFabLocation(),
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
                onRefresh: () async {
                  await Future.wait([_load(), _loadCalendarMonth()]);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildCalendar(c)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'لیست تعطیلات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: c.textStrong,
                          ),
                        ),
                      ),
                    ),
                    if (_holidays.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'تعطیلی‌ای در این بازه ثبت نشده',
                              style: TextStyle(color: c.textMuted),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          24 + MediaQuery.of(context).padding.bottom,
                        ),
                        sliver: SliverList.builder(
                          itemCount: _holidays.length,
                          itemBuilder: (ctx, i) {
                            final h = _holidays[i];
                            final isWeekly = h['type'] == 'weekly';
                            final isGlobal = h['is_global'] == true;
                            final canDelete = h['can_delete'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: c.borderSoft),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: c.primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isWeekly
                                          ? Icons.event_repeat_rounded
                                          : Icons.event_busy_rounded,
                                      size: 16,
                                      color: c.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (h['title'] ?? '').toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                            color: c.textStrong,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _shamsi(
                                            (h['holiday_date'] ?? '')
                                                .toString(),
                                          ),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: c.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isGlobal)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c.info.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'سراسری',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: c.info,
                                        ),
                                      ),
                                    ),
                                  if (canDelete)
                                    GestureDetector(
                                      onTap: () => _confirmDelete(h),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: c.danger,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
  }
}

class _AddHolidaySheet extends StatefulWidget {
  final AppColors c;
  final VoidCallback onAdded;
  final DateTime? initialDate;
  const _AddHolidaySheet({
    required this.c,
    required this.onAdded,
    this.initialDate,
  });

  @override
  State<_AddHolidaySheet> createState() => _AddHolidaySheetState();
}

/// 🔧 طبق درخواست: عیناً مثلِ مودالِ «افزودن روز تعطیل» وب — «تاریخ انتخاب
/// شده»، «عنوان تعطیلی»، «توضیحات (اختیاری)» و دکمه‌هایِ انصراف/ذخیره.
/// «تکرارِ هفتگی» حذف شد (در وب غیرفعال است: holidayType همیشه 'date')
class _AddHolidaySheetState extends State<_AddHolidaySheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime? _date;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showCustomPersianDatePicker(
      context,
      initialDate: _date,
      pickOnTap: true,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppSnack.warning('توجه', 'لطفا عنوان تعطیلی را وارد کنید');
      return;
    }
    if (_date == null) {
      AppSnack.warning('توجه', 'لطفا یک تاریخ از روی تقویم انتخاب کنید');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final d = _date!;
      final res = await ApiClient.dio.post(
        '/api/holidays/add.php',
        data: {
          'type': 'date',
          'scope': 'org',
          'title': title,
          'description': _descController.text.trim(),
          'holiday_date':
              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        },
      );
      final res2 = res.data;
      if (res2['success'] == true) {
        AppSnack.success(
          '✅ ثبت شد',
          res2['message']?.toString() ?? 'تعطیلی اضافه شد',
        );
        widget.onAdded();
        if (mounted) Navigator.of(context).pop();
      } else {
        AppSnack.error('خطا', res2['message']?.toString() ?? 'خطا در ثبت');
      }
    } catch (e) {
      AppSnack.error('خطا', ApiClient.errorMessage(e, 'خطا در اتصال به سرور'));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  String get _dateText {
    if (_date == null) return 'انتخاب تاریخ';
    final j = Jalali.fromDateTime(_date!);
    return toPersianDigits(
      '${_weekdaysFa[j.weekDay - 1]} ${j.day} ${_jalaliMonths[j.month - 1]} ${j.year}',
    );
  }

  Widget _label(AppColors c, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.textStrong,
      ),
    ),
  );

  InputDecoration _decoration(AppColors c, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
    filled: true,
    fillColor: c.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.borderSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.borderSoft),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'افزودن روز تعطیل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: c.textStrong,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label(c, 'تاریخ انتخاب شده'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.borderSoft),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: _date != null ? c.primary : c.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _dateText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _date != null
                                        ? c.textStrong
                                        : c.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _label(c, 'عنوان تعطیلی'),
                      TextField(
                        controller: _titleController,
                        style: TextStyle(color: c.textStrong),
                        decoration: _decoration(c, 'مثال: عید نوروز'),
                      ),
                      const SizedBox(height: 14),
                      _label(c, 'توضیحات (اختیاری)'),
                      TextField(
                        controller: _descController,
                        minLines: 2,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(color: c.textStrong),
                        decoration: _decoration(c, 'توضیحات اضافی...'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textStrong,
                            side: BorderSide(color: c.borderSoft),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('انصراف'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            disabledBackgroundColor: c.primary.withValues(
                              alpha: 0.4,
                            ),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'ذخیره',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
}
