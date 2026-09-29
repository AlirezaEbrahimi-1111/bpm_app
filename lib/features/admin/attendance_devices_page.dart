import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_snack.dart';

/// «دستگاه‌های حضور و غیاب» — پورتِ pages/attendance-devices.php برایِ
/// موبایل. آدرسِ داده دقیقاً همان API نسخه‌ی وب است (سه‌تب):
///   GET  /go/api/attendance/devices            لیستِ دستگاه‌ها
///   POST /api/attendance/devices.php           تأیید/رد/حذف (action+id)
///   POST /go/api/attendance/devices            ویرایشِ برچسب (action:relabel)
///   GET  /go/api/attendance/allowed-ips        لیستِ آی‌پی‌های مجاز
///   POST /go/api/attendance/allowed-ips        افزودن/فعال‌سازی/حذف
///   GET  /go/api/attendance/denied-log?range=  گزارشِ تلاش‌های ناموفق
///   POST /go/api/attendance/denied-log         حذفِ یک ردیف / پاک‌سازیِ بازه
///
/// 🔧 نکته: این سه endpoint با پیشوندِ /go/api از یک میکروسرویسِ Go
/// (نه PHP) سرو می‌شوند؛ چون هم‌دامنه‌اند و همان توکنِ Bearer را
/// می‌پذیرند، دقیقاً مثلِ بقیه‌ی APIهای اپ با ApiClient.dio صدا زده می‌شوند.
class AttendanceDevicesPage extends StatefulWidget {
  const AttendanceDevicesPage({super.key});

  @override
  State<AttendanceDevicesPage> createState() => _AttendanceDevicesPageState();
}

class _AttendanceDevicesPageState extends State<AttendanceDevicesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
          'دستگاه‌های حضور و غیاب',
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
        bottom: TabBar(
          controller: _tab,
          labelColor: c.primary,
          unselectedLabelColor: c.textMuted,
          indicatorColor: c.primary,
          labelStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'دستگاه‌ها'),
            Tab(text: 'آی‌پی‌های مجاز'),
            Tab(text: 'تلاش‌های ناموفق'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_DevicesTab(), _AllowedIpsTab(), _DeniedLogTab()],
      ),
    );
  }
}

String _toShamsiTime(String? gregorian) {
  if (gregorian == null || gregorian.isEmpty) return '—';
  try {
    final date = DateTime.parse(gregorian.replaceFirst(' ', 'T'));
    final j = Jalali.fromDateTime(date);
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
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return toPersianDigits('${j.day} ${mo[j.month - 1]} $h:$m');
  } catch (_) {
    return '—';
  }
}

