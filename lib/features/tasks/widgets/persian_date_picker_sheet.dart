import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/utils/persian_number.dart';

/// انتخابگر تاریخ شمسیِ اختصاصیِ برنامه.
///
/// چرا این ویجت ساخته شد؟ پکیج `persian_datetime_picker` که قبلاً استفاده
/// می‌شد، گاهی اعداد (روز/سال) را با ارقام انگلیسی نشان می‌داد، چون
/// رندر کردن ارقام داخل خودِ پکیج انجام می‌شود و ما کنترلی روی آن نداریم.
/// این ویجت را خودمان می‌سازیم تا تضمین کنیم همه‌ی اعداد همیشه با
/// ارقام فارسی («toPersianDigits») نمایش داده شوند.
Future<DateTime?> showCustomPersianDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  Jalali? firstDate,
  Jalali? lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PersianDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate ?? Jalali(1400, 1, 1),
      lastDate: lastDate ?? Jalali(1410, 12, 29),
    ),
  );
}

class _PersianDatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final Jalali firstDate;
  final Jalali lastDate;

  const _PersianDatePickerSheet({
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_PersianDatePickerSheet> createState() =>
      _PersianDatePickerSheetState();
}

class _PersianDatePickerSheetState extends State<_PersianDatePickerSheet> {
  static const _primary = Color(0xFF6D28D9);
  static const _ink = Color(0xFF1A1A2E);

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
    final daysInMonth = _viewMonth.monthLength;
    // weekDay در Jalali: شنبه=۱ ... جمعه=۷ → برای شبکه، شنبه باید ستون صفر باشد
    final firstWeekDay = _viewMonth.weekDay - 1;
    final today = Jalali.now();

    return SafeArea(
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── هدر ماه/سال + ناوبری ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: _primary,
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_months[_viewMonth.month - 1]} ${toPersianDigits(_viewMonth.year.toString())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: _primary,
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
                            color: Colors.grey.shade500,
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
                final inRange =
                    date >= widget.firstDate && date <= widget.lastDate;

                return GestureDetector(
                  onTap: inRange
                      ? () => setState(() => _selected = date)
                      : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? _primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: (isToday && !isSelected)
                          ? Border.all(color: _primary, width: 1)
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
                            ? Colors.grey.shade300
                            : isSelected
                            ? Colors.white
                            : _ink,
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
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
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
    );
  }
}
