import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/task_group_style.dart';

/// شیتِ «مدیریتِ گروه‌های کار» — CRUD کامل (نام/رنگ/آیکون/دامنه)، دقیقاً
/// معادلِ `pages/group-management.php` در دسکتاپ. خودش لیستش را از
/// `list-all.php` می‌گیرد (این endpoint فقط به کاربرِ دارایِ مجوزِ
/// manage_task_groups پاسخ می‌دهد — اگر کاربر این مجوز را نداشته باشد،
/// پیامِ ۴۰۳ سرور مستقیم نمایش داده می‌شود).
///
/// [onChanged] بعد از هر تغییرِ واقعی (افزودن/ویرایش/حذف) صدا زده
/// می‌شود تا صفحه‌ی فراخوان (که خودش با `list.php` کار می‌کند) فهرستِ
/// گروه‌هایش را دوباره بگیرد.
Future<void> showTaskGroupManagementSheet(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskGroupManagementSheet(onChanged: onChanged),
  );
}

class _TaskGroupManagementSheet extends StatefulWidget {
  final VoidCallback onChanged;
  const _TaskGroupManagementSheet({required this.onChanged});

  @override
  State<_TaskGroupManagementSheet> createState() =>
      _TaskGroupManagementSheetState();
}

class _TaskGroupManagementSheetState extends State<_TaskGroupManagementSheet> {
  List<dynamic> _groups = [];
  bool _isLoading = true;
  String? _error;

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
      final res = await ApiClient.dio.get('/api/task-groups/list-all.php');
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _groups = data['groups'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = (data['message'] ?? 'خطا در دریافت گروه‌ها').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'خطا در اتصال به سرور';
      // پیام واقعی سرور (مثلاً ۴۰۳ «دسترسی غیرمجاز») نمایش داده شود
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['message'] != null)
          msg = data['message'].toString();
      } catch (_) {}
      setState(() {
        _error = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _delete(Map group) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/task-groups/delete.php',
        data: {'id': group['id']},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        widget.onChanged();
        _load();
        AppSnack.success('✅ حذف شد', data['message'] ?? 'گروه حذف شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در حذف گروه');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _confirmDelete(Map group) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف گروه',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Text(
          'آیا از حذف گروه «${group['name']}» مطمئن هستید؟ کارهای این گروه بدون‌گروه می‌شوند.',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _delete(group);
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor({Map? group}) async {
    final changed = await Get.bottomSheet<bool>(
      _TaskGroupEditorSheet(group: group),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (changed == true) {
      widget.onChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مدیریت گروه‌ها',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: c.textStrong,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _openEditor(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16, color: c.primary),
                            const SizedBox(width: 4),
                            Text(
                              'گروه جدید',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: c.primary))
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            style: TextStyle(color: c.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _groups.isEmpty
                    ? Center(
                        child: Text(
                          'هنوز گروهی ساخته نشده',
                          style: TextStyle(color: c.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _groups.length,
                        itemBuilder: (ctx, i) {
                          final g = _groups[i];
                          final canEdit = g['can_edit'] == true;
                          final isOrg = g['scope'] == 'org';
                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: parseTaskGroupColor(
                                  g['color'],
                                ).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                taskGroupIconFor(g['icon']),
                                size: 18,
                                color: parseTaskGroupColor(g['color']),
                              ),
                            ),
                            title: Text(
                              g['name'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textStrong,
                              ),
                            ),
                            subtitle: Text(
                              '${isOrg ? 'سازمانی' : 'شخصی'} • ${g['tasks_count'] ?? 0} کار',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textMuted,
                              ),
                            ),
                            trailing: canEdit
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: c.textMuted,
                                        ),
                                        onPressed: () => _openEditor(group: g),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: c.danger,
                                        ),
                                        onPressed: () => _confirmDelete(g),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// فرمِ افزودن/ویرایشِ یک گروه — نام + انتخابِ رنگ (از ۱۰ رنگِ ثابت) +
/// انتخابِ آیکون (از ۱۲ آیکونِ ثابت) + دامنه (شخصی/سازمانی)
class _TaskGroupEditorSheet extends StatefulWidget {
  final Map? group;
  const _TaskGroupEditorSheet({this.group});

  @override
  State<_TaskGroupEditorSheet> createState() => _TaskGroupEditorSheetState();
}

class _TaskGroupEditorSheetState extends State<_TaskGroupEditorSheet> {
  late final TextEditingController _nameController;
  late String _color;
  late String _icon;
  late String _scope;
  bool _isSaving = false;

  bool get _isEdit => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.group?['name']?.toString() ?? '',
    );
    _color = widget.group?['color']?.toString() ?? taskGroupColors.first;
    _icon = widget.group?['icon']?.toString() ?? taskGroupIconKeys.first;
    _scope = widget.group?['scope']?.toString() ?? 'personal';
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnack.error('خطا', 'نام گروه الزامی است');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final res = _isEdit
          ? await ApiClient.dio.post(
              '/api/task-groups/update.php',
              data: {
                'id': widget.group!['id'],
                'name': name,
                'color': _color,
                'icon': _icon,
              },
            )
          : await ApiClient.dio.post(
              '/api/task-groups/create.php',
              data: {
                'name': name,
                'color': _color,
                'icon': _icon,
                'scope': _scope,
              },
            );
      final data = ApiClient.parseResponse(res.data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (data['success'] == true) {
        Get.back(result: true);
        AppSnack.success(
          '✅ موفق',
          data['message'] ??
              (_isEdit ? 'گروه به‌روزرسانی شد' : 'گروه ساخته شد'),
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ذخیره‌سازی');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      String msg = 'خطا در اتصال به سرور';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['message'] != null)
          msg = data['message'].toString();
      } catch (_) {}
      AppSnack.error('خطا', msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 🔧 رفعِ باگِ «تا بالای صفحه می‌رود»: Get.bottomSheet خودش همیشه
    // دورِ کل محتوا یک Padding(bottom: viewInsets.bottom) می‌کشد؛
    // اضافه‌کردنِ دوباره‌اش اینجا فاصله را دوبرابر می‌کرد
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              _isEdit ? 'ویرایش گروه' : 'گروه جدید',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: c.textStrong,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.right,
              style: TextStyle(color: c.textStrong),
              decoration: InputDecoration(
                hintText: 'نام گروه',
                hintStyle: TextStyle(color: c.textMuted),
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.borderSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: c.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('رنگ', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: taskGroupColors.map((clr) {
                final selected = clr == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = clr),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: parseTaskGroupColor(clr),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: c.textStrong, width: 2)
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('آیکون', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: taskGroupIconKeys.map((key) {
                final selected = key == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = key),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? c.primary : c.surface,
                      shape: BoxShape.circle,
                      border: selected ? null : Border.all(color: c.borderSoft),
                    ),
                    child: Icon(
                      taskGroupIconFor(key),
                      size: 17,
                      color: selected ? Colors.white : c.textMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              Text(
                'دامنه',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _scopeChip(c, label: 'شخصی', value: 'personal'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _scopeChip(c, label: 'سازمانی', value: 'org'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'گروه سازمانی برای همه‌ی کاربران سازمان دیده می‌شود؛ فقط مدیران می‌توانند بسازند.',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
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
                    : Text(_isEdit ? 'ذخیره تغییرات' : 'ساخت گروه'),
              ),
            ),
          ],
        ),
    );
  }

  Widget _scopeChip(
    AppColors c, {
    required String label,
    required String value,
  }) {
    final selected = _scope == value;
    return GestureDetector(
      onTap: () => setState(() => _scope = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.primary.withValues(alpha: 0.1) : c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? c.primary : c.borderSoft),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: selected ? c.primary : c.textMuted,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