Widget _statusBadge(AppColors c, String status) {
  final map = {
    'approved': ('تأییدشده', c.success, Icons.check_circle_rounded),
    'rejected': ('ردشده', c.danger, Icons.cancel_rounded),
  };
  final (label, color, icon) =
      map[status] ?? ('در انتظار', c.warning, Icons.hourglass_top_rounded);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════
// تب ۱: دستگاه‌ها
// ═══════════════════════════════════════════════════
class _DevicesTab extends StatefulWidget {
  const _DevicesTab();

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get('/go/api/attendance/devices');
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _devices = data['devices'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در بارگذاری دستگاه‌ها';
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

  Future<void> _action(dynamic device, String action) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/attendance/devices.php',
        data: {'action': action, 'id': device['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ انجام شد', data['message']?.toString() ?? '');
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در انجامِ عملیات',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _confirmDelete(dynamic device) async {
    final c = AppColors.of(context);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        content: Text(
          'این دستگاه حذف شود؟',
          style: TextStyle(color: c.textStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok == true) _action(device, 'delete');
  }

  Future<void> _relabel(dynamic device) async {
    final c = AppColors.of(context);
    final controller = TextEditingController(
      text: (device['label'] ?? '').toString(),
    );
    final label = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        title: Text(
          'برچسبِ دستگاه',
          style: TextStyle(color: c.textStrong, fontSize: 15),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'مثلاً: صندوق ۱ - فروشگاه مرکزی',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            child: Text('ذخیره', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
    if (label == null) return;
    try {
      final res = await ApiClient.dio.post(
        '/go/api/attendance/devices',
        data: {'action': 'relabel', 'id': device['id'], 'label': label},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ ثبت شد', 'برچسب ذخیره شد');
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در ذخیره برچسب',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_isLoading)
      return Center(child: CircularProgressIndicator(color: c.primary));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 44, color: c.textMuted),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('تلاش مجدد')),
            ],
          ),
        ),
      );
    }
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other_rounded,
              size: 44,
              color: c.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text('دستگاهی ثبت نشده است', style: TextStyle(color: c.textMuted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: c.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: _devices.length,
        itemBuilder: (ctx, i) {
          final d = _devices[i];
          final status = (d['status'] ?? 'pending').toString();
          final label = (d['label'] ?? '').toString().trim();
          final requesterName = (d['first_seen_user_name'] ?? '')
              .toString()
              .trim();
          // 🔧 طبق درخواست: به‌جای «بدون برچسب»، نامِ کاربرِ درخواست‌دهنده
          final title = label.isNotEmpty
              ? label
              : (requesterName.isNotEmpty ? requesterName : 'بدون برچسب');
          return Container(
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
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: c.textStrong,
                        ),
                      ),
                    ),
                    _statusBadge(c, status),
                  ],
                ),
                const SizedBox(height: 8),
                // 🔧 طبق درخواست: فقط تاریخِ ثبت، زیرِ عنوان
                _kv(c, 'تاریخ ثبت', _toShamsiTime(d['created_at']?.toString())),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status != 'approved')
                      _iconBtn(
                        c,
                        Icons.check_rounded,
                        c.success,
                        'تأیید',
                        () => _action(d, 'approve'),
                      ),
                    if (status != 'rejected')
                      _iconBtn(
                        c,
                        Icons.block_rounded,
                        c.danger,
                        'رد',
                        () => _action(d, 'reject'),
                      ),
                    _iconBtn(
                      c,
                      Icons.edit_outlined,
                      c.textMuted,
                      'ویرایش برچسب',
                      () => _relabel(d),
                    ),
                    _iconBtn(
                      c,
                      Icons.delete_outline_rounded,
                      c.danger,
                      'حذف',
                      () => _confirmDelete(d),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kv(AppColors c, String k, String v) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$k: ',
          style: TextStyle(fontSize: 11, color: c.textMuted),
        ),
        TextSpan(
          text: v,
          style: TextStyle(
            fontSize: 11,
            color: c.textStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _iconBtn(
    AppColors c,
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════
// تب ۲: آی‌پی‌های مجاز
// ═══════════════════════════════════════════════════
class _AllowedIpsTab extends StatefulWidget {
  const _AllowedIpsTab();

  @override
  State<_AllowedIpsTab> createState() => _AllowedIpsTabState();
}

class _AllowedIpsTabState extends State<_AllowedIpsTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _ips = [];
  final _ipController = TextEditingController();
  final _labelController = TextEditingController();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get('/go/api/attendance/allowed-ips');
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _ips = data['ips'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در بارگذاری';
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

  Future<void> _add() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      AppSnack.error('خطا', 'آدرس IP را وارد کنید');
      return;
    }
    setState(() => _isAdding = true);
    try {
      final res = await ApiClient.dio.post(
        '/go/api/attendance/allowed-ips',
        data: {
          'action': 'add',
          'ip_address': ip,
          'label': _labelController.text.trim(),
        },
      );
      final data = res.data;
      if (data['success'] == true) {
        _ipController.clear();
        _labelController.clear();
        AppSnack.success(
          '✅ ثبت شد',
          data['message']?.toString() ?? 'آی‌پی اضافه شد',
        );
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در ثبت');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
    if (mounted) setState(() => _isAdding = false);
  }

  Future<void> _toggle(dynamic ip) async {
    try {
      final res = await ApiClient.dio.post(
        '/go/api/attendance/allowed-ips',
        data: {'action': 'toggle', 'id': ip['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ انجام شد', data['message']?.toString() ?? '');
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _delete(dynamic ip) async {
    final c = AppColors.of(context);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        content: Text(
          'این آی‌پی حذف شود؟',
          style: TextStyle(color: c.textStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.dio.post(
        '/go/api/attendance/allowed-ips',
        data: {'action': 'delete', 'id': ip['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('🗑️ حذف شد', 'آی‌پی حذف شد');
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در حذف');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.borderSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ipController,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: c.textStrong, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'آدرس IP',
                    hintStyle: TextStyle(color: c.textMuted, fontSize: 12.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                const SizedBox(height: 8),
                TextField(
                  controller: _labelController,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: c.textStrong, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'برچسب (اختیاری)',
                    hintStyle: TextStyle(color: c.textMuted, fontSize: 12.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isAdding ? null : _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('افزودن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textMuted),
                    ),
                  ),
                )
              : _ips.isEmpty
              ? Center(
                  child: Text(
                    'هیچ آی‌پی مجازی ثبت نشده است',
                    style: TextStyle(color: c.textMuted),
                  ),
                )
              : RefreshIndicator(
                  color: c.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: _ips.length,
                    itemBuilder: (ctx, i) {
                      final ip = _ips[i];
                      final active =
                          ip['is_active'] == 1 || ip['is_active'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: active ? c.success : c.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (ip['ip_address'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: c.textStrong,
                                    ),
                                  ),
                                  if ((ip['label'] ?? '').toString().isNotEmpty)
                                    Text(
                                      ip['label'].toString(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.power_settings_new_rounded,
                                size: 18,
                                color: active ? c.success : c.textMuted,
                              ),
                              onPressed: () => _toggle(ip),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: c.danger,
                              ),
                              onPressed: () => _delete(ip),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// تب ۳: تلاش‌های ناموفق
// ═══════════════════════════════════════════════════
class _DeniedLogTab extends StatefulWidget {
  const _DeniedLogTab();

  @override
  State<_DeniedLogTab> createState() => _DeniedLogTabState();
}

class _DeniedLogTabState extends State<_DeniedLogTab> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _logs = [];
  String _range = 'all';

  static const _reasonLabels = {
    'IP_NOT_ALLOWED': 'خارج از شبکهٔ مجاز',
    'NO_FINGERPRINT': 'بدون شناسهٔ دستگاه',
    'DEVICE_PENDING': 'دستگاه در انتظار تأیید',
    'DEVICE_NOT_APPROVED': 'دستگاه تأییدنشده',
    'DEVICE_REJECTED': 'دستگاه ردشده',
  };
  static const _rangeLabels = {
    'today': 'امروز',
    'week': 'هفتهٔ اخیر',
    'all': 'همه',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/go/api/attendance/denied-log',
        queryParameters: {'range': _range},
      );
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _logs = data['logs'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در بارگذاری';
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

  Future<void> _delete(dynamic log) async {
    try {
      final res = await ApiClient.dio.post(
        '/go/api/attendance/denied-log',
        data: {'action': 'delete', 'id': log['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('🗑️ حذف شد', 'مورد حذف شد');
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در حذف');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _clear() async {
    final c = AppColors.of(context);
    final label = _rangeLabels[_range] ?? '';
    final ok = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        content: Text(
          'همهٔ تلاش‌های ناموفق «$label» پاک شوند؟',
          style: TextStyle(color: c.textStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('بله، پاک کن', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.dio.post(
        '/go/api/attendance/denied-log',
        data: {'action': 'clear', 'range': _range},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ انجام شد', data['message']?.toString() ?? 'پاک شد');
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _range,
                  isExpanded: true,
                  dropdownColor: c.surface,
                  style: TextStyle(color: c.textStrong, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.borderSoft),
                    ),
                  ),
                  items: _rangeLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _range = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _logs.isEmpty ? null : _clear,
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  size: 16,
                  color: c.danger,
                ),
                label: Text(
                  'پاک‌سازی',
                  style: TextStyle(color: c.danger, fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textMuted),
                    ),
                  ),
                )
              : _logs.isEmpty
              ? Center(
                  child: Text(
                    'تلاش ناموفقی ثبت نشده است',
                    style: TextStyle(color: c.textMuted),
                  ),
                )
              : RefreshIndicator(
                  color: c.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final l = _logs[i];
                      final action = (l['action'] ?? '').toString();
                      final reason = (l['reason'] ?? '').toString();
                      final userName = (l['user_name'] ?? '').toString().trim();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.borderSoft),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        userName.isEmpty
                                            ? 'کاربر ناشناس'
                                            : userName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: c.textStrong,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (action == 'check_in'
                                                      ? c.success
                                                      : c.danger)
                                                  .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          action == 'check_in'
                                              ? 'ورود'
                                              : (action == 'check_out'
                                                    ? 'خروج'
                                                    : action),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: action == 'check_in'
                                                ? c.success
                                                : c.danger,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _reasonLabels[reason] ??
                                        (reason.isEmpty ? '—' : reason),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(l['ip_address'] ?? '—')} • ${_toShamsiTime(l['created_at']?.toString())}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _delete(l),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
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
        ),
      ],
    );
  }
}
