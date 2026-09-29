import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_snack.dart';

/// شیتِ «مدیریتِ واحدهایِ فعالیت» — پورتِ pages/activity_section_managment.php
/// برایِ موبایل. همان API نسخه‌ی وب:
///   GET    /api/organization/activity-sections.php  (لیست — بدونِ نیازِ مجوزِ خاص)
///   POST   همان آدرس، {section_key, section_label, sort_order}  (افزودن/ویرایشِ برچسب — نیازِ مجوزِ manage_activity_sections)
///   DELETE همان آدرس، {section_key, transfer_to}  (حذف + انتقالِ کاربرانِ همان واحد)
Future<void> showManageActivitySectionsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ManageSectionsSheet(),
  );
}

class _ManageSectionsSheet extends StatefulWidget {
  const _ManageSectionsSheet();

  @override
  State<_ManageSectionsSheet> createState() => _ManageSectionsSheetState();
}

class _ManageSectionsSheetState extends State<_ManageSectionsSheet> {
  List<dynamic> _sections = [];
  bool _isLoading = true;
  String? _error;

  final _keyController = TextEditingController();
  final _labelController = TextEditingController();
  String? _addError;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/api/organization/activity-sections.php',
      );
      final data = res.data;
      if (data['success'] == true) {
        setState(() {
          _sections = data['sections'] as List? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'خطا در دریافتِ واحدها';
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
    final key = _keyController.text.trim().toLowerCase();
    final label = _labelController.text.trim();
    setState(() => _addError = null);

    if (key.isEmpty || label.isEmpty) {
      setState(() => _addError = 'کلید انگلیسی و نام فارسی الزامی است');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(key)) {
      setState(() => _addError = 'کلید باید فقط شامل حروف کوچک، عدد و _ باشد');
      return;
    }
    if (['management', 'supervisor'].contains(key)) {
      setState(() => _addError = 'این کلید رزرو شده است');
      return;
    }
    if (_sections.any((s) => s['section_key'] == key)) {
      setState(() => _addError = 'این کلید قبلاً وجود دارد');
      return;
    }

    setState(() => _isAdding = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/organization/activity-sections.php',
        data: {
          'section_key': key,
          'section_label': label,
          'sort_order': _sections.length,
        },
      );
      final data = res.data;
      if (data['success'] == true) {
        _keyController.clear();
        _labelController.clear();
        AppSnack.success(
          '✅ افزوده شد',
          data['message']?.toString() ?? 'واحد اضافه شد',
        );
        _load();
      } else {
        setState(
          () => _addError = data['message']?.toString() ?? 'خطا در افزودن',
        );
      }
    } catch (_) {
      setState(() => _addError = 'خطا در اتصال به سرور');
    }
    if (mounted) setState(() => _isAdding = false);
  }

  Future<void> _editLabel(dynamic s) async {
    final c = AppColors.of(context);
    final controller = TextEditingController(
      text: s['section_label']?.toString() ?? '',
    );
    final newLabel = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: c.surface,
        title: Text(
          'ویرایش «${s['section_label']}»',
          style: TextStyle(color: c.textStrong, fontSize: 15),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'نام فارسی',
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
    if (newLabel == null || newLabel.isEmpty) return;
    try {
      final res = await ApiClient.dio.post(
        '/api/organization/activity-sections.php',
        data: {
          'section_key': s['section_key'],
          'section_label': newLabel,
          'sort_order': s['sort_order'] ?? 0,
        },
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success('✅ ثبت شد', 'نام واحد بروزرسانی شد');
        _load();
      } else {
        AppSnack.error(
          'خطا',
          data['message']?.toString() ?? 'خطا در بروزرسانی',
        );
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _confirmDelete(dynamic s) async {
    final c = AppColors.of(context);
    final others = _sections
        .where((x) => x['section_key'] != s['section_key'])
        .toList();
    String transferTo = 'management';

    final confirmed = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: c.surface,
          title: Text(
            'حذف «${s['section_label']}»',
            style: TextStyle(color: c.textStrong, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اگر کاربری در این واحد باشد، به واحد زیر منتقل می‌شود.',
                style: TextStyle(color: c.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: transferTo,
                isExpanded: true,
                dropdownColor: c.surface,
                style: TextStyle(color: c.textStrong, fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'management',
                    child: Text('مدیریت (management)'),
                  ),
                  ...others.map(
                    (o) => DropdownMenuItem(
                      value: o['section_key']?.toString(),
                      child: Text(
                        '${o['section_label']} (${o['section_key']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) =>
                    setSheetState(() => transferTo = v ?? 'management'),
              ),
            ],
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
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await ApiClient.dio.delete(
        '/api/organization/activity-sections.php',
        data: {'section_key': s['section_key'], 'transfer_to': transferTo},
      );
      final data = res.data;
      if (data['success'] == true) {
        AppSnack.success(
          '🗑️ حذف شد',
          data['message']?.toString() ?? 'واحد حذف شد',
        );
        _load();
      } else {
        AppSnack.error('خطا', data['message']?.toString() ?? 'خطا در حذف واحد');
      }
    } catch (_) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
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
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.94,
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
              Text(
                'مدیریت واحدهای فعالیت',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: c.textStrong,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      Text(
                        'افزودن واحد جدید',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.textStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _keyController,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: c.textStrong, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'کلید انگلیسی — مثال: logistics',
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 12.5,
                          ),
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
                          hintText: 'نام فارسی — مثال: لجستیک',
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 12.5,
                          ),
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
                      if (_addError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _addError!,
                          style: TextStyle(color: c.danger, fontSize: 11.5),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _isAdding ? null : _add,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            _isAdding ? 'در حال افزودن...' : 'افزودن',
                          ),
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
                    : _sections.isEmpty
                    ? Center(
                        child: Text(
                          'هنوز واحدی ساخته نشده',
                          style: TextStyle(color: c.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _sections.length,
                        itemBuilder: (ctx, i) {
                          final s = _sections[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: c.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Icon(
                                Icons.account_tree_outlined,
                                size: 16,
                                color: c.primary,
                              ),
                            ),
                            title: Text(
                              s['section_label']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textStrong,
                              ),
                            ),
                            subtitle: Text(
                              s['section_key']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textMuted,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: c.textMuted,
                                  ),
                                  onPressed: () => _editLabel(s),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: c.danger,
                                  ),
                                  onPressed: () => _confirmDelete(s),
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
      ),
    );
  }
}
