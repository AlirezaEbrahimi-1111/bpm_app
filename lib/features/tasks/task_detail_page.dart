import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/persian_number.dart';

class TaskDetailPage extends StatefulWidget {
  final int taskId;
  final int? currentUserId;
  const TaskDetailPage({super.key, required this.taskId, this.currentUserId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  static const _primary = Color(0xFF6C63FF);
  static const _ink = Color(0xFF1A1A2E);

  Map<String, dynamic>? _task;
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _error;
  List<dynamic> _checklist = [];
  int _checklistDone = 0;
  int _checklistTotal = 0;
  int _checklistPercent = 0;
  List<dynamic> _groups = [];
  bool _canEdit = false;
  bool _hasChanges = false;
  bool _isDeleted = false;
  List<dynamic> _users = [];
  List<dynamic> _attachments = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = ApiClient.currentUserId; // ← از منبع سراسری مطمئن
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/detail.php',
        queryParameters: {'id': widget.taskId},
      );
      if (res.data['success'] == true) {
        print(
          '🔍 TASK DATA: ${res.data['task']}',
        ); // ← این خط را موقتاً اضافه کنید

        setState(() {
          _task = res.data['task'];
          _history = res.data['history'] ?? [];
          _canEdit = res.data['can_edit'] == true;
          _isDeleted =
              res.data['task']?['is_deleted'] == 1 ||
              res.data['task']?['is_deleted'] == true;
          _isLoading = false;
        });
        _loadChecklist(); // ← اضافه شد
        _loadGroups();
        _loadUsers();
        _loadAttachments();
      } else {
        setState(() {
          _error = res.data['message'] ?? 'خطا در دریافت اطلاعات';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطا در اتصال به سرور';
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return _primary;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _primary;
    }
  }

  Future<void> _changeGroup(int? groupId) async {
    print('📤 Sending group_id: $groupId (${groupId.runtimeType})');

    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/update-group.php',
        data: {'task_id': widget.taskId, 'group_id': groupId},
      );
      print('📥 Response type: ${res.data.runtimeType}');
      print('📥 Response: ${res.data}');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;

        _loadDetail();
        Get.snackbar(
          '✅ موفق',
          'گروه به‌روزرسانی شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          res.data['message'] ?? 'خطا در تغییر گروه',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      print('❌ Group error: $e');
      if (e is dio.DioException) {
        print('📋 Status: ${e.response?.statusCode}');
        print('📋 Data: ${e.response?.data}');
      }
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  void _showGroupSheet() {
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
                    Get.back();
                    _changeGroup(null);
                  },
                ),
                ..._groups.map((g) {
                  final color = _parseColor(g['color']);
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
                      Get.back();
                      _changeGroup(g['id']);
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

  Future<void> _loadAttachments() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/get-attachments.php',
        queryParameters: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(() => _attachments = data['attachments'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadFile() async {
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
        withData: true, // مهم برای وب
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      setState(() => _isUploading = true);

      // ساخت FormData
      final formData = dio.FormData.fromMap({
        'task_id': widget.taskId,
        'file': dio.MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });

      final res = await ApiClient.dio.post(
        '/api/tasks/upload-attachment.php',
        data: formData,
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUploading = false);

      if (data['success'] == true) {
        _loadAttachments();
        Get.snackbar(
          '✅ موفق',
          'فایل آپلود شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          data['message'] ?? 'خطا در آپلود',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      Get.snackbar(
        'خطا',
        'خطا در آپلود فایل',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _deleteAttachment(int attId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/delete-attachment.php',
        data: {'attachment_id': attId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _loadAttachments();
        Get.snackbar(
          '✅ موفق',
          'فایل حذف شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          data['message'] ?? 'خطا در حذف',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _openFile(String filePath) async {
    final url = 'https://bpm.computeryekta.com/$filePath';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      Get.snackbar(
        'خطا',
        'امکان باز کردن فایل نیست',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _loadUsers() async {
    try {
      final res = await ApiClient.dio.get('/api/users/list.php');
      if (res.data['success'] == true) {
        final all = res.data['users'] as List? ?? [];
        // حذف کاربر جاری از لیست
        setState(() {
          _users = all
              .where((u) => u['id']?.toString() != _currentUserId?.toString())
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGroups() async {
    try {
      final res = await ApiClient.dio.get('/api/task-groups/list-all.php');
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        final all = data['groups'] as List? ?? [];
        final myId = _currentUserId;
        setState(() {
          _groups = all.where((g) {
            if (g['scope'] == 'org') return true;
            return g['created_by']?.toString() == myId?.toString();
          }).toList();
        });
      }
    } catch (_) {
      // کاربر عادی به گروه‌ها دسترسی ندارد — طبیعی است
    }
  }

  Future<void> _loadChecklist() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/checklist/get.php',
        queryParameters: {'task_id': widget.taskId},
      );
      print('✅ Checklist response: ${res.data}');
      if (res.data['success'] == true) {
        setState(() {
          _checklist = res.data['items'] ?? [];
          _checklistDone = res.data['done'] ?? 0;
          _checklistTotal = res.data['total'] ?? 0;
          _checklistPercent = res.data['percent'] ?? 0;
        });
      }
    } catch (e) {
      print('❌ Checklist error: $e');
    }
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final isDone = item['is_done'] == 1 || item['is_done'] == true;

    // آیتم تیک‌خورده قفل است
    if (isDone) {
      Get.snackbar(
        'قفل',
        'این آیتم تکمیل شده و قابل تغییر نیست',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    if (item['can_toggle_this'] != true) {
      Get.snackbar(
        'توجه',
        'این آیتم به فرد دیگری ارجاع شده است',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }
    final newValue = !(item['is_done'] == 1 || item['is_done'] == true);
    try {
      final res = await ApiClient.dio.post(
        '/api/checklist/toggle.php',
        data: {'item_id': item['id'], 'is_done': newValue},
      );
      if (res.data['success'] == true) {
        _loadChecklist();
        // اگر کار خودکار تکمیل شد، کل صفحه را refresh کن
        if (res.data['auto_completed'] == true) {
          _loadDetail();
        }
      } else {
        Get.snackbar(
          'خطا',
          res.data['message'] ?? 'خطا در تغییر آیتم',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      print('❌ Toggle error: $e');
      if (e is dio.DioException) {
        print('📋 Status: ${e.response?.statusCode}');
        print('📋 Data: ${e.response?.data}');
      }
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  String _toShamsiDateTime(String? gregorian) {
    if (gregorian == null || gregorian.isEmpty) return '';
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
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return toPersianDigits(
        '${j.day} ${mo[j.month - 1]} ${j.year} - ساعت $h:$m',
      );
    } catch (_) {
      return gregorian;
    }
  }

  // تبدیل تاریخ میلادی متن به شمسی
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
      return gregorian;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Get.back(result: _hasChanges);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'جزئیات کار',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded, // ← این
              color: _ink,
              size: 20,
            ),
            onPressed: () => Get.back(result: _hasChanges),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
            ? _buildError()
            : _buildContent(),
        bottomNavigationBar: (_isLoading || _error != null || _task == null)
            ? null
            : _buildActionBar(),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        TextButton(onPressed: _loadDetail, child: const Text('تلاش مجدد')),
      ],
    ),
  );
  // ════════════════════════════════════════════════
  // نوار عملیات پایین — دکمه‌های دایره‌ای آیکونی (مینیمال)
  // ════════════════════════════════════════════════
  Widget? _buildActionBar() {
    final t = _task!;
    final status = t['status'] as String? ?? '';

    // ── اگر کار حذف شده: فقط دکمه بازگردانی ──
    if (_isDeleted) {
      return Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  'این کار حذف شده است',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── ادامه منطق عادی (کار حذف‌نشده) ──
    final isAssignee =
        _currentUserId != null &&
        t['assignee_id']?.toString() == _currentUserId.toString();
    final isCreator =
        _currentUserId != null &&
        t['creator_id']?.toString() == _currentUserId.toString();
    final isPending =
        status == 'pending_approval' &&
        (t['is_pending_approval'] == 1 || t['is_pending_approval'] == true);

    // دکمه‌هایی که قرار است نمایش داده شوند
    final List<Widget> buttons = [];

    // ── حالت منتظر تأیید: رد / تأیید ──
    if (isPending && (isCreator || isAssignee)) {
      buttons.add(
        _circleAction(
          icon: Icons.close_rounded,
          label: 'رد',
          color: const Color(0xFFEF4444),
          onTap: _showRejectDialog,
        ),
      );
      buttons.add(
        _circleAction(
          icon: Icons.check_rounded,
          label: 'تأیید',
          color: const Color(0xFF22C55E),
          onTap: () => _approveOrReject(true),
        ),
      );
    } else if (isAssignee) {
      // ── شروع / تکمیل ──
      if (status == 'not_started' ||
          status == 'delegated' ||
          status == 'rejected') {
        buttons.add(
          _circleAction(
            icon: Icons.play_arrow_rounded,
            label: 'شروع',
            color: const Color(0xFF3B82F6),
            onTap: () => _updateStatus('in_progress'),
          ),
        );
      } else if (status == 'in_progress') {
        buttons.add(
          _circleAction(
            icon: Icons.check_rounded,
            label: 'تکمیل',
            color: const Color(0xFF22C55E),
            onTap: _showCompleteDialog,
          ),
        );
      }

      // ── ارجاع ──
      final canDelegate =
          status != 'completed' &&
          status != 'approved' &&
          status != 'rejected' &&
          !isPending;
      if (canDelegate) {
        buttons.add(
          _circleAction(
            icon: Icons.send_rounded,
            label: 'ارجاع',
            color: const Color(0xFFF59E0B),
            onTap: _showDelegateSheet,
          ),
        );
      }
    }

    // ── حذف (برای سازنده) — در همین ردیف ──
    if (_canEdit) {
      buttons.add(
        _circleAction(
          icon: Icons.delete_outline_rounded,
          label: 'حذف',
          color: const Color(0xFFEF4444),
          onTap: _confirmDelete,
        ),
      );
    }

    // اگر هیچ دکمه‌ای نبود، نوار را نشان نده
    if (buttons.isEmpty) return null;

    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _withGaps(buttons, 28),
          ),
        ),
      ),
    );
  }

  // افزودن فاصله بین دکمه‌ها
  List<Widget> _withGaps(List<Widget> items, double gap) {
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) result.add(SizedBox(width: gap));
    }
    return result;
  }

  // دکمه دایره‌ای آیکونی + برچسب زیرش
  Widget _circleAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isUpdating ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isUpdating
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final t = _task!;
    final status = t['status'] as String? ?? '';
    final priority = t['priority'] as String? ?? '';
    final si = _statusInfo(status);
    final pi = _priorityInfo(priority);
    final isContinuous = t['task_type'] == 'continuous';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── کارت اصلی ──
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان + وضعیت
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        t['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ),
                    _chip(si.$2, si.$1),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _chip(pi.$2, pi.$1),
                    const SizedBox(width: 8),
                    _chip(isContinuous ? 'دوره‌ای' : 'مقطعی', _primary),
                  ],
                ),
                if ((t['description'] ?? '').toString().isNotEmpty) ...[
                  const Divider(height: 28),
                  Text(
                    'توضیحات',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: _ink,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── کارت اطلاعات ──
          _card(
            child: Column(
              children: [
                _infoRow(
                  Icons.person_outline,
                  'سازنده',
                  t['creator_name'] ?? '—',
                ),
                const Divider(height: 20),
                _infoRow(
                  Icons.assignment_ind_outlined,
                  'مسئول',
                  t['assignee_name'] ?? '—',
                ),
                const Divider(height: 20),
                if (isContinuous) ...[
                  _infoRow(
                    Icons.play_circle_outline,
                    'تاریخ شروع',
                    _toShamsi(t['start_date']),
                  ),
                  const Divider(height: 20),
                  _infoRow(
                    Icons.event_busy_outlined,
                    'تاریخ پایان',
                    _toShamsi(t['end_date']),
                  ),
                  const Divider(height: 20),
                  _infoRow(
                    Icons.repeat_rounded,
                    'دوره تکرار',
                    _periodLabel(t['period_type']),
                  ),
                ] else
                  _infoRow(
                    Icons.event_outlined,
                    'موعد انجام',
                    _toShamsi(t['due_date']),
                  ),
                const Divider(height: 20),
                _buildGroupRow(t),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── چک‌لیست ──
          if (_checklistTotal > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'چک‌لیست',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  Text(
                    toPersianDigits('$_checklistDone از $_checklistTotal'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            _card(
              child: Column(
                children: [
                  // نوار پیشرفت
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _checklistPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation(_primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // آیتم‌ها
                  ..._checklist.map((item) => _checklistItem(item)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ── پیوست‌ها ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'پیوست‌ها',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
                GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add, size: 16, color: _primary),
                              SizedBox(width: 4),
                              Text(
                                'افزودن',
                                style: TextStyle(
                                  fontSize: 12,
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
          ),
          if (_attachments.isEmpty)
            _card(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'فایلی پیوست نشده',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            _card(
              child: Column(
                children: _attachments.map((a) => _attachmentItem(a)).toList(),
              ),
            ),
          const SizedBox(height: 12),
          // ── تاریخچه ──
          if (_history.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'تاریخچه فعالیت‌ها',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            _card(
              child: Column(
                children: _history.map((h) => _historyItem(h)).toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  int? _currentUserId;
  bool _isUpdating = false;
  void _showDelegateSheet() {
    if (_users.isEmpty) {
      Get.snackbar(
        'توجه',
        'کاربری برای ارجاع یافت نشد',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade100,
      );
      return;
    }

    int? selectedUserId;
    String? selectedUserName;
    final notesController = TextEditingController();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
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
                'ارجاع کار',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // لیست کاربران
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _users.map((u) {
                    final name =
                        '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                            .trim();
                    final display = name.isEmpty
                        ? (u['phone'] ?? 'بدون نام')
                        : name;
                    final selected = selectedUserId == u['id'];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: selected
                            ? _primary
                            : _primary.withValues(alpha: 0.1),
                        child: Text(
                          display.toString().isNotEmpty
                              ? display.toString()[0]
                              : '?',
                          style: TextStyle(
                            color: selected ? Colors.white : _primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        display,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: _primary)
                          : null,
                      onTap: () => setSheetState(() {
                        selectedUserId = u['id'];
                        selectedUserName = display;
                      }),
                    );
                  }).toList(),
                ),
              ),

              // توضیح
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    hintText: 'توضیح (اختیاری)...',
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
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // دکمه ارجاع
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedUserId == null
                        ? null
                        : () {
                            Get.back();
                            _delegateTask(
                              selectedUserId!,
                              notes: notesController.text.trim(),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      selectedUserName == null
                          ? 'یک نفر را انتخاب کنید'
                          : 'ارجاع به $selectedUserName',
                      style: const TextStyle(
                        fontSize: 15,
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
      isScrollControlled: true,
    );
  }

  void _showRejectDialog() {
    final notesController = TextEditingController();
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cancel_outlined,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'رد کار',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'دلیل رد (الزامی)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'دلیل رد کار را بنویسید...',
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
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'انصراف',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final notes = notesController.text.trim();
                        if (notes.isEmpty) {
                          Get.snackbar(
                            'خطا',
                            'دلیل رد الزامی است',
                            snackPosition: SnackPosition.BOTTOM,
                            backgroundColor: Colors.red.shade100,
                          );
                          return;
                        }
                        Get.back();
                        _approveOrReject(false, notes: notes);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('رد کردن'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompleteDialog() {
    final notesController = TextEditingController();
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF22C55E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'تکمیل کار',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'توضیحات (اختیاری)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'توضیحی درباره انجام کار...',
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
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'انصراف',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _updateStatus(
                          'completed',
                          notes: notesController.text.trim(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('تکمیل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delegateTask(int toUserId, {String? notes}) async {
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/delegate.php',
        data: {
          'task_id': widget.taskId,
          'to_user_id': toUserId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);

      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        Get.snackbar(
          '✅ موفق',
          data['message'] ?? 'کار ارجاع شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          data['message'] ?? 'خطا در ارجاع',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _approveOrReject(bool approve, {String? notes}) async {
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve.php',
        data: {
          'task_id': widget.taskId,
          'approve': approve,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);

      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        Get.snackbar(
          approve ? '✅ تأیید شد' : 'رد شد',
          data['message'] ?? '',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: approve
              ? Colors.green.shade100
              : Colors.orange.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          data['message'] ?? 'خطا در عملیات',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _deleteTask() async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/delete.php',
        data: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);

      if (data['success'] == true) {
        // برگشت به صفحه قبل با پیام و امکان بازگردانی
        Get.back(result: true);
        Get.snackbar(
          '🗑️ حذف شد',
          'کار حذف شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.grey.shade200,
          mainButton: TextButton(
            onPressed: () {
              Get.closeCurrentSnackbar();
              _restoreTask();
            },
            child: const Text(
              'بازگردانی',
              style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          'خطا',
          data['message'] ?? 'خطا در حذف',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Future<void> _restoreTask() async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/restore.php',
        data: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        Get.snackbar(
          '✅ بازگردانی شد',
          'کار بازگردانده شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      }
    } catch (_) {}
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف کار', style: TextStyle(fontSize: 16)),
        content: const Text('آیا از حذف این کار مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'انصراف',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _deleteTask();
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String status, {String? notes}) async {
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/update-status.php',
        data: {
          'task_id': widget.taskId,
          'status': status,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);

      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        Get.snackbar(
          '✅ موفق',
          data['message'] ?? 'وضعیت به‌روزرسانی شد',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade100,
        );
      } else {
        Get.snackbar(
          'خطا',
          data['message'] ?? 'خطا در تغییر وضعیت',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      Get.snackbar(
        'خطا',
        'خطا در اتصال به سرور',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  Widget _attachmentItem(Map<String, dynamic> att) {
    final isImage = att['is_image'] == true;
    final fileType = (att['file_type'] ?? '').toString();
    final canDelete = att['can_delete'] == true;

    IconData icon;
    Color color;
    if (isImage) {
      icon = Icons.image_outlined;
      color = const Color(0xFF22C55E);
    } else if (fileType == 'pdf') {
      icon = Icons.picture_as_pdf_outlined;
      color = const Color(0xFFEF4444);
    } else if (['doc', 'docx'].contains(fileType)) {
      icon = Icons.description_outlined;
      color = const Color(0xFF3B82F6);
    } else if (['xls', 'xlsx'].contains(fileType)) {
      icon = Icons.table_chart_outlined;
      color = const Color(0xFF22C55E);
    } else {
      icon = Icons.insert_drive_file_outlined;
      color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att['file_original_name'] ?? 'فایل',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${att['file_size_formatted'] ?? ''} • ${att['uploader_name'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          // دانلود
          IconButton(
            icon: Icon(Icons.download_outlined, size: 20, color: _primary),
            onPressed: () => _openFile(att['file_path'] ?? ''),
          ),
          // حذف
          if (canDelete)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red.shade300,
              ),
              onPressed: () => _confirmDeleteAttachment(att['id']),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteAttachment(int attId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف فایل', style: TextStyle(fontSize: 16)),
        content: const Text('آیا از حذف این فایل مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'انصراف',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // اول دیالوگ را ببند
              await _deleteAttachment(attId); // بعد حذف کن
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> h) {
    final action = h['action'] as String? ?? '';
    final ai = _actionInfo(action);

    // نام فردی که عمل را انجام داد
    final fromName =
        '${h['from_user_first_name'] ?? ''} ${h['from_user_last_name'] ?? ''}'
            .trim();
    // نام فرد مقصد (برای ارجاع)
    final toName =
        '${h['to_user_first_name'] ?? ''} ${h['to_user_last_name'] ?? ''}'
            .trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: ai.$1.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(ai.$2, color: ai.$1, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عمل + نام
                Row(
                  children: [
                    Text(
                      ai.$3,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    if (fromName.isNotEmpty) ...[
                      Text(
                        ' توسط ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        fromName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                // برای ارجاع: به چه کسی
                if (action == 'delegated' && toName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'به: $toName',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                // توضیحات
                if ((h['notes'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      h['notes'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                // تاریخ و ساعت
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _toShamsiDateTime(h['created_at']?.toString()),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistItem(Map<String, dynamic> item) {
    final isDone = item['is_done'] == 1 || item['is_done'] == true;
    final canToggle = item['can_toggle_this'] == true;
    final assigneeName =
        (item['assignee_user_name'] ?? '').toString().isNotEmpty
        ? item['assignee_user_name']
        : (item['assignee_section_name'] ?? '').toString();

    return InkWell(
      onTap: (isDone || !canToggle) ? null : () => _toggleItem(item),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            // چک‌باکس
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? _primary : Colors.transparent,
                border: isDone
                    ? null
                    : Border.all(
                        color: canToggle
                            ? Colors.grey.shade400
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),
            // عنوان
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDone ? Colors.grey.shade400 : _ink,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (assigneeName.toString().isNotEmpty)
                    Text(
                      'مسئول: $assigneeName',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ),
            // قفل اگر مجاز نیست
            // قفل: یا تیک‌خورده (قفل دائم) یا مجاز نیست
            if (isDone)
              Icon(Icons.lock_rounded, size: 16, color: Colors.grey.shade400)
            else if (!canToggle)
              Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  // ── ویجت‌های کمکی ──
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
      ],
    ),
    child: child,
  );
  Widget _buildGroupRow(Map<String, dynamic> t) {
    final hasGroup = (t['group_name'] ?? '').toString().isNotEmpty;
    final color = _parseColor(t['group_color']);

    return InkWell(
      onTap: _canEdit ? _showGroupSheet : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(
            'گروه',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const Spacer(),
          if (hasGroup) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              t['group_name'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ] else
            Text(
              'بدون گروه',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          if (_canEdit) ...[
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 16, color: _primary),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    ],
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  String _periodLabel(String? p) => switch (p) {
    'daily' => 'روزانه',
    'weekly' => 'هفتگی',
    'monthly' => 'ماهانه',
    _ => '—',
  };

  (Color, String) _statusInfo(String s) => switch (s) {
    'completed' => (const Color(0xFF22C55E), 'انجام شده'),
    'in_progress' => (const Color(0xFF3B82F6), 'در جریان'),
    'delegated' => (const Color(0xFFF59E0B), 'ارجاع شده'),
    'approved' => (const Color(0xFF22C55E), 'تأیید شده'),
    'rejected' => (const Color(0xFFEF4444), 'رد شده'),
    _ => (const Color(0xFF9CA3AF), 'شروع نشده'),
  };

  (Color, String) _priorityInfo(String p) => switch (p) {
    'high' => (const Color(0xFFEF4444), 'اولویت بالا'),
    'medium' => (const Color(0xFFF59E0B), 'اولویت متوسط'),
    'low' => (const Color(0xFF22C55E), 'اولویت پایین'),
    _ => (const Color(0xFF9CA3AF), '—'),
  };

  (Color, IconData, String) _actionInfo(String a) => switch (a) {
    'created' => (
      const Color(0xFF6C63FF),
      Icons.add_circle_outline,
      'ایجاد شد',
    ),
    'started' || 'in_progress' => (
      const Color(0xFF3B82F6),
      Icons.play_circle_outline,
      'شروع شد',
    ),
    'completed' => (
      const Color(0xFF22C55E),
      Icons.check_circle_outline,
      'تکمیل شد',
    ),
    'pending_approval' => (
      const Color(0xFFF59E0B),
      Icons.hourglass_empty_rounded,
      'منتظر تأیید',
    ),
    'approved' || 'completion_approved' => (
      const Color(0xFF22C55E),
      Icons.verified_outlined,
      'تأیید شد',
    ),
    'rejected' || 'completion_rejected' => (
      const Color(0xFFEF4444),
      Icons.cancel_outlined,
      'رد شد',
    ),
    'delegated' => (const Color(0xFFF59E0B), Icons.send_outlined, 'ارجاع شد'),
    'assigned' => (
      const Color(0xFF3B82F6),
      Icons.person_add_outlined,
      'تخصیص یافت',
    ),
    'stopped' => (
      const Color(0xFF9CA3AF),
      Icons.stop_circle_outlined,
      'متوقف شد',
    ),
    'reopened' => (
      const Color(0xFF3B82F6),
      Icons.refresh_rounded,
      'بازگشایی شد',
    ),
    'deleted' => (
      const Color(0xFFEF4444),
      Icons.delete_outline_rounded,
      'حذف شد',
    ),
    'updated' => (const Color(0xFF6C63FF), Icons.edit_outlined, 'ویرایش شد'),
    _ => (const Color(0xFF9CA3AF), Icons.circle_outlined, a),
  };
}
