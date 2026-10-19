import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/utils/persian_number.dart';
import '../../../core/theme/app_colors.dart';

/// انتخابگر تاریخ شمسیِ اختصاصیِ برنامه.
///
/// چرا این ویجت ساخته شد؟ پکیج `persian_datetime_picker` که قبلاً استفاده
/// می‌شد، گاهی اعداد (روز/سال) را با ارقام انگلیسی نشان می‌داد، چون
/// رندر کردن ارقام داخل خودِ پکیج انجام می‌شود و ما کنترلی روی آن نداریم.
/// این ویجت را خودمان می‌سازیم تا تضمین کنیم همه‌ی اعداد همیشه با
/// ارقام فارسی («toPersianDigits») نمایش داده شوند.
/// [firstDate] اگر داده نشود، پیش‌فرض «امروز» است — یعنی روزهای قبل از
/// امروز به‌طور پیش‌فرض خاکستری/غیرفعال نمایش داده می‌شوند. برای مواردی
/// که واقعاً باید تاریخِ گذشته هم قابل‌انتخاب باشد، یک `firstDate` قدیمی‌تر
/// صریحاً پاس بدهید.
Future<DateTime?> showCustomPersianDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  Jalali? firstDate,
  Jalali? lastDate,
  // 🔧 طبق درخواست (تمدید موعد): با یک لمس روی روز، همان تاریخ انتخاب و
  // تقویم بسته می‌شود — بدونِ نیاز به دکمه‌ی «تأیید»
  bool pickOnTap = false,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    // 🔧 رفعِ باگ: قبلاً این کادر رنگ‌بندی‌اش کاملاً هاردکد/روشن بود
    // (بدونِ AppColors) — در تمِ تاریک، پس‌زمینه‌ی پیش‌فرضِ مودال تیره
    // می‌شد ولی متن‌ها همچنان با رنگِ تیره («_ink») رسم می‌شدند، یعنی
    // عملاً نامرئی. حالا کاملاً با AppColors هماهنگ با تمِ روشن/تاریک است.
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PersianDatePickerSheet(
      pickOnTap: pickOnTap,
      initialDate: initialDate,
      firstDate: firstDate ?? Jalali.now(),
      lastDate: lastDate ?? Jalali(1410, 12, 29),
    ),
  );
}

class _PersianDatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final Jalali firstDate;
  final Jalali lastDate;
  final bool pickOnTap;

  const _PersianDatePickerSheet({
    this.pickOnTap = false,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_PersianDatePickerSheet> createState() =>
      _PersianDatePickerSheetState();
}

class _PersianDatePickerSheetState extends State<_PersianDatePickerSheet> {
  late Jalali _viewMonth; // اولین روز ماهی که در حال نمایش است
  late Jalali _selected;

  static const _weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
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
    _selected = widget.initialDate != null
        ? Jalali.fromDateTime(widget.initialDate!)
        : Jalali.now();
    _viewMonth = Jalali(_selected.year, _selected.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      var y = _viewMonth.year;
      var m = _viewMonth.month + delta;
      if (m < 1) {
        m = 12;
        y -= 1;
      } else if (m > 12) {
        m = 1;
        y += 1;
      }
      _viewMonth = Jalali(y, m, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final daysInMonth = _viewMonth.monthLength;
    // weekDay در Jalali: شنبه=۱ ... جمعه=۷ → برای شبکه، شنبه باید ستون صفر باشد
    final firstWeekDay = _viewMonth.weekDay - 1;
    final today = Jalali.now();
    // 🔧 رفعِ باگ: Jalali.now() ساعتِ لحظه‌ی فعلی را هم در خودش نگه
    // می‌دارد؛ اگر widget.firstDate/lastDate مستقیماً با آن مقایسه شوند
    // (مثلاً firstDate: Jalali.now() از صفحه‌ی تمدیدِ موعد)، «امروز» چون
    // ساعتش صفر است ولی firstDate ساعتِ واقعی دارد، به‌اشتباه «خارج از
    // بازه» حساب می‌شد (غیرقابلِ‌کلیک + رنگِ کم‌رنگِ اشتباه). با ساختنِ
    // نسخه‌یِ بدونِ‌ساعتِ همان روزها، مقایسه فقط بر اساسِ سال/ماه/روز است.
    final firstDateOnly = Jalali(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final lastDateOnly = Jalali(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── هدر ماه/سال + ناوبری ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🔧 اصلاح: هم‌سو با تقویمِ روزهای تعطیل — آیکن‌ها ۱۸۰
                  // درجه می‌چرخند تا جهتِ فلش با جهتِ حرکت (قبل/بعد) درست باشد
                  IconButton(
                    icon: Transform.rotate(
                      angle: math.pi,
                      child: const Icon(Icons.chevron_right_rounded),
                    ),
                    color: c.primary,
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    '${_months[_viewMonth.month - 1]} ${toPersianDigits(_viewMonth.year.toString())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.textStrong,
                    ),
                  ),
                  IconButton(
                    icon: Transform.rotate(
                      angle: math.pi,
                      child: const Icon(Icons.chevron_left_rounded),
                    ),
                    color: c.primary,
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── ردیف روزهای هفته ──
              Row(
                children: _weekDays
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // ── شبکه‌ی روزهای ماه ──
              GridView.builder(
                shrinkWrap: true,
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
                  final date = Jalali(_viewMonth.year, _viewMonth.month, day);

                  final isSelected =
                      date.year == _selected.year &&
                      date.month == _selected.month &&
                      date.day == _selected.day;
                  final isToday =
                      date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final inRange = date >= firstDateOnly && date <= lastDateOnly;

                  return GestureDetector(
                    onTap: inRange
                        ? () {
                            if (widget.pickOnTap) {
                              Navigator.of(context).pop(date.toDateTime());
                              return;
                            }
                            setState(() => _selected = date);
                          }
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? c.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: (isToday && !isSelected)
                            ? Border.all(color: c.primary, width: 1)
                            : null,
                      ),
                      child: Text(
                        toPersianDigits(day.toString()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: !inRange
                              ? c.textMuted.withValues(alpha: 0.4)
                              : isSelected
                              ? Colors.white
                              : c.textStrong,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textStrong,
                        side: BorderSide(color: c.borderSoft),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_selected.toDateTime()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('تأیید'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
