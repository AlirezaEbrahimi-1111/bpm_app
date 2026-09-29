import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/network/api_client.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import '../../core/utils/persian_number.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_switch.dart';
import 'widgets/persian_date_picker_sheet.dart';
import 'widgets/task_group_management_sheet.dart';

/// صفحه‌ی «تعریف کار جدید» — طبق طرح ارسالی (روشن + تاریک).
/// 🔧 طبق درخواستِ صریح، ترتیبِ بخش‌ها با خودِ عکس یک تفاوت دارد: چک‌لیست
/// بلافاصله بعد از «عنوان کار» می‌آید (نه پایینِ فرم مثلِ عکس).
class CreateTaskPage extends StatefulWidget {
  final String userRole;
  final int? currentUserId;
  // 🔧 «بازتعریفِ کار» — وقتی از جزئیاتِ یک تسکِ موجود باز می‌شود، این
  // مپ عنوان/توضیح/نوع/اولویت/گروه/چک‌لیست/پیوست‌هایِ تسکِ اصلی را حمل
  // می‌کند تا فرم از قبل پر شود؛ در نهایت هنوز همان create.php صدا زده
  // می‌شود (دقیقاً مثل نسخهٔ دسکتاپ — فیلد ویژه‌ای برایِ «بازتعریف» در
  // بک‌اند وجود ندارد).
  final Map<String, dynamic>? redefineFrom;
  const CreateTaskPage({
    super.key,
    this.userRole = '',
    this.currentUserId,
    this.redefineFrom,
  });

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
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
  bool _isLoading = false;
  // چک‌لیست
  final List<String> _checklistItems = [];
  final _checklistController = TextEditingController();
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
  // 🔧 اشتراکِ تاریخچه با ارجاع‌شوندگان — endpoint از قبل پشتیبانی
  // می‌کند (share_history)، فقط تا الان در فرمِ موبایل نبود
  bool _shareHistory = true;

