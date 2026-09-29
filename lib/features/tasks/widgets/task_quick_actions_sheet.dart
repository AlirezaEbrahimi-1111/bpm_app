import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_number.dart';
import 'persian_date_picker_sheet.dart';

/// منوی «عملیات» روی سه‌نقطه‌ی هر ردیفِ کار در لیست‌ها (داشبورد،
/// کارها، واگذارشده) — به‌جای رفتنِ مستقیم به جزئیاتِ کار.
///
/// منطقِ نمایشِ اکشن‌ها دقیقاً هم‌راستا با نسخه‌ی وب است
/// (تابعِ pmActions در pages/dashboard-user.php):
/// - کارِ پایان‌یافته/حذف‌شده → بدون اکشن
/// - در انتظارِ تأییدِ من (pending_approval و مسئول=من) → تأیید/رد
/// - مسئولِ من (نه در انتظارِ تأیید) → ارجاع/تمدید موعد
/// - در غیرِ این‌ها (فقط ناظر) → بدون اکشن
bool _isTerminal(dynamic t) {
  final status = t['status'];
  return t['is_deleted'] == 1 ||
      const ['completed', 'approved', 'stopped', 'rejected'].contains(status);
}

/// عمومی شد چون در مودال‌های «برنامه‌ی فردا/هفته/ماه» هم برای اولویتِ
/// مرتب‌سازی (کارهایِ منتظرِ اقدام بالاتر) لازم است
List<String> quickActionsFor(dynamic task, int currentUserId) {
  if (_isTerminal(task)) return [];
  final assigneeId = int.tryParse(task['assignee_id']?.toString() ?? '');
  if (task['status'] == 'pending_approval' && assigneeId == currentUserId) {
    return ['approve', 'reject'];
  }
  if (assigneeId != null && assigneeId == currentUserId) {
    return ['delegate', 'extend'];
  }
  return [];
}

void showTaskQuickActionsSheet(
  BuildContext context, {
  required dynamic task,
  required VoidCallback onChanged,
}) {
  final currentUserId = ApiClient.currentUserId ?? -1;
  final actions = quickActionsFor(task, currentUserId);
  final c = AppColors.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuickActionsSheet(
      task: task,
      actions: actions,
      c: c,
      onChanged: onChanged,
    ),
  );
}

class _QuickActionsSheet extends StatelessWidget {
  final dynamic task;
  final List<String> actions;
  final AppColors c;
  final VoidCallback onChanged;

  const _QuickActionsSheet({
    required this.task,
    required this.actions,
    required this.c,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
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
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                (task['title'] ?? '').toString(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: c.textStrong,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (actions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 20,
                ),
                child: Text(
                  'عملیاتی موجود نیست',
                  style: TextStyle(color: c.textMuted, fontSize: 13),
                ),
              )
            else ...[
              if (actions.contains('approve'))
                _tile(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  label: 'تأیید',
                  color: c.success,
                  onTap: () => _approve(context),
                ),
              if (actions.contains('reject'))
                _tile(
                  context,
                  icon: Icons.cancel_outlined,
                  label: 'رد',
                  color: c.danger,
                  onTap: () => _showReject(context),
                ),
              if (actions.contains('delegate'))
                _tile(
                  context,
                  icon: Icons.send_outlined,
                  label: 'ارجاع',
                  color: c.primary,
                  onTap: () => _showDelegate(context),
                ),
              if (actions.contains('extend'))
                _tile(
                  context,
                  icon: Icons.calendar_month_outlined,
                  label: 'تمدید موعد',
                  color: c.primary,
                  onTap: () => _showExtend(context),
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: c.textStrong,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  int get _taskId => int.tryParse(task['id'].toString()) ?? 0;

  Future<void> _approve(BuildContext context) async {
    Navigator.of(context).pop();
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve.php',
        data: {'task_id': _taskId, 'approve': true},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        onChanged();
        AppSnack.success('✅ تأیید شد', data['message'] ?? '');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تأیید');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _showReject(BuildContext context) {
    Navigator.of(context).pop();
    final controller = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رد کار', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'دلیل رد (الزامی)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('انصراف')),
          TextButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                AppSnack.error('خطا', 'لطفاً دلیل رد را بنویسید');
                return;
              }
              Get.back();
              try {
                final res = await ApiClient.dio.post(
                  '/api/tasks/approve.php',
                  data: {'task_id': _taskId, 'approve': false, 'notes': reason},
                );
                final data = ApiClient.parseResponse(res.data);
                if (data['success'] == true) {
                  onChanged();
                  AppSnack.warning('رد شد', data['message'] ?? '');
                } else {
                  AppSnack.error('خطا', data['message'] ?? 'خطا در رد کار');
                }
              } catch (_) {
                AppSnack.error('خطا', 'خطا در اتصال به سرور');
              }
            },
            child: Text('رد کردن', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  void _showDelegate(BuildContext context) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _DelegateSheet(taskId: _taskId, c: c, onChanged: onChanged),
    );
  }

  void _showExtend(BuildContext context) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExtendSheet(taskId: _taskId, c: c, onChanged: onChanged),
    );
  }
}

class _DelegateSheet extends StatefulWidget {
  final int taskId;
  final AppColors c;
  final VoidCallback onChanged;
  const _DelegateSheet({
    required this.taskId,
    required this.c,
    required this.onChanged,
  });

