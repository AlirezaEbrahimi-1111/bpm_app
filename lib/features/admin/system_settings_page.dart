import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/app_switch.dart';
import '../../core/utils/persian_number.dart';

const _groupIcons = {
  'attendance': Icons.calendar_month_rounded,
  'calculation': Icons.calculate_outlined,
  'approval': Icons.history_toggle_off_rounded,
  'leave': Icons.house_outlined,
  'limits': Icons.shield_outlined,
};

const _groupColors = {
  'attendance': Color(0xFF3B82F6),
  'calculation': Color(0xFF8E57FE),
  'approval': Color(0xFFF59E0B),
  'leave': Color(0xFF1B7B39),
  'limits': Color(0xFFEF4444),
};

/// «تنظیمات سیستم» — پورتِ attendance_system/pages/settings.php برایِ
/// موبایل. آدرسِ داده — تازه به وب اضافه شد، دقیقاً بر همین الگوی بقیه
/// APIهای پروژه (بدونِ HTML، فقط JSON):
///   GET  /attendance_system/api/attendance/settings.php
///   POST همان آدرس، بدنه: {setting_key: value, ...} برایِ همه‌ی کلیدها
class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _groups = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  final Set<String> _collapsed = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/attendance_system/api/attendance/settings.php',
      );
      final data = res.data;
      if (data['success'] == true) {
        final groups = (data['groups'] as Map).cast<String, dynamic>();
        for (final c in _controllers.values) {
          c.dispose();
        }
        _controllers.clear();
        _boolValues.clear();
        for (final g in groups.values) {
          final settings = (g['settings'] as Map).cast<String, dynamic>();
          for (final s in settings.values) {
            final key = s['key'].toString();
            if (s['type'] == 'boolean') {
              _boolValues[key] = s['value'].toString() == '1';
            } else {
              // 🔧 طبق درخواست: فیلدِ مبالغِ ریالی جداکننده‌ی هزارگان دارد
              final useThousands = (s['unit'] ?? '').toString() == 'ریال';
              final digitsOnly = (s['value'] ?? '').toString().replaceAll(
                RegExp(r'[^\d]'),
                '',
              );
              _controllers[key] = TextEditingController(
                text: toPersianDigits(
                  useThousands ? groupThousands(digitsOnly) : digitsOnly,
                ),
              );
            }
          }
        }
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافتِ تنظیمات';
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

  Future<void> _save() async {
    // اعتبارسنجیِ سمتِ کلاینت (min/max) — همان قوانینِ وب، برایِ پیامِ فوری‌تر
    for (final g in _groups.values) {
      final settings = (g['settings'] as Map).cast<String, dynamic>();
      for (final s in settings.values) {
        if (s['type'] != 'number') continue;
        final key = s['key'].toString();
        final raw = toEnglishDigits(
          _controllers[key]?.text.trim() ?? '',
        ).replaceAll(',', '');
        final value = int.tryParse(raw);
        if (value == null) {
          AppSnack.error('خطا', '${s['label']}: مقدار نامعتبر است');
          return;
        }
        final min = s['min'] != null ? int.tryParse(s['min'].toString()) : null;
        final max = s['max'] != null ? int.tryParse(s['max'].toString()) : null;
        if (min != null && value < min) {
          AppSnack.error(
            'خطا',
            '${s['label']}: حداقل مقدار ${toPersianDigits(min)} است',
          );
          return;
        }
        if (max != null && value > max) {
          AppSnack.error(
            'خطا',
            '${s['label']}: حداکثر مقدار ${toPersianDigits(max)} است',
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    final body = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      body[entry.key] = toEnglishDigits(
        entry.value.text.trim(),
      ).replaceAll(',', '');
    }
    for (final entry in _boolValues.entries) {
      if (entry.value) body[entry.key] = '1';
    }
    try {
      final res = await ApiClient.dio.post(
        '/attendance_system/api/attendance/settings.php',
        data: body,
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success(
          '✅ ثبت شد',
          data['message']?.toString() ?? 'تنظیمات ذخیره شدند',
        );
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در ذخیره‌سازی',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
    if (mounted) setState(() => _isSaving = false);
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
          'تنظیمات سیستم',
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
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: _groups.entries
                        .map((e) => _groupCard(c, e.key, e.value))
                        .toList(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    12 + MediaQuery.of(context).padding.bottom,
                  ),
                  // 🔧 طبق درخواست: بزرگ و تمام‌عرض، مثلِ دکمه‌ی «ارجاع به ...»
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
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
                              'ذخیره تنظیمات',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _groupCard(AppColors c, String groupKey, dynamic group) {
    final settings = (group['settings'] as Map).cast<String, dynamic>();
    final collapsed = _collapsed.contains(groupKey);
    final color = _groupColors[groupKey] ?? c.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSoft),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (collapsed) {
                _collapsed.remove(groupKey);
              } else {
                _collapsed.add(groupKey);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _groupIcons[groupKey] ?? Icons.settings_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (group['title'] ?? '').toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: c.textStrong,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: collapsed
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      Divider(height: 1, color: c.borderSoft),
                      ...settings.values.map((s) => _settingRow(c, s)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(AppColors c, dynamic s) {
    final key = s['key'].toString();
    final isBoolean = s['type'] == 'boolean';
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (s['label'] ?? '').toString(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textStrong,
                  ),
                ),
                if ((s['help'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    (s['help']).toString(),
                    style: TextStyle(fontSize: 11, color: c.textMuted),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isBoolean)
            AppSwitch(
              value: _boolValues[key] ?? false,
              onChanged: (v) => setState(() => _boolValues[key] = v),
              activeColor: c.primary,
            )
          else ...[
            SizedBox(
              width: 90,
              child: TextField(
                controller: _controllers[key],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                // 🔧 طبق درخواست: اعدادِ داخلِ کادر فارسی، و فیلدِ ریالی
                // جداکننده‌ی هزارگان هم دارد
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]')),
                  if ((s['unit'] ?? '').toString() == 'ریال')
                    ThousandsSeparatorInputFormatter()
                  else
                    PersianDigitsInputFormatter(),
                ],
                style: TextStyle(
                  color: c.textStrong,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: c.borderSoft),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
            // 🔧 رفعِ باگِ «کادرهای متن در یک راستا نیستند»: عرضِ این
            // عبارت (ساعت/روز/برابر/...) قبلاً متغیر بود، پس فضایِ باقی‌مانده
            // برایِ ستونِ برچسب هم ردیف‌به‌ردیف فرق می‌کرد و کادرِ متن‌ها
            // هم‌راستا نمی‌شدند. حالا این عرض همیشه ثابت است — حتی وقتی
            // عبارتی وجود ندارد — تا کادرهای متن دقیقاً زیرِ هم بیفتند
            SizedBox(
              width: 46,
              child: Text(
                (s['unit'] ?? '').toString(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