  @override
  void initState() {
    super.initState();
    _loadAssigneeData();
    final rf = widget.redefineFrom;
    if (rf != null) {
      _titleController.text = (rf['title'] ?? '').toString();
      _descController.text = (rf['description'] ?? '').toString();
      _taskType = (rf['task_type'] ?? 'periodic').toString();
      _priority = (rf['priority'] ?? 'medium').toString();
      if (rf['group_id'] != null) {
        _selectedGroupId = rf['group_id'];
        _groupLabel = (rf['group_name'] ?? '').toString().isNotEmpty
            ? rf['group_name'].toString()
            : 'بدون گروه';
      }
      final checklistTitles = (rf['checklist_titles'] as List?) ?? [];
      _checklistItems.addAll(checklistTitles.map((e) => e.toString()));
      // 🔧 تاریخ/موعد و مسئولِ انجام عمداً خالی می‌مانند — باید تازه
      // انتخاب شوند، درست مثلِ رفتارِ «بازتعریف» در نسخهٔ دسکتاپ
    }
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
        _users = all.where((u) => u['id'] != widget.currentUserId).toList();
      }
    } catch (_) {}
    await _loadGroups();

    setState(() {});
  }

  Future<void> _loadGroups() async {
    try {
      // 🔧 list.php (نه list-all.php) — همان قابلِ دسترسِ همه‌ی کاربران
      final r = await ApiClient.dio.get('/api/task-groups/list.php');
      if (r.data['success'] == true) {
        final all = r.data['groups'] as List? ?? [];
        setState(() {
          _groups = all.where((g) {
            if (g['scope'] == 'org') return true;
            return g['created_by']?.toString() ==
                widget.currentUserId.toString();
          }).toList();
        });
      }
    } catch (_) {}
  }

  String _toApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  // 🔧 به‌جای پکیج persian_datetime_picker (که گاهی ارقام را انگلیسی
  // نشان می‌داد)، انتخابگر اختصاصیِ خودمان استفاده می‌شود
  Future<DateTime?> _pickDate({DateTime? initial}) async {
    return showCustomPersianDatePicker(
      context,
      initialDate: initial,
      firstDate: Jalali(1400, 1, 1),
      lastDate: Jalali(1410, 12, 29),
    );
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      AppSnack.error('خطا', 'عنوان کار الزامی است');
      return;
    }
    if (_taskType == 'periodic' && _dueDate == null) {
      AppSnack.error('خطا', 'تاریخ انجام الزامی است');
      return;
    }
    if (_taskType == 'continuous' && _startDate == null) {
      AppSnack.error('خطا', 'تاریخ شروع الزامی است');
      return;
    }

    setState(() => _isLoading = true);

    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'task_type': _taskType,
      'priority': _priority,
      'share_history': _shareHistory,
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
    final redefineAttachmentIds =
        widget.redefineFrom?['attachment_ids'] as List?;
    if (redefineAttachmentIds != null && redefineAttachmentIds.isNotEmpty) {
      body['copy_attachment_ids'] = redefineAttachmentIds;
    }

    try {
      final res = await ApiClient.dio.post('/api/tasks/create.php', data: body);
      setState(() => _isLoading = false);

      if (res.data['success'] == true) {
        final newTaskId = res.data['task_id'];
        if (newTaskId != null && _checklistItems.isNotEmpty) {
          await _saveChecklist(newTaskId);
        }
        if (newTaskId != null && _pickedFiles.isNotEmpty) {
          await _uploadFiles(newTaskId);
        }
        Get.back(result: true);
        AppSnack.success(
          '✅ موفق',
          widget.redefineFrom != null
              ? 'کار بازتعریف شد'
              : 'کار با موفقیت ایجاد شد',
        );
      } else {
        AppSnack.error('خطا', res.data['message'] ?? 'خطا در ایجاد کار');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
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
      AppSnack.error('خطا', 'خطا در انتخاب فایل');
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
      } catch (_) {}
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
    } catch (_) {}
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
          widget.redefineFrom != null ? 'بازتعریف کار' : 'تعریف کار جدید',
          style: TextStyle(
            color: c.textStrong,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: Transform.rotate(
            angle: math.pi, // 🔧 طبق درخواست: ۱۸۰ درجه چرخید
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── این یک کار روتین است؟ — فعلاً غیرفعال (به‌زودی) ──
            // 🔧 طبق درخواست: بدونِ آیکن و بدونِ کادر/بکگراند — فقط
            // سوییچ و برچسب، و طبقِ درخواستِ بعدی: سوییچ بلافاصله پشتِ
            // متن (نه با فاصله‌ی زیاد تا لبه‌ی مقابل) — هر دو با هم
            // سمتِ راست بچسبند
            Opacity(
              opacity: 0.5,
              child: IgnorePointer(
                child: Row(
                  children: [
                    AppSwitch(
                      value: false,
                      onChanged: (_) {},
                      activeColor: c.primary,
                    ),
                    const SizedBox(width: 10),
                    // Expanded (نه Flexible+Spacer که عرض را نصف می‌کرد و متن
                    // را دو خطی می‌کرد) — متن یک‌خطی و چسبیده به سوییچ
                    Expanded(
                      child: Text(
                        'این یک کار روتین است (به‌زودی)',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.textStrong),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 🔧 طبق درخواست: عنوان/برچسبِ هر بخش با فیلد/کنترلِ خودش در
            // یک خط (به‌جای عنوانِ جدا بالای هر فیلد)
            _labeledRow(
              c,
              icon: Icons.edit_outlined,
              label: 'عنوان کار',
              field: _bareTextField(
                c,
                controller: _titleController,
                hint: 'عنوان کار را وارد کنید',
              ),
            ),
            const SizedBox(height: 16),

            // 🔧 طبق درخواست: چک‌لیست بلافاصله بعد از عنوان
            _labeledRow(
              c,
              icon: Icons.checklist_rounded,
              label: 'چک‌لیست',
              trailing: _checklistItems.isEmpty
                  ? null
                  : toPersianDigits('${_checklistItems.length} مورد'),
              field: _checklistAddField(c),
            ),
            if (_checklistItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              _checklistItemsList(c),
            ],
            const SizedBox(height: 16),

            _groupPicker(c),
            const SizedBox(height: 16),

            _labeledRow(
              c,
              icon: Icons.priority_high_rounded,
              label: 'اولویت',
              labelFontSize: 11.5,
              field: _prioritySelector(c),
            ),
            const SizedBox(height: 16),

            _labeledRow(
              c,
              icon: Icons.grid_view_rounded,
              label: 'نوع کار',
              labelFontSize: 11.5,
              field: _typeSelector(c),
            ),
            const SizedBox(height: 16),

            // 🔧 طبق درخواست: عنوان/برچسبِ «توضیحات» داخلِ خودِ کادر آمد
            // (نه بالای آن، جدا)
            _descriptionField(c),
            const SizedBox(height: 16),

            _assigneePicker(c),
            const SizedBox(height: 16),

            if (_taskType == 'periodic') ...[
              _dateTile(
                c,
                icon: Icons.calendar_today_outlined,
                label: 'موعد انجام',
                value: _dueDate != null ? _toShamsi(_dueDate!) : null,
                hint: 'انتخاب تاریخ',
                onTap: () async {
                  final d = await _pickDate();
                  if (d != null) setState(() => _dueDate = d);
                },
              ),
            ] else ...[
              _dateTile(
                c,
                icon: Icons.play_circle_outline_rounded,
                label: 'تاریخ شروع',
                value: _startDate != null ? _toShamsi(_startDate!) : null,
                hint: 'انتخاب تاریخ',
                onTap: () async {
                  final d = await _pickDate();
                  if (d != null) setState(() => _startDate = d);
                },
              ),
              const SizedBox(height: 10),
              _dateTile(
                c,
                icon: Icons.event_busy_rounded,
                label: 'تاریخ پایان (اختیاری)',
                value: _endDate != null ? _toShamsi(_endDate!) : null,
                hint: 'نامحدود',
                onTap: () async {
                  final d = await _pickDate();
                  if (d != null) setState(() => _endDate = d);
                },
              ),
              const SizedBox(height: 10),
              _labeledRow(
                c,
                icon: Icons.repeat_rounded,
                label: 'دوره تکرار',
                field: _periodSelector(c),
              ),
            ],
            const SizedBox(height: 16),

            // 🔧 طبق درخواست: آیکنِ چشم حذف شد
            _toggleRow(
              c,
              label: 'نمایش تاریخچه کار برای کاربران ارجاع‌شونده',
              value: _shareHistory,
              onChanged: (v) => setState(() => _shareHistory = v),
            ),
            const SizedBox(height: 16),

            _labeledRow(
              c,
              icon: Icons.attach_file_rounded,
              label: 'فایل‌های پیوست',
              trailing: _pickedFiles.isEmpty
                  ? null
                  : toPersianDigits('${_pickedFiles.length} فایل'),
              field: _attachmentsAddField(c),
            ),
            if (_pickedFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              _attachmentsList(c),
            ],
          ],
        ),
      ),
      // 🔧 طبق درخواست: دکمه‌ی ذخیره دیگر داخل اسکرول نیست — ثابت،
      // چسبیده به بالای نوار/دکمه‌های سیستمِ گوشی
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: c.bgPage,
            border: Border(top: BorderSide(color: c.borderSoft)),
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
                  : Text(
                      widget.redefineFrom != null
                          ? 'بازتعریف کار'
                          : 'ذخیره کار',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── ویجت‌های کمکی ─────────────────────────────────

  Widget _rowContainer(
    AppColors c, {
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) => Container(
    padding:
        padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.borderSoft),
    ),
    child: child,
  );

  // 🔧 طبق درخواست: عنوانِ هر بخش دیگر ردیفِ جداگانه‌ی بالای فیلد
  // نیست — همه در یک خط (آیکن+برچسب سمتِ راست، خودِ فیلد/کنترل
  // سمتِ چپ و Expanded)
  Widget _labeledRow(
    AppColors c, {
    required IconData icon,
    required String label,
    String? trailing,
    required Widget field,
    double labelFontSize = 13,
  }) {
    return _rowContainer(
      c,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w600,
              color: c.textStrong,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing, style: TextStyle(fontSize: 11, color: c.textMuted)),
          ],
          const SizedBox(width: 10),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget _bareTextField(
    AppColors c, {
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 13.5, color: c.textStrong),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
  }

  // 🔧 طبق درخواست: برچسبِ «توضیحات» داخلِ خودِ کادر (به‌عنوانِ یک
  // سرتیترِ کوچک بالای فیلد)، نه جدا و بیرون از آن
  Widget _descriptionField(AppColors c) {
    return _rowContainer(
      c,
      // 🔧 طبق درخواست: متنِ راهنمای «توضیحات کار را وارد کنید» جلوی
      // برچسبِ «توضیحات» (همان ردیف) آمد و ارتفاعِ کادر حدود ۵۰٪ کمتر شد
      // (قبلاً ۲۰+۱۰+۴۵ = ۷۵؛ حالا ۳۶). فیلد همچنان چندخطی است و اسکرول می‌خورد.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.notes_rounded, size: 18, color: c.textMuted),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'توضیحات',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _descController,
                maxLines: null,
                minLines: null,
                expands: true,
                textAlign: TextAlign.right,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(fontSize: 13.5, color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'توضیحات کار را وارد کنید',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  isDense: true,
                  // عددِ top را کمتر/منفی‌نزدیک به صفر کنید تا متن بالاتر برود
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 آیکن اختیاری شد — ردیفِ «تاریخچه» دیگر آیکن (چشم) ندارد.
  // 🔧 طبق درخواست: سوییچ بلافاصله پشتِ متن می‌آید (نه با Expanded که
  // آن را تا لبه‌ی مقابل می‌کشید) — با Flexible+Spacer هر دو با هم
  // سمتِ راست می‌چسبند
  Widget _toggleRow(
    AppColors c, {
    IconData? icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _rowContainer(
      c,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c.textMuted),
            const SizedBox(width: 10),
          ],
          // Expanded: متن یک‌خطی و سوییچ تا لبه‌ی چپِ کادر می‌رود
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textStrong),
            ),
          ),
          const SizedBox(width: 10),
          // سوییچِ کوچک‌شده هنوز جای اصلیِ خود را در Row اشغال می‌کند و
          // ~۹ پیکسل فاصله‌ی اضافه از لبه می‌سازد؛ با ۱۱- پیکسل جابه‌جایی
          // فاصله‌ی چپ نصف می‌شود (عدد را کم/زیاد کنید تا تنظیم شود)
          Transform.translate(
            offset: const Offset(-11, 0),
            child: AppSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: c.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(
    AppColors c, {
    required IconData icon,
    required String label,
    String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _labeledRow(
        c,
        icon: icon,
        label: label,
        field: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? c.textStrong : c.textMuted,
                ),
              ),
            ),
            if (value != null)
              Icon(Icons.check_circle_rounded, color: c.primary, size: 15),
          ],
        ),
      ),
    );
  }

  Widget _prioritySelector(AppColors c) => Row(
    children: [
      _prioBtn(c, 'بالا', 'high', c.danger),
      const SizedBox(width: 8),
      _prioBtn(c, 'متوسط', 'medium', c.warning),
      const SizedBox(width: 8),
      _prioBtn(c, 'پایین', 'low', c.success),
    ],
  );

  Widget _prioBtn(AppColors c, String label, String val, Color color) {
    final selected = _priority == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : c.borderSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeSelector(AppColors c) => Row(
    children: [
      _typeBtn(c, 'مقطعی', 'periodic', Icons.event_note_rounded),
      const SizedBox(width: 10),
      _typeBtn(c, 'دوره‌ای', 'continuous', Icons.repeat_rounded),
    ],
  );

  Widget _typeBtn(AppColors c, String label, String val, IconData icon) {
    final selected = _taskType == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _taskType = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? c.primary : c.borderSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : c.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : c.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodSelector(AppColors c) => Row(
    children: [
      _periodBtn(c, 'روزانه', 'daily'),
      const SizedBox(width: 8),
      _periodBtn(c, 'هفتگی', 'weekly'),
      const SizedBox(width: 8),
      _periodBtn(c, 'ماهانه', 'monthly'),
    ],
  );

  Widget _periodBtn(AppColors c, String label, String val) {
    final selected = _periodType == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _periodType = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.primary.withValues(alpha: 0.12) : c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? c.primary : c.borderSoft),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? c.primary : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Color _parseGroupColor(AppColors c, String? hex) {
    if (hex == null || hex.isEmpty) return c.primary;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return c.primary;
    }
  }

  Widget _groupPicker(AppColors c) {
    final hasSelection = _selectedGroupId != null;
    Color dotColor = c.textMuted;
    if (hasSelection) {
      final g = _groups.firstWhere(
        (e) => e['id'] == _selectedGroupId,
        orElse: () => null,
      );
      if (g != null) dotColor = _parseGroupColor(c, g['color']);
    }
    return GestureDetector(
      onTap: () => _showGroupSheet(c),
      child: _labeledRow(
        c,
        icon: Icons.folder_outlined,
        label: 'گروه کار',
        field: Row(
          children: [
            if (hasSelection) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                _groupLabel,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: c.textStrong),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              hasSelection ? Icons.close_rounded : Icons.expand_more_rounded,
              color: c.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupSheet(AppColors c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: c.surfaceContainerLow,
      builder: (_) => Column(
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
            'انتخاب گروه',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: c.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: Icon(Icons.block, color: c.textMuted, size: 20),
                  title: Text(
                    'بدون گروه',
                    style: TextStyle(color: c.textStrong),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedGroupId = null;
                      _groupLabel = 'بدون گروه';
                    });
                    Get.back();
                  },
                ),
                ..._groups.map((g) {
                  final color = _parseGroupColor(c, g['color']);
                  return ListTile(
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      g['name'] ?? '',
                      style: TextStyle(color: c.textStrong),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedGroupId = g['id'];
                        _groupLabel = g['name'] ?? '';
                      });
                      Get.back();
                    },
                  );
                }),
                Divider(height: 12, color: c.borderSoft),
                ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    color: c.primary,
                    size: 20,
                  ),
                  title: Text(
                    'مدیریت گروه‌ها',
                    style: TextStyle(color: c.primary),
                  ),
                  onTap: () {
                    Get.back();
                    showTaskGroupManagementSheet(
                      context,
                      onChanged: _loadGroups,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _assigneePicker(AppColors c) {
    final hasSelection = _assigneeType != 'self';
    return GestureDetector(
      onTap: () => _showAssigneeSheet(c),
      child: _labeledRow(
        c,
        icon: Icons.person_outline_rounded,
        label: 'واگذاری به',
        field: Row(
          children: [
            Expanded(
              child: Text(
                _assigneeLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection ? c.primary : c.textStrong,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more_rounded, color: c.textMuted, size: 16),
          ],
        ),
      ),
    );
  }

  void _showAssigneeSheet(AppColors c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssigneeSelectSheet(
        users: _users,
        sections: _sections,
        isSupervisor: _isSupervisor,
        onSelected: _selectAssignee,
      ),
    );
  }

  void _selectAssignee(String type, dynamic value, String label) {
    setState(() {
      _assigneeType = type;
      _assigneeValue = value;
      _assigneeLabel = label;
    });
  }

  // 🔧 طبق درخواست: فقط ردیفِ «افزودنِ آیتمِ جدید» کنارِ برچسبِ
  // «چک‌لیست» در یک خط می‌آید؛ آیتم‌هایِ از قبل اضافه‌شده در فهرستِ
  // جدا (زیرش) می‌مانند
  Widget _checklistAddField(AppColors c) {
    return Row(
      children: [
        GestureDetector(
          onTap: _addChecklistItem,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _checklistController,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: c.textStrong),
            decoration: InputDecoration(
              hintText: 'افزودن آیتم جدید...',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 12.5),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
            onSubmitted: (_) => _addChecklistItem(),
          ),
        ),
      ],
    );
  }

  Widget _checklistItemsList(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _checklistItems.asMap().entries.map((entry) {
        final i = entry.key;
        final text = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _checklistItems.removeAt(i)),
                child: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: c.textStrong),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.radio_button_unchecked, size: 18, color: c.textMuted),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 🔧 طبق درخواست: به‌جای کادرِ بزرگِ «انتخاب/آپلود»، فقط یک دکمه‌ی
  // «+» کنارِ برچسبِ «فایل‌های پیوست» در یک خط
  Widget _attachmentsAddField(AppColors c) {
    return Row(
      children: [
        // 🔧 طبق درخواست: بعد از انتخابِ فایل، متنِ «برای افزودنِ فایلِ
        // دیگر…» نمایش داده نمی‌شود (دکمه‌ی + سرِ جایش می‌ماند)
        Expanded(
          child: _pickedFiles.isEmpty
              ? Text(
                  'فایلی انتخاب نشده',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _attachmentsList(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _pickedFiles.asMap().entries.map((entry) {
        final i = entry.key;
        final file = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _pickedFiles.removeAt(i)),
                child: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  file.name,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: c.textStrong),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.insert_drive_file_outlined,
                size: 18,
                color: c.textMuted,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════
// مودالِ انتخابِ مسئول، با قابلیتِ جستجو
// ════════════════════════════════════════════════════════════
class _AssigneeSelectSheet extends StatefulWidget {
  final List<dynamic> users;
  final List<dynamic> sections;
  final bool isSupervisor;
  final void Function(String type, dynamic value, String label) onSelected;

  const _AssigneeSelectSheet({
    required this.users,
    required this.sections,
    required this.isSupervisor,
    required this.onSelected,
  });

  @override
  State<_AssigneeSelectSheet> createState() => _AssigneeSelectSheetState();
}

class _AssigneeSelectSheetState extends State<_AssigneeSelectSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _userLabel(dynamic u) {
    final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final q = _query.trim().toLowerCase();

    final filteredSections = q.isEmpty
        ? widget.sections
        : widget.sections.where((s) {
            final label = (s['section_label'] ?? s['section_key'] ?? '')
                .toString()
                .toLowerCase();
            return label.contains(q);
          }).toList();

    final filteredUsers = q.isEmpty
        ? widget.users
        : widget.users.where((u) {
            final label = _userLabel(u).toLowerCase();
            final phone = (u['phone'] ?? '').toString().toLowerCase();
            return label.contains(q) || phone.contains(q);
          }).toList();

    final showSelfOption = q.isEmpty || 'خودم'.contains(q);
    final showGroupOptions = q.isEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
              color: c.borderSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'انتخاب مسئول',
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
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: c.textStrong, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'جستجوی نام یا واحد...',
                hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: c.textMuted,
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: c.textMuted,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
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
            child:
                (filteredSections.isEmpty &&
                    filteredUsers.isEmpty &&
                    !showSelfOption)
                ? Center(
                    child: Text(
                      'نتیجه‌ای یافت نشد',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  )
                : ListView(
                    controller: scrollController,
                    children: [
                      if (showSelfOption)
                        _tile(
                          c,
                          icon: Icons.person,
                          color: c.textMuted,
                          label: 'خودم',
                          onTap: () => _select('self', null, 'خودم'),
                        ),
                      if (filteredSections.isNotEmpty) ...[
                        _header(c, 'واحدها'),
                        if (widget.isSupervisor && showGroupOptions)
                          _tile(
                            c,
                            icon: Icons.groups,
                            color: c.primary,
                            label: 'همه واحدها',
                            meta:
                                '${widget.users.length} نفر — یک تسک برای هر نفر',
                            onTap: () => _select(
                              'all_sections',
                              '__all__',
                              'همه واحدها',
                            ),
                          ),
                        ...filteredSections.map((s) {
                          final key = s['section_key'];
                          final label = s['section_label'] ?? key;
                          final count = widget.users
                              .where((u) => u['activity_section'] == key)
                              .length;
                          return _tile(
                            c,
                            icon: Icons.folder_outlined,
                            color: c.warning,
                            label: label,
                            meta: count > 0 ? '$count نفر' : 'بدون عضو',
                            onTap: () => _select('section', key, label),
                          );
                        }),
                      ],
                      if (filteredUsers.isNotEmpty || showGroupOptions) ...[
                        _header(c, 'کاربران'),
                        if (widget.isSupervisor && showGroupOptions)
                          _tile(
                            c,
                            icon: Icons.people,
                            color: c.primary,
                            label: 'همه کاربران',
                            meta:
                                '${widget.users.length} نفر — یک تسک برای هر نفر',
                            onTap: () => _select(
                              'all_users',
                              '__all_users__',
                              'همه کاربران',
                            ),
                          ),
                        ...filteredUsers.map((u) {
                          final display = _userLabel(u);
                          return _tile(
                            c,
                            avatar: display.isNotEmpty ? display[0] : '?',
                            label: display,
                            onTap: () => _select('user', u['id'], display),
                          );
                        }),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _select(String type, dynamic value, String label) {
    widget.onSelected(type, value, label);
    Navigator.of(context).pop();
  }

  Widget _header(AppColors c, String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    color: c.surfaceContainerLow,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textMuted,
      ),
    ),
  );

  Widget _tile(
    AppColors c, {
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
              backgroundColor: c.primary.withValues(alpha: 0.1),
              child: Text(
                avatar,
                style: TextStyle(color: c.primary, fontSize: 13),
              ),
            )
          : CircleAvatar(
              radius: 16,
              backgroundColor: (color ?? c.textMuted).withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 18),
            ),
      title: Text(label, style: TextStyle(fontSize: 14, color: c.textStrong)),
      subtitle: meta != null
          ? Text(meta, style: TextStyle(fontSize: 11, color: c.textMuted))
          : null,
      onTap: onTap,
    );
  }
}
