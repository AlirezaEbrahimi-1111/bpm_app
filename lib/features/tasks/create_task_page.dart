import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/network/api_client.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import '../../core/utils/persian_number.dart';

class CreateTaskPage extends StatefulWidget {
  final String userRole;
  final int? currentUserId;
  const CreateTaskPage({super.key, this.userRole = '', this.currentUserId});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  static const _primary = Color(0xFF6D28D9);

  // فیلدهای اصلی
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _taskType = 'periodic'; // periodic | continuous
  String _priority = 'medium';
  String _periodType = 'daily';

  DateTime? _dueDate;
  DateTime? _startDate;
  DateTime? _endDate;
  // گروه‌ها
  List<dynamic> _groups = [];
  int? _selectedGroupId;
  String _groupLabel = 'بدون گروه';
  bool _showMore = false;
  bool _isLoading = false;
  // چک‌لیست
  final List<String> _checklistItems = [];
  final _checklistController = TextEditingController();
  // لیست همکاران
  // داده‌های assignee
  List<dynamic> _users = [];
  List<dynamic> _sections = [];
  String _myRole = '';
  bool get _isSupervisor => _myRole == 'supervisor';
  // فایل‌های پیوست (موقت تا قبل از ساخت کار)
  final List<PlatformFile> _pickedFiles = [];
  // انتخاب فعلی: نوع و مقدار
  // type: 'self' | 'user' | 'section' | 'all_users' | 'all_sections'
  String _assigneeType = 'self';
  dynamic _assigneeValue; // id کاربر یا section_key
  String _assigneeLabel = 'خودم';

  @override
  void initState() {
    super.initState();
    _loadAssigneeData();
  }

  Future<void> _loadAssigneeData() async {
    _myRole = widget.userRole;

    try {
      final r = await ApiClient.dio.get(
        '/api/organization/activity-sections.php',
      );
      if (r.data['success'] == true) _sections = r.data['sections'] ?? [];
    } catch (_) {}

    try {
      final r = await ApiClient.dio.get('/api/users/list.php');
      if (r.data['success'] == true) {
        final all = r.data['users'] as List? ?? [];
        // حذف کاربر جاری از لیست
        _users = all.where((u) => u['id'] != widget.currentUserId).toList();
      }
    } catch (_) {}
    try {
      final r = await ApiClient.dio.get('/api/task-groups/list-all.php');
      if (r.data['success'] == true) {
        final all = r.data['groups'] as List? ?? [];
        _groups = all.where((g) {
          if (g['scope'] == 'org') return true;
          return g['created_by']?.toString() == widget.currentUserId.toString();
        }).toList();
      }
    } catch (_) {}

    setState(() {});
  }

  // ── تبدیل DateTime به رشته میلادی ─────────────────
  String _toApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── نمایش تاریخ شمسی ──────────────────────────────
  String _toShamsi(DateTime d) {
    final j = Jalali.fromDateTime(d);
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
  }

  // ── انتخاب تاریخ ──────────────────────────────────
  Future<DateTime?> _pickDate({DateTime? initial}) async {
    Jalali? picked = await showPersianDatePicker(
      context: context,
      initialDate: initial != null
          ? Jalali.fromDateTime(initial)
          : Jalali.now(),
      firstDate: Jalali(1400, 1),
      lastDate: Jalali(1410, 12),
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: Localizations.override(
          context: ctx,
          locale: const Locale('fa', 'IR'),
          child: Theme(
            data: Theme.of(
              ctx,
            ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
            child: child!,
          ),
        ),
      ),
    );
    return picked?.toDateTime();
  }

