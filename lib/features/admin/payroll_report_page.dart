import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';

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

String _fmtToman(num? rial) {
  if (rial == null) return '—';
  final toman = (rial / 10).round();
  final s = toman.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return toPersianDigits('${buf.toString()} تومان');
}

/// «گزارش حقوق پرسنل» — پورتِ attendance_system/pages/payroll-report.php
/// برایِ موبایل. همان API وب:
///   GET /attendance_system/api/attendance/payroll-report.php?jy=&jm=
class PayrollReportPage extends StatefulWidget {
  const PayrollReportPage({super.key});

  @override
  State<PayrollReportPage> createState() => _PayrollReportPageState();
}

class _PayrollReportPageState extends State<PayrollReportPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _rows = [];
  Map<String, dynamic>? _totals;
  int? _jy;
  int? _jm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? jy, int? jm}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/attendance_system/api/attendance/payroll-report.php',
        queryParameters: {if (jy != null) 'jy': jy, if (jm != null) 'jm': jm},
      );
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _rows = data['rows'] as List? ?? [];
          _totals = (data['totals'] as Map?)?.cast<String, dynamic>();
          _jy = data['jy'] is int
              ? data['jy']
              : int.tryParse(data['jy'].toString());
          _jm = data['jm'] is int
              ? data['jm']
              : int.tryParse(data['jm'].toString());
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافتِ گزارش';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'خطا در اتصال به سرور — احتمالاً دسترسیِ لازم را ندارید';
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    if (_jy == null || _jm == null) return;
    var y = _jy!;
    var m = _jm! + delta;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    _load(jy: y, jm: m);
  }

  void _showDetail(dynamic row) {
    final c = AppColors.of(context);
    Get.bottomSheet(
      Container(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  (row['name'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (row['section'] ?? '').toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
                const SizedBox(height: 16),
                _detailRow(c, 'حقوق پایه', _fmtToman(row['base_salary'])),
                _detailRow(
                  c,
                  'کسری ×۲ ضریب',
                  toPersianDigits((row['final_hms'] ?? '0:00').toString()),
                ),
                _detailRow(c, 'جریمهٔ کسری', _fmtToman(row['shortage_money'])),
                _detailRow(
                  c,
                  'حقوق تا امروز',
                  _fmtToman(row['salary_received']),
                  emphasize: true,
                ),
                Divider(color: c.borderSoft, height: 24),
                _detailRow(
                  c,
                  'جمع مرخصی/پاس',
                  toPersianDigits((row['leave_pass_hms'] ?? '0:00').toString()),
                ),
                _detailRow(
                  c,
                  'سهمیهٔ ماهانه',
                  toPersianDigits(
                    _minutesToHm(row['leave_pass_quota_minutes']),
                  ),
                ),
                _detailRow(
                  c,
                  'سهمیهٔ باقی‌مانده',
                  toPersianDigits(
                    (row['leave_pass_remaining_hms'] ?? '0:00').toString(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  String _minutesToHm(dynamic m) {
    final mins = m is int ? m : int.tryParse(m?.toString() ?? '') ?? 0;
    final h = mins ~/ 60;
    final r = mins % 60;
    return '$h:${r.toString().padLeft(2, '0')}';
  }

  Widget _detailRow(
    AppColors c,
    String label,
    String value, {
    bool emphasize = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.textMuted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
            color: emphasize ? c.primary : c.textStrong,
          ),
        ),
      ],
    ),
  );

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
          'گزارش حقوق پرسنل',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 15,
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
                      onPressed: () => _load(),
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: c.primary,
              onRefresh: () => _load(jy: _jy, jm: _jm),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  // ── انتخابگرِ ماه ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.borderSoft),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: c.textMuted,
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          (_jy != null && _jm != null)
                              ? '${_jalaliMonths[_jm! - 1]} ${toPersianDigits(_jy!)}'
                              : '—',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: c.textStrong,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: c.textMuted,
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── جمع کل ──
                  if (_totals != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _totalItem(
                              c,
                              'جمع حقوق پایه',
                              _fmtToman(_totals!['base_salary']),
                            ),
                          ),
                          Container(width: 1, height: 32, color: c.borderSoft),
                          Expanded(
                            child: _totalItem(
                              c,
                              'جمع پرداختی',
                              _fmtToman(_totals!['salary_received']),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    toPersianDigits('${_rows.length} نفر'),
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                  const SizedBox(height: 8),
                  if (_rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'داده‌ای برای این ماه نیست',
                          style: TextStyle(color: c.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._rows.map((r) => _row(c, r)),
                ],
              ),
            ),
    );
  }

  Widget _totalItem(AppColors c, String label, String value) => Column(
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: c.textMuted)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.bold,
          color: c.primary,
        ),
      ),
    ],
  );

  Widget _row(AppColors c, dynamic r) {
    final remainingMin = r['leave_pass_remaining_minutes'];
    final over = remainingMin is num && remainingMin < 0;
    return GestureDetector(
      onTap: () => _showDetail(r),
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
                    (r['name'] ?? '').toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: c.textStrong,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (over)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'تجاوز از سهمیه',
                      style: TextStyle(
                        fontSize: 10,
                        color: c.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              (r['section'] ?? '').toString(),
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _mini(
                    c,
                    'حقوق تا امروز',
                    _fmtToman(r['salary_received']),
                  ),
                ),
                Expanded(
                  child: _mini(
                    c,
                    'جریمهٔ کسری',
                    _fmtToman(r['shortage_money']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(AppColors c, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: c.textStrong,
        ),
      ),
    ],
  );
}