  @override
  State<_DelegateSheet> createState() => _DelegateSheetState();
}

class _DelegateSheetState extends State<_DelegateSheet> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _query = '';
  bool _isSubmitting = false;
  dynamic _selectedUser;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.dio.get('/api/users/list.php');
      if (res.data['success'] == true) {
        final all = res.data['users'] as List? ?? [];
        _users = all.where((u) => u['id'] != ApiClient.currentUserId).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _userLabel(dynamic u) {
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
  }

  Future<void> _delegate(dynamic user) async {
    setState(() => _isSubmitting = true);
    final notes = _notesController.text.trim();
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/delegate.php',
        data: {
          'task_id': widget.taskId,
          'to_user_id': user['id'],
          if (notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (data['success'] == true) {
        widget.onChanged();
        AppSnack.success('✅ موفق', data['message'] ?? 'کار ارجاع شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ارجاع کار');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _users
        : _users.where((u) => _userLabel(u).toLowerCase().contains(q)).toList();

    final mq = MediaQuery.of(context);
    final selectedLabel = _selectedUser == null
        ? null
        : _userLabel(_selectedUser);

    // 🔧 طبق درخواست: انتخابِ کاربر فقط او را علامت می‌زند (دیگر فوراً
    // ارجاع نمی‌دهد)؛ زیرِ لیست فیلدِ توضیحات و دکمه‌ی «ارجاع به <نام>»
    // می‌آید و تا دکمه زده نشود ارجاعی انجام نمی‌شود. ارتفاعِ کل سقف‌دار
    // است (مثلِ شیتِ ارجاعِ صفحه‌ی جزئیات) تا با صفحه‌کلید سرریز نکند.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
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
            const SizedBox(height: 16),
            Text(
              'ارجاع کار به',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: c.textStrong,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: c.textStrong, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'جستجوی نام...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: c.textMuted,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.borderSoft),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: c.primary))
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'کاربری یافت نشد',
                        style: TextStyle(color: c.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        final label = _userLabel(u);
                        final selected =
                            _selectedUser != null &&
                            _selectedUser['id'] == u['id'];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: selected
                                ? c.primary
                                : c.primary.withValues(alpha: 0.1),
                            child: Text(
                              label.isNotEmpty ? label[0] : '?',
                              style: TextStyle(
                                color: selected ? Colors.white : c.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            label,
                            style: TextStyle(fontSize: 14, color: c.textStrong),
                          ),
                          trailing: selected
                              ? Icon(Icons.check_circle, color: c.primary)
                              : null,
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _selectedUser = u),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _notesController,
                textAlign: TextAlign.right,
                style: TextStyle(color: c.textStrong, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'توضیحات (اختیاری)...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.borderSoft),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (_selectedUser == null || _isSubmitting)
                      ? null
                      : () => _delegate(_selectedUser),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    disabledBackgroundColor: c.primary.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          selectedLabel == null
                              ? 'ارجاع'
                              : 'ارجاع به $selectedLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtendSheet extends StatefulWidget {
  final int taskId;
  final AppColors c;
  final VoidCallback onChanged;
  const _ExtendSheet({
    required this.taskId,
    required this.c,
    required this.onChanged,
  });

  @override
  State<_ExtendSheet> createState() => _ExtendSheetState();
}

class _ExtendSheetState extends State<_ExtendSheet> {
  DateTime? _newDate;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  String _toShamsiText(DateTime d) {
    // 🔧 انتخابگر تاریخِ میلادی برمی‌گرداند (برای ارسال به سرور)؛ فقط نمایش
    // باید شمسی باشد
    final j = Jalali.fromDateTime(d);
    return toPersianDigits(
      '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _pickDate() async {
    final d = await showCustomPersianDatePicker(context);
    if (d != null) setState(() => _newDate = d);
  }

  Future<void> _submit() async {
    if (_newDate == null) {
      AppSnack.error('خطا', 'لطفاً موعد جدید را انتخاب کنید');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      AppSnack.error('خطا', 'لطفاً دلیل تمدید را بنویسید');
      return;
    }
    setState(() => _isSubmitting = true);
    final dateStr =
        '${_newDate!.year.toString().padLeft(4, '0')}-${_newDate!.month.toString().padLeft(2, '0')}-${_newDate!.day.toString().padLeft(2, '0')}';
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/request-deadline.php',
        data: {
          'task_id': widget.taskId,
          'new_deadline': dateStr,
          'reason': reason,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (data['success'] == true) {
        widget.onChanged();
        AppSnack.success(
          '✅ ثبت شد',
          data['message'] ?? 'درخواست تمدید موعد ثبت شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ثبت درخواست');
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        // 🔧 فاصله‌ی دکمه‌های ناوبریِ گوشی (safe-area) اضافه شد تا «ثبت درخواست» پشتِ آن‌ها نرود
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
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
              'تمدید موعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: c.textStrong,
              ),
            ),
            const SizedBox(height: 16),
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
                      color: _newDate != null ? c.primary : c.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _newDate != null
                            ? _toShamsiText(_newDate!)
                            : 'انتخاب موعد جدید',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          color: _newDate != null ? c.textStrong : c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              textAlign: TextAlign.right,
              style: TextStyle(color: c.textStrong, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'دلیل تمدید (الزامی)',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.borderSoft),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ثبت درخواست',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