  // ── ارسال فرم ─────────────────────────────────────
  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      Get.snackbar(
        'خطا',
        'عنوان کار الزامی است',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }
    if (_taskType == 'periodic' && _dueDate == null) {
      Get.snackbar(
        'خطا',
        'تاریخ انجام الزامی است',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }
    if (_taskType == 'continuous' && _startDate == null) {
      Get.snackbar(
        'خطا',
        'تاریخ شروع الزامی است',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    setState(() => _isLoading = true);

    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'task_type': _taskType,
      'priority': _priority,
    };

    if (_descController.text.trim().isNotEmpty) {
      body['description'] = _descController.text.trim();
    }

    if (_assigneeType == 'user' && _assigneeValue != null) {
      body['assignee_id'] = _assigneeValue;
    }
    if (_selectedGroupId != null) {
      body['group_id'] = _selectedGroupId;
    }
    if (_taskType == 'periodic' && _dueDate != null) {
      body['due_date'] = _toApiDate(_dueDate!);
    }
    if (_taskType == 'continuous') {
      if (_startDate != null) body['start_date'] = _toApiDate(_startDate!);
      if (_endDate != null) body['end_date'] = _toApiDate(_endDate!);
      body['period_type'] = _periodType;
    }

    try {
      final res = await ApiClient.dio.post('/api/tasks/create.php', data: body);
      setState(() => _isLoading = false);

      if (res.data['success'] == true) {
        final newTaskId = res.data['task_id'];
        // ذخیره چک‌لیست اگر آیتمی هست
        if (newTaskId != null && _checklistItems.isNotEmpty) {
          await _saveChecklist(newTaskId);
        }
        // آپلود فایل‌ها اگر هست
        if (newTaskId != null && _pickedFiles.isNotEmpty) {
          await _uploadFiles(newTaskId);
        }
        Get.back(result: true);
        Get.snackbar(
          '✅ موفق',
          'کار با موفقیت ایجاد شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          res.data['message'] ?? 'خطا در ایجاد کار',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Create error: $e');
      if (e is dio.DioException) {
        print('📋 Response: ${e.response?.data}');
      }
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _pickedFiles.add(result.files.first));
      }
    } catch (_) {
      Get.snackbar(
        'خطا',
        'خطا در انتخاب فایل',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _uploadFiles(dynamic taskId) async {
    for (final file in _pickedFiles) {
      try {
        final formData = dio.FormData.fromMap({
          'task_id': taskId,
          'file': dio.MultipartFile.fromBytes(file.bytes!, filename: file.name),
        });
        await ApiClient.dio.post(
          '/api/tasks/upload-attachment.php',
          data: formData,
        );
      } catch (_) {
        // خطا در یک فایل نباید بقیه را متوقف کند
      }
    }
  }

  void _addChecklistItem() {
    final text = _checklistController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklistItems.add(text);
      _checklistController.clear();
    });
  }

  Future<void> _saveChecklist(dynamic taskId) async {
    try {
      await ApiClient.dio.post(
        '/api/checklist/save.php',
        data: {
          'task_id': taskId,
          'items': _checklistItems
              .asMap()
              .entries
              .map((e) => {'title': e.value, 'sort_order': e.key})
              .toList(),
        },
      );
    } catch (e) {
      // خطا در چک‌لیست نباید کل کار را متوقف کند
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'کار جدید',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── کارت اصلی ──────────────────────────────
            _card(
              children: [
                // عنوان
                _label('عنوان کار *'),
                _textField(_titleController, 'مثال: پیگیری قرارداد'),
                const SizedBox(height: 16),

                // نوع کار
                _label('نوع کار'),
                _segmented(),
                const SizedBox(height: 16),

                // اولویت
                _label('اولویت'),
                _prioritySelector(),
              ],
            ),
            const SizedBox(height: 12),

            // ── کارت تاریخ ─────────────────────────────
            _card(
              children: [
                if (_taskType == 'periodic') ...[
                  _label('تاریخ انجام *'),
                  _dateTile(
                    icon: Icons.event_rounded,
                    value: _dueDate != null ? _toShamsi(_dueDate!) : null,
                    hint: 'انتخاب تاریخ',
                    onTap: () async {
                      final d = await _pickDate();
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ] else ...[
                  // تاریخ شروع و پایان در یک ردیف
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('تاریخ شروع *'),
                            _dateTile(
                              icon: Icons.play_circle_outline_rounded,
                              value: _startDate != null
                                  ? _toShamsi(_startDate!)
                                  : null,
                              hint: 'شروع',
                              onTap: () async {
                                final d = await _pickDate();
                                if (d != null) setState(() => _startDate = d);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('تاریخ پایان'),
                            _dateTile(
                              icon: Icons.event_busy_rounded,
                              value: _endDate != null
                                  ? _toShamsi(_endDate!)
                                  : null,
                              hint: 'اختیاری',
                              onTap: () async {
                                final d = await _pickDate();
                                if (d != null) setState(() => _endDate = d);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _label('دوره تکرار'),
                  _periodSelector(),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── جزئیات بیشتر ───────────────────────────
            GestureDetector(
              onTap: () => setState(() => _showMore = !_showMore),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _showMore ? Icons.remove : Icons.add,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _showMore ? 'بستن جزئیات' : 'جزئیات بیشتر',
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showMore) ...[
              const SizedBox(height: 12),
              _card(
                children: [
                  // توضیحات
                  _label('توضیحات'),
                  _textField(
                    _descController,
                    'توضیحات اختیاری...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // مسئول
                  _label('مسئول کار'),
                  _assigneePicker(),
                  const SizedBox(height: 16),
                  // گروه
                  _label('گروه'),
                  _groupPicker(),
                ],
              ),
              const SizedBox(height: 12),
              _card(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.checklist_rounded,
                        size: 18,
                        color: _primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'چک‌لیست',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      if (_checklistItems.isNotEmpty)
                        Text(
                          '${_checklistItems.length} آیتم',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // آیتم‌های اضافه‌شده
                  ..._checklistItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final text = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.radio_button_unchecked,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _checklistItems.removeAt(i)),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // فیلد افزودن آیتم
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _checklistController,
                          decoration: InputDecoration(
                            hintText: 'افزودن آیتم جدید...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F6FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _addChecklistItem(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _addChecklistItem,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _card(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'پیوست فایل',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const Spacer(),
                    if (_pickedFiles.isNotEmpty)
                      Text(
                        '${_pickedFiles.length} فایل',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // فایل‌های انتخاب‌شده
                ..._pickedFiles.asMap().entries.map((entry) {
                  final i = entry.key;
                  final file = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            file.name,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _pickedFiles.removeAt(i)),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // دکمه افزودن فایل
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add, size: 18, color: _primary),
                        SizedBox(width: 6),
                        Text(
                          'انتخاب فایل',
                          style: TextStyle(
                            fontSize: 13,
                            color: _primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),

      // ── دکمه ثبت ───────────────────────────────────
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ثبت کار',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── ویجت‌های کمکی ─────────────────────────────────

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF555570),
      ),
    ),
  );

  Widget _textField(TextEditingController c, String hint, {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF5F6FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      );

  Widget _segmented() => Row(
    children: [
      _typeBtn('مقطعی', 'periodic', Icons.event_note_rounded),
      const SizedBox(width: 10),
      _typeBtn('دوره‌ای', 'continuous', Icons.repeat_rounded),
    ],
  );

  Widget _typeBtn(String label, String val, IconData icon) {
    final selected = _taskType == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _taskType = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _primary : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prioritySelector() => Row(
    children: [
      _prioBtn('بالا', 'high', const Color(0xFFEF4444)),
      const SizedBox(width: 8),
      _prioBtn('متوسط', 'medium', const Color(0xFFF59E0B)),
      const SizedBox(width: 8),
      _prioBtn('پایین', 'low', const Color(0xFF22C55E)),
    ],
  );

  Widget _prioBtn(String label, String val, Color color) {
    final selected = _priority == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? color : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _periodSelector() => Row(
    children: [
      _periodBtn('روزانه', 'daily'),
      const SizedBox(width: 8),
      _periodBtn('هفتگی', 'weekly'),
      const SizedBox(width: 8),
      _periodBtn('ماهانه', 'monthly'),
    ],
  );

  Widget _periodBtn(String label, String val) {
    final selected = _periodType == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _periodType = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? _primary.withValues(alpha: 0.1)
                : const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: _primary, width: 1.5) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? _primary : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required IconData icon,
    String? value,
    required String hint,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value != null ? _primary : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            value ?? hint,
            style: TextStyle(
              fontSize: 13,
              color: value != null
                  ? const Color(0xFF1A1A2E)
                  : Colors.grey.shade400,
            ),
          ),
          const Spacer(),
          if (value != null)
            Icon(Icons.check_circle_rounded, color: _primary, size: 18),
        ],
      ),
    ),
  );
  Color _parseGroupColor(String? hex) {
    if (hex == null || hex.isEmpty) return _primary;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _primary;
    }
  }

  Widget _groupPicker() {
    final hasSelection = _selectedGroupId != null;
    // رنگ گروه انتخاب‌شده
    Color dotColor = Colors.grey.shade400;
    if (hasSelection) {
      final g = _groups.firstWhere(
        (e) => e['id'] == _selectedGroupId,
        orElse: () => null,
      );
      if (g != null) dotColor = _parseGroupColor(g['color']);
    }

    return GestureDetector(
      onTap: _showGroupSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (hasSelection)
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(
                Icons.folder_outlined,
                color: Colors.grey.shade400,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _groupLabel,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasSelection)
              GestureDetector(
                onTap: () => setState(() {
                  _selectedGroupId = null;
                  _groupLabel = 'بدون گروه';
                }),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              )
            else
              Icon(
                Icons.expand_more_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showGroupSheet() {
    if (_groups.isEmpty) {
      Get.snackbar(
        'توجه',
        'گروهی تعریف نشده است',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'انتخاب گروه',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.block,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  title: const Text('بدون گروه'),
                  onTap: () {
                    setState(() {
                      _selectedGroupId = null;
                      _groupLabel = 'بدون گروه';
                    });
                    Get.back();
                  },
                ),
                ..._groups.map((g) {
                  final color = _parseGroupColor(g['color']);
                  return ListTile(
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(g['name'] ?? ''),
                    onTap: () {
                      setState(() {
                        _selectedGroupId = g['id'];
                        _groupLabel = g['name'] ?? '';
                      });
                      Get.back();
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _assigneePicker() {
    final hasSelection = _assigneeType != 'self';
    return GestureDetector(
      onTap: _showAssigneeSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              color: hasSelection ? _primary : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _assigneeLabel,
                style: TextStyle(fontSize: 13, color: const Color(0xFF1A1A2E)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showAssigneeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'انتخاب مسئول',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // خودم
                  _assigneeTile(
                    icon: Icons.person,
                    color: Colors.grey,
                    label: 'خودم',
                    onTap: () => _selectAssignee('self', null, 'خودم'),
                  ),

                  // ── واحدها (فقط supervisor) ──
                  // ── واحدها (برای همه) ──
                  if (_sections.isNotEmpty) ...[
                    _sheetHeader('📁 واحدها'),
                    // «همه واحدها» فقط supervisor
                    if (_isSupervisor)
                      _assigneeTile(
                        icon: Icons.groups,
                        color: const Color(0xFF6B21A8),
                        label: 'همه واحدها',
                        meta: '${_users.length} نفر — یک تسک برای هر نفر',
                        onTap: () => _selectAssignee(
                          'all_sections',
                          '__all__',
                          'همه واحدها',
                        ),
                      ),
                    ..._sections.map((s) {
                      final key = s['section_key'];
                      final label = s['section_label'] ?? key;
                      final count = _users
                          .where((u) => u['activity_section'] == key)
                          .length;
                      return _assigneeTile(
                        icon: Icons.folder_outlined,
                        color: const Color(0xFF854D0E),
                        label: label,
                        meta: count > 0 ? '$count نفر' : 'بدون عضو',
                        onTap: () => _selectAssignee('section', key, label),
                      );
                    }),
                  ],

                  // ── کاربران ──
                  _sheetHeader('👤 کاربران'),
                  if (_isSupervisor)
                    _assigneeTile(
                      icon: Icons.people,
                      color: const Color(0xFF6B21A8),
                      label: 'همه کاربران',
                      meta: '${_users.length} نفر — یک تسک برای هر نفر',
                      onTap: () => _selectAssignee(
                        'all_users',
                        '__all_users__',
                        'همه کاربران',
                      ),
                    ),
                  ..._users.map((u) {
                    final name =
                        '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                            .trim();
                    final display = name.isEmpty
                        ? (u['phone'] ?? 'بدون نام')
                        : name;
                    return _assigneeTile(
                      avatar: display.toString().isNotEmpty
                          ? display.toString()[0]
                          : '?',
                      label: display,
                      onTap: () => _selectAssignee('user', u['id'], display),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAssignee(String type, dynamic value, String label) {
    setState(() {
      _assigneeType = type;
      _assigneeValue = value;
      _assigneeLabel = label;
    });
    Get.back();
  }

  Widget _sheetHeader(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    color: const Color(0xFFF5F6FA),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
      ),
    ),
  );

  Widget _assigneeTile({
    IconData? icon,
    Color? color,
    String? avatar,
    required String label,
    String? meta,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: avatar != null
          ? CircleAvatar(
              radius: 16,
              backgroundColor: _primary.withValues(alpha: 0.1),
              child: Text(
                avatar,
                style: const TextStyle(color: _primary, fontSize: 13),
              ),
            )
          : CircleAvatar(
              radius: 16,
              backgroundColor: (color ?? Colors.grey).withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: meta != null
          ? Text(
              meta,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            )
          : null,
      onTap: onTap,
    );
  }
}
