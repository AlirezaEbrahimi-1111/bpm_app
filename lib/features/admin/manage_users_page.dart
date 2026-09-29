import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/utils/persian_number.dart';
import '../../core/widgets/app_switch.dart';

/// «مدیریت کاربران» — پورتِ صفحه‌ی وب pages/users.php برایِ موبایل.
/// آدرسِ داده و عملیات دقیقاً همان API نسخه‌ی وب است:
///   GET  /api/admin/users.php
///   GET  /api/organization/activity-sections.php
///   POST /api/admin/create-user.php
///   POST /api/admin/update-user.php
///   POST /api/admin/toggle-user-status.php
///   GET  /api/admin/user-pending-tasks.php
///   POST /api/admin/delete-user.php
///
/// 🔧 محدودیتِ عمدیِ باقی‌مانده نسبت به وب: اعطای دسترسیِ روتین/فرآیند،
/// درختِ سلسله‌مراتبِ گرافیکی، و رسیدگیِ کاملِ کارهایِ بازِ کاربر هنگامِ
/// غیرفعال‌سازی (وب یک مودالِ واگذاریِ کار دارد؛ اینجا فقط پیامِ روشن
/// می‌دهیم که باید از وب استفاده شود، تا هیچ کاری بی‌صاحب نماند).
/// «درخواست‌های سهمیه‌ی تشویقی» عمداً نیامده — در خودِ pages/users.php
/// وب هم چیزی جز چند کلاسِ CSSِ بلااستفاده (.bonus-req-box) از آن نبود؛
/// قابلیتِ واقعی‌اش (leave-bonus-requests) بخشی از ماژولِ جداگانه‌ی
/// حضور و غیاب است، نه همین صفحه.
class ManageUsersPage extends StatefulWidget {
  final String currentUserRole;
  const ManageUsersPage({super.key, required this.currentUserRole});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

const _roleRank = {'employee': 0, 'manager': 1, 'supervisor': 2, 'admin': 2};

const _roleLabels = {
  'employee': 'کارمند',
  'manager': 'مدیر',
  'supervisor': 'ناظر سازمان',
  'admin': 'مدیرکل',
  'management': 'مدیریت',
};

class _ManageUsersPageState extends State<ManageUsersPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];
  List<dynamic> _sections = [];
  String _query = '';
  // 'all' | 'active' | 'inactive'
  String _statusFilter = 'all';

  // 🔧 admin/users.php عکسِ پروفایل برنمی‌گرداند؛ فقط chat/search-users.php
  // این را دارد (و فقط برایِ کاربرانِ فعال، حداکثر ۳۰ نفر، بدونِ خودِ actor).
  // بهترین‌تلاشِ ممکن: هرجا تطبیق پیدا شد عکسِ واقعی، وگرنه حرفِ اول
  Map<int, String> _avatarUrls = {};

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
      final results = await Future.wait([
        ApiClient.dio.get('/api/admin/users.php'),
        ApiClient.dio.get('/api/organization/activity-sections.php'),
        ApiClient.dio.get('/api/chat/search-users.php'),
      ]);
      final usersData = results[0].data;
      if (usersData['success'] == true) {
        _users = usersData['users'] as List? ?? [];
      } else {
        _error = usersData['message']?.toString() ?? 'خطا در دریافتِ کاربران';
      }
      final sectionsData = results[1].data;
      if (sectionsData['success'] == true) {
        _sections = sectionsData['sections'] as List? ?? [];
      }
      final avatarsData = results[2].data;
      if (avatarsData['success'] == true) {
        final list = avatarsData['users'] as List? ?? [];
        _avatarUrls = {
          for (final u in list)
            if (u['avatar_url'] != null)
              (u['id'] as num).toInt(): u['avatar_url'].toString(),
        };
      }
    } catch (e) {
      _error =
          'خطا در اتصال به سرور — احتمالاً دسترسیِ «مدیریتِ کاربران» ندارید';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _sectionLabel(String? key) {
    if (key == null || key.isEmpty) return 'عمومی';
    final s = _sections.firstWhere(
      (s) => s['section_key'] == key,
      orElse: () => null,
    );
    return s == null ? key : (s['section_label']?.toString() ?? key);
  }

  List<dynamic> get _filtered {
    var list = _users;
    if (_statusFilter == 'active') {
      list = list
          .where((u) => u['is_active'] == 1 || u['is_active'] == true)
          .toList();
    } else if (_statusFilter == 'inactive') {
      list = list
          .where((u) => u['is_active'] == 0 || u['is_active'] == false)
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) {
        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
            .toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || username.contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _toggleStatus(dynamic user) async {
    final isActive = user['is_active'] == 1 || user['is_active'] == true;
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
        .trim();

    if (isActive) {
      // طبق وب: قبل از غیرفعال‌سازی، کارهای بازِ کاربر چک می‌شود
      try {
        final res = await ApiClient.dio.get(
          '/api/admin/user-pending-tasks.php',
          queryParameters: {'user_id': user['id']},
        );
        final data = res.data;
        final tasks = data['tasks'] as List? ?? [];
        if (data['success'] == true && tasks.isNotEmpty) {
          if (!mounted) return;
          _showPendingTasksBlock(
            name.isEmpty ? 'این کاربر' : name,
            tasks.length,
          );
          return;
        }
      } catch (_) {
        // اگر خودِ چک شکست خورد، مثل وب اجازه می‌دهیم غیرفعال‌سازیِ ساده ادامه یابد
      }
    }

    final confirmed = await _confirm(
      isActive
          ? '⚠️ غیرفعال کردن «${name.isEmpty ? 'این کاربر' : name}» — این کاربر دیگر نمی‌تواند وارد سیستم شود. مطمئن هستید؟'
          : 'فعال کردن «${name.isEmpty ? 'این کاربر' : name}»؟',
    );
    if (!confirmed) return;

    try {
      final res = await ApiClient.dio.post(
        '/api/admin/toggle-user-status.php',
        data: {'user_id': user['id'], 'is_active': isActive ? 0 : 1},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ انجام شد', data['message']?.toString() ?? '');
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در تغییر وضعیت',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _showPendingTasksBlock(String name, int count) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        title: Text(
          'کارِ باز دارد',
          style: TextStyle(color: c.textStrong, fontSize: 16),
        ),
        content: Text(
          '$name هنوز ${toPersianDigits(count)} کارِ باز دارد. قبل از غیرفعال‌سازی، باید تکلیفِ این کارها (واگذاری/تکمیل) مشخص شود. این بخش فعلاً فقط در نسخه‌ی وب انجام‌پذیر است.',
          style: TextStyle(color: c.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String message) async {
    final c = AppColors.of(context);
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        content: Text(
          message,
          style: TextStyle(color: c.textStrong, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('تأیید', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _delete(dynamic user) async {
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
        .trim();
    final confirmed = await _confirm(
      '🗑️ حذفِ «${name.isEmpty ? 'این کاربر' : name}» — این کار قابلِ بازگشت نیست. مطمئن هستید؟',
    );
    if (!confirmed) return;
    try {
      final res = await ApiClient.dio.post(
        '/api/admin/delete-user.php',
        data: {'user_id': user['id']},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success(
          '🗑️ حذف شد',
          data['message']?.toString() ?? 'کاربر حذف شد',
        );
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در حذف کاربر',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  String _toShamsi(String? gregorian) {
    if (gregorian == null || gregorian.isEmpty) return '—';
    try {
      final date = DateTime.parse(gregorian);
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
      return toPersianDigits('${j.day} ${mo[j.month - 1]} ${j.year}');
    } catch (_) {
      return '—';
    }
  }

  /// طبق درخواست: با ضربه روی هر کارت، اطلاعاتِ کامل کاربر در یک شیتِ
  /// فقط‌خواندنی نمایش داده می‌شود؛ از همان‌جا می‌توان وارد ویرایش شد
  void _showUserDetailsSheet(dynamic u) {
    final c = AppColors.of(context);
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    final isActive = u['is_active'] == 1 || u['is_active'] == true;
    final role = (u['role'] ?? 'employee').toString();
    final manager = _users.firstWhere(
      (m) => m['id'] == u['manager_id'],
      orElse: () => null,
    );
    final managerName = manager == null
        ? '—'
        : '${manager['first_name'] ?? ''} ${manager['last_name'] ?? ''}'.trim();
    final shiftType = (u['shift_type'] ?? 'single').toString();
    final salaryRial = u['monthly_salary'];
    final salaryToman = salaryRial is num ? (salaryRial / 10).round() : 0;

    Get.bottomSheet(
      ConstrainedBox(
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
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isActive
                      ? c.primary.withValues(alpha: 0.15)
                      : c.borderSoft,
                  foregroundImage:
                      _avatarUrls.containsKey((u['id'] as num).toInt())
                      ? NetworkImage(
                          '${ApiClient.baseUrl}/${_avatarUrls[(u['id'] as num).toInt()]}',
                        )
                      : null,
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: TextStyle(
                      color: isActive ? c.primary : c.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name.isEmpty ? 'بدون نام' : name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'فعال' : 'غیرفعال',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? c.success : c.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      children: [
                        _infoRow(
                          c,
                          'شماره موبایل',
                          (u['phone'] ?? '—').toString(),
                        ),
                        _infoRow(
                          c,
                          'نام کاربری',
                          (u['username'] ?? '—').toString(),
                        ),
                        _infoRow(
                          c,
                          'ایمیل',
                          (u['email'] ?? '').toString().isEmpty
                              ? '—'
                              : u['email'].toString(),
                        ),
                        _infoRow(c, 'نقش', _roleLabels[role] ?? role),
                        _infoRow(
                          c,
                          'واحد فعالیت',
                          _sectionLabel(u['activity_section']?.toString()),
                        ),
                        _infoRow(c, 'مدیر مستقیم', managerName),
                        _infoRow(
                          c,
                          'نوع شیفت',
                          shiftType == 'double' ? 'دو شیفت' : 'تک شیفت',
                        ),
                        _infoRow(
                          c,
                          'ساعت کاری روزانه',
                          u['daily_work_hours'] == null
                              ? '—'
                              : toPersianDigits(
                                  '${u['daily_work_hours']} ساعت',
                                ),
                        ),
                        _infoRow(
                          c,
                          'حقوق ماهانه',
                          salaryToman > 0
                              ? toPersianDigits('$salaryToman تومان')
                              : '—',
                        ),
                        _infoRow(
                          c,
                          'تاریخ عضویت',
                          _toShamsi(u['created_at']?.toString()),
                        ),
                        _infoRow(
                          c,
                          'آخرین ورود',
                          _toShamsi(u['last_login']?.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        _openUserFormSheet(user: u);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'ویرایش اطلاعات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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

  Widget _infoRow(AppColors c, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔧 طبق درخواست: عرضِ ثابت برایِ برچسب‌ها، تا مقدارها همه راست‌چین
        // و روی یک راستایِ عمودیِ ثابت (لبه‌ی چپِ همین ستون) بیفتند
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textStrong,
            ),
          ),
        ),
      ],
    ),
  );

  void _openUserFormSheet({dynamic user}) {
    final c = AppColors.of(context);
    Get.bottomSheet(
      _UserFormSheet(
        c: c,
        user: user,
        allUsers: _users,
        sections: _sections,
        actorRole: widget.currentUserRole,
        onSaved: _load,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
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
          'مدیریت کاربران',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openUserFormSheet(user: null),
        backgroundColor: c.primary,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
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
          : RefreshIndicator(
              color: c.primary,
              onRefresh: _load,
              child: ListView(
                // 🔧 طبق درخواست: فاصله‌ی دکمه‌های ناوبریِ گوشی هم رعایت شود
                // تا آخرین کارت پشتِ آن‌ها نرود
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: c.textStrong, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'جستجوی نام، شماره یا نام‌کاربری...',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: c.textMuted,
                      ),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statusChip(
                        c,
                        'all',
                        'همه (${toPersianDigits(_users.length)})',
                      ),
                      const SizedBox(width: 8),
                      _statusChip(
                        c,
                        'active',
                        'فعال (${toPersianDigits(_users.where((u) => u['is_active'] == 1 || u['is_active'] == true).length)})',
                      ),
                      const SizedBox(width: 8),
                      _statusChip(
                        c,
                        'inactive',
                        'غیرفعال (${toPersianDigits(_users.where((u) => u['is_active'] == 0 || u['is_active'] == false).length)})',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          'کاربری یافت نشد',
                          style: TextStyle(color: c.textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map((u) => _userCard(c, u)),
                ],
              ),
            ),
    );
  }

  Widget _statusChip(AppColors c, String key, String label) {
    final selected = _statusFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.primary : c.borderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _userCard(AppColors c, dynamic u) {
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    final isActive = u['is_active'] == 1 || u['is_active'] == true;
    final role = (u['role'] ?? 'employee').toString();
    return GestureDetector(
      onTap: () => _showUserDetailsSheet(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isActive
                  ? c.primary.withValues(alpha: 0.15)
                  : c.borderSoft,
              // 🔧 عکسِ پروفایل — اگر برایِ این کاربر پیدا شد (فقط
              // کاربرانِ فعال، طبقِ محدودیتِ API)، وگرنه حرفِ اول
              foregroundImage: _avatarUrls.containsKey((u['id'] as num).toInt())
                  ? NetworkImage(
                      '${ApiClient.baseUrl}/${_avatarUrls[(u['id'] as num).toInt()]}',
                    )
                  : null,
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: TextStyle(
                  color: isActive ? c.primary : c.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'بدون نام' : name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: c.textStrong,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _tag(c, _roleLabels[role] ?? role, c.primary),
                      _tag(
                        c,
                        _sectionLabel(u['activity_section']?.toString()),
                        c.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // 🔧 طبق درخواست: سوئیچ کنارِ سطلِ آشغال (نه بالا/پایینِ هم)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSwitch(
                  value: isActive,
                  onChanged: (_) => _toggleStatus(u),
                  activeColor: c.primary,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _delete(u),
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
          ],
        ),
      ),
    );
  }

  Widget _tag(AppColors c, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// شیتِ ساخت/ویرایشِ کاربر — اطلاعاتِ پایه + (فقط در ویرایش) شیفت‌کاری،
/// حقوق و سلسله‌مراتبِ مدیر، دقیقاً مطابقِ سه‌تبِ فرمِ وب.
class _UserFormSheet extends StatefulWidget {
  final AppColors c;
  final dynamic user; // null یعنی «ساختِ کاربرِ جدید»
  final List<dynamic> allUsers;
  final List<dynamic> sections;
  final String actorRole;
  final VoidCallback onSaved;

  const _UserFormSheet({
    required this.c,
    required this.user,
    required this.allUsers,
    required this.sections,
    required this.actorRole,
    required this.onSaved,
  });

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _salary;
  String? _section;
  late String _role;

  // شیفت‌کاری
  String _shiftType = 'single';
  TimeOfDay? _shift1Start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _shift1End = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay? _shift2Start;
  TimeOfDay? _shift2End;

  // سلسله‌مراتب
  int? _managerId;

  bool _isSaving = false;
  int _tab = 0; // 0=پایه، 1=شیفت/حقوق، 2=سلسله‌مراتب — فقط در ویرایش

  bool get _isEdit => widget.user != null;

  int get _actorRank => _roleRank[widget.actorRole] ?? 0;

  /// نقش‌هایی که از این فرم قابلِ‌انتخاب‌اند — هرچه رتبه‌اش از خودِ actor
  /// بالاتر نرود (دقیقاً همان خطِ قرمزِ سرور در update-user.php)
  List<String> get _assignableRoles => [
    'employee',
    'manager',
    'supervisor',
  ].where((r) => (_roleRank[r] ?? 0) <= _actorRank).toList();

  TimeOfDay? _parseTime(String? v) {
    if (v == null || v.isEmpty) return null;
    final parts = v.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _fmtTime(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _firstName = TextEditingController(
      text: u?['first_name']?.toString() ?? '',
    );
    _lastName = TextEditingController(text: u?['last_name']?.toString() ?? '');
    _phone = TextEditingController(text: u?['phone']?.toString() ?? '');
    _email = TextEditingController(text: u?['email']?.toString() ?? '');
    _password = TextEditingController();
    _section = u?['activity_section']?.toString();
    if (_section == null || _section!.isEmpty) _section = null;
    _role = u?['role']?.toString() ?? 'employee';

    if (_isEdit) {
      _shiftType = u['shift_type']?.toString() ?? 'single';
      _shift1Start =
          _parseTime(u['shift_1_start']?.toString()) ??
          const TimeOfDay(hour: 8, minute: 0);
      _shift1End =
          _parseTime(u['shift_1_end']?.toString()) ??
          const TimeOfDay(hour: 17, minute: 0);
      _shift2Start = _parseTime(u['shift_2_start']?.toString());
      _shift2End = _parseTime(u['shift_2_end']?.toString());
      final rial = u['monthly_salary'];
      final rialNum = rial is num
          ? rial
          : num.tryParse(rial?.toString() ?? '') ?? 0;
      final toman = (rialNum / 10).round();
      _salary = TextEditingController(
        text: toman > 0 ? toPersianDigits(_thousands(toman)) : '',
      );
      _managerId = u['manager_id'] == null
          ? null
          : int.tryParse(u['manager_id'].toString());
    } else {
      _salary = TextEditingController();
    }
  }

  String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  int _dailyWorkHours() {
    int mins(TimeOfDay? s, TimeOfDay? e) {
      if (s == null || e == null) return 0;
      final diff = (e.hour * 60 + e.minute) - (s.hour * 60 + s.minute);
      return diff > 0 ? diff : 0;
    }

    var total = mins(_shift1Start, _shift1End);
    if (_shiftType == 'double') total += mins(_shift2Start, _shift2End);
    return total > 0 ? (total / 60).round() : 0;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      AppSnack.error('خطا', 'نام و نام خانوادگی الزامی است');
      return;
    }
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(_phone.text.trim())) {
      AppSnack.error('خطا', 'شماره موبایل نامعتبر است');
      return;
    }
    if (!_isEdit && _password.text.length < 8) {
      AppSnack.error(
        'خطا',
        'رمز عبور باید حداقل ۸ کاراکتر و شامل حرف و عدد باشد',
      );
      return;
    }
    if (_isEdit && _password.text.isNotEmpty && _password.text.length < 8) {
      AppSnack.error(
        'خطا',
        'رمز عبور باید حداقل ۸ کاراکتر و شامل حرف و عدد باشد',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        final tomanClean = _salary.text.replaceAll(RegExp(r'[^\d]'), '');
        final toman = int.tryParse(tomanClean) ?? 0;
        final res = await ApiClient.dio.post(
          '/api/admin/update-user.php',
          data: {
            'user_id': widget.user['id'],
            'first_name': _firstName.text.trim(),
            'last_name': _lastName.text.trim(),
            'phone': _phone.text.trim(),
            'email': _email.text.trim(),
            'activity_section': _section ?? 'public',
            // همیشه ارسال شود؛ اگر نیاید سرور به employee برمی‌گرداند
            'role': _role,
            if (_password.text.isNotEmpty) 'password': _password.text,
            'shift_type': _shiftType,
            'daily_work_hours': _dailyWorkHours(),
            'shift_1_start': _fmtTime(_shift1Start),
            'shift_1_end': _fmtTime(_shift1End),
            'shift_2_start': _shiftType == 'double'
                ? _fmtTime(_shift2Start)
                : null,
            'shift_2_end': _shiftType == 'double' ? _fmtTime(_shift2End) : null,
            'monthly_salary': toman * 10,
            'manager_id': _managerId,
          },
        );
        final data = res.data;
        if (data['success'] == true) {
          AppSnack.success('✅ ثبت شد', 'اطلاعات کاربر بروزرسانی شد');
          widget.onSaved();
          if (mounted) Navigator.of(context).pop();
        } else {
          AppSnack.error(
            'خطا',
            data['message']?.toString() ?? 'خطا در بروزرسانی',
          );
        }
      } else {
        final phone = _phone.text.trim();
        final res = await ApiClient.dio.post(
          '/api/admin/create-user.php',
          data: {
            // طبق وب: موبایل هم‌زمان نام‌کاربری هم هست
            'username': phone,
            'password': _password.text,
            'phone': phone,
            'first_name': _firstName.text.trim(),
            'last_name': _lastName.text.trim(),
            'activity_section': _section ?? 'public',
            if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
          },
        );
        final data = res.data;
        if (data['success'] == true) {
          AppSnack.success(
            '✅ ثبت شد',
            'کاربر جدید ایجاد شد — شیفت/حقوق/سلسله‌مراتب را از ویرایش تنظیم کنید',
          );
          widget.onSaved();
          if (mounted) Navigator.of(context).pop();
        } else {
          AppSnack.error(
            'خطا',
            data['message']?.toString() ?? 'خطا در ایجاد کاربر',
          );
        }
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  InputDecoration _dec(AppColors c, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
    filled: true,
    fillColor: c.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c.borderSoft),
    ),
  );

  Future<void> _pickTime(bool isStart, {required bool secondShift}) async {
    final current = secondShift
        ? (isStart ? _shift2Start : _shift2End)
        : (isStart ? _shift1Start : _shift1End);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (secondShift) {
        if (isStart) {
          _shift2Start = picked;
        } else {
          _shift2End = picked;
        }
      } else {
        if (isStart) {
          _shift1Start = picked;
        } else {
          _shift1End = picked;
        }
      }
    });
  }

  Widget _timeField(
    AppColors c,
    String label,
    TimeOfDay? value,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.borderSoft),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: c.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : toPersianDigits(_fmtTime(value)!),
                style: TextStyle(
                  fontSize: 13,
                  color: value == null ? c.textMuted : c.textStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    // 🔧 رفعِ باگِ «تا بالای صفحه می‌رود»: Get.bottomSheet خودش (مستقل از
    // isScrollControlled) همیشه دورِ کل محتوا یک Padding(bottom:
    // viewInsets.bottom) می‌کشد؛ اضافه‌کردنِ دوباره‌اش اینجا فاصله را
    // دوبرابر و شیت را تا نزدیکیِ بالای صفحه هل می‌داد
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.borderSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isEdit ? 'ویرایش کاربر' : 'کاربر جدید',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tabChip(c, 0, 'اطلاعات پایه'),
                      const SizedBox(width: 8),
                      _tabChip(c, 1, 'شیفت و حقوق'),
                      const SizedBox(width: 8),
                      _tabChip(c, 2, 'سلسله‌مراتب'),
                    ],
                  ),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: _tab == 0
                        ? _basicTab(c)
                        : _tab == 1
                        ? _shiftTab(c)
                        : _hierarchyTab(c),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    // 🔧 طبق درخواست: تمام‌عرض و هم‌اندازه‌ی دکمه‌ی «ارجاع به ...»
                    width: double.infinity,
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
                          : Text(
                              _isEdit ? 'ذخیره تغییرات' : 'ایجاد کاربر',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _tabChip(AppColors c, int index, String label) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? c.primary : c.borderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _basicTab(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _firstName,
                textAlign: TextAlign.right,
                style: TextStyle(color: c.textStrong),
                decoration: _dec(c, 'نام'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _lastName,
                textAlign: TextAlign.right,
                style: TextStyle(color: c.textStrong),
                decoration: _dec(c, 'نام خانوادگی'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: _dec(
            c,
            _isEdit
                ? 'شماره موبایل'
                : 'شماره موبایل (هم موبایل، هم نام‌کاربری)',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _email,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: _dec(c, 'ایمیل (اختیاری)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password,
          obscureText: true,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: _dec(c, _isEdit ? 'رمز عبور جدید (اختیاری)' : 'رمز عبور'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _section,
          isExpanded: true,
          decoration: _dec(c, 'واحد فعالیت'),
          dropdownColor: c.surface,
          style: TextStyle(color: c.textStrong, fontSize: 14),
          items: [
            const DropdownMenuItem(value: null, child: Text('عمومی')),
            ...widget.sections.map(
              (s) => DropdownMenuItem(
                value: s['section_key']?.toString(),
                child: Text(s['section_label']?.toString() ?? ''),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _section = v),
        ),
        if (!_isEdit) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'پس از ایجاد کاربر، شیفت‌کاری، حقوق، نقش و مدیرِ مستقیم را از «ویرایش» تنظیم کنید.',
              style: TextStyle(fontSize: 11.5, color: c.textMuted),
            ),
          ),
        ],
      ],
    );
  }

  Widget _shiftTab(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _shiftType,
          isExpanded: true,
          decoration: _dec(c, 'نوع شیفت'),
          dropdownColor: c.surface,
          style: TextStyle(color: c.textStrong, fontSize: 14),
          items: const [
            DropdownMenuItem(value: 'single', child: Text('تک شیفت')),
            DropdownMenuItem(value: 'double', child: Text('دو شیفت')),
          ],
          onChanged: (v) => setState(() => _shiftType = v ?? 'single'),
        ),
        const SizedBox(height: 12),
        Text(
          'شیفت اول',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textStrong,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _timeField(
                c,
                'شروع',
                _shift1Start,
                () => _pickTime(true, secondShift: false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _timeField(
                c,
                'پایان',
                _shift1End,
                () => _pickTime(false, secondShift: false),
              ),
            ),
          ],
        ),
        if (_shiftType == 'double') ...[
          const SizedBox(height: 14),
          Text(
            'شیفت دوم',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _timeField(
                  c,
                  'شروع',
                  _shift2Start,
                  () => _pickTime(true, secondShift: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _timeField(
                  c,
                  'پایان',
                  _shift2End,
                  () => _pickTime(false, secondShift: true),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borderSoft),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Text(
                'ساعت کاری روزانه (خودکار)',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
              const Spacer(),
              Text(
                toPersianDigits('${_dailyWorkHours()} ساعت'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'حقوق ماهانه',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textStrong,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _salary,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: _dec(c, 'مبلغ به تومان'),
        ),
      ],
    );
  }

  Widget _hierarchyTab(AppColors c) {
    final eligibleManagers = widget.allUsers
        .where(
          (m) =>
              m['id'] != widget.user['id'] &&
              _roleRank.containsKey(m['role']?.toString()) &&
              (_roleRank[m['role']?.toString()] ?? 0) >= 1,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'مدیر مستقیم',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textStrong,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: _managerId,
          isExpanded: true,
          decoration: _dec(c, '— بدون مدیر —'),
          dropdownColor: c.surface,
          style: TextStyle(color: c.textStrong, fontSize: 14),
          items: [
            const DropdownMenuItem(value: null, child: Text('— بدون مدیر —')),
            ...eligibleManagers.map((m) {
              final n = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'
                  .trim();
              final label = n.isEmpty ? (m['phone']?.toString() ?? '') : n;
              final roleLbl =
                  _roleLabels[m['role']?.toString()] ??
                  m['role']?.toString() ??
                  '';
              return DropdownMenuItem(
                value: int.tryParse(m['id'].toString()),
                child: Text(
                  '$label ($roleLbl)',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (v) => setState(() => _managerId = v),
        ),
        const SizedBox(height: 16),
        Text(
          'نقش',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.textStrong,
          ),
        ),
        const SizedBox(height: 8),
        if (_assignableRoles.contains(_role) || _assignableRoles.length > 1)
          DropdownButtonFormField<String>(
            initialValue: _assignableRoles.contains(_role) ? _role : null,
            isExpanded: true,
            decoration: _dec(c, 'نقش'),
            dropdownColor: c.surface,
            style: TextStyle(color: c.textStrong, fontSize: 14),
            items: _assignableRoles
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(_roleLabels[r] ?? r),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _role = v ?? _role),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.borderSoft),
            ),
            child: Text(
              'نقش فعلی: ${_roleLabels[_role] ?? _role} — با دسترسیِ شما قابلِ‌تغییر نیست',
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          ),
      ],
    );
  }
}
