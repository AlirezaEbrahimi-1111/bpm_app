import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/widgets/app_snack.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../core/network/api_client.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/persian_number.dart';
import 'dart:convert';
import '../../core/utils/task_labels.dart';
import '../shell/widgets/offline_banner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/scrollable_chip_row.dart';
import '../../core/theme/theme_controller.dart';
import 'widgets/persian_date_picker_sheet.dart';
import 'widgets/task_group_management_sheet.dart';
import 'create_task_page.dart';

class TaskDetailPage extends StatefulWidget {
  final int taskId;
  final int? currentUserId;
  const TaskDetailPage({super.key, required this.taskId, this.currentUserId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  static const _primary = Color(0xFF6C63FF);

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
  List<dynamic> _viewers = [];
  List<dynamic> _deadlineRequests = [];
  List<dynamic> _overdueClearRequests = [];
  Map<String, dynamic>? _renewalRequest;
  Map<String, dynamic>? _terminationRequest;

  // 🔧 آفلاین سبک: جزئیات این کار از کش (نه تازه از سرور) نمایش داده می‌شود
  bool _isOfflineData = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = ApiClient.currentUserId; // ← از منبع سراسری مطمئن
    _loadDetail();
  }

  // 🔧 اصلاح باگ: چون Dio به‌صورت پیش‌فرض روی هر status code غیرِ ۲xx
  // (مثلاً ۴۰۰/۴۰۳/۴۰۹/۵۰۰ که خیلی از این endpoint ها برمی‌گردانند)
  // Exception پرتاب می‌کند، پیام واقعی سرور (که PHP در بدنه‌ی JSON
  // پاسخ گذاشته) هیچ‌وقت به catch نمی‌رسید و قبلاً همیشه پیام عمومیِ
  // «خطا در اتصال به سرور» نمایش داده می‌شد — حتی وقتی واقعاً سرور
  // جواب داده بود، فقط با یک پیامِ خطای معنادار. این تابع پیام واقعی
  // را (اگر موجود باشد) استخراج می‌کند.
  String _dioErrorMessage(Object e, String fallback) {
    if (e is dio.DioException && e.response?.data is Map) {
      final msg = (e.response!.data as Map)['message'];
      if (msg != null && msg.toString().trim().isNotEmpty)
        return msg.toString();
    }
    return fallback;
  }

  String get _offlineCacheKey => 'task_detail_${widget.taskId}';

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
        setState(() {
          _task = res.data['task'];
          _history = res.data['history'] ?? [];
          _canEdit = res.data['can_edit'] == true;
          _isDeleted =
              res.data['task']?['is_deleted'] == 1 ||
              res.data['task']?['is_deleted'] == true;
          _isOfflineData = false;
          _isLoading = false;
        });
        _loadChecklist();
        _loadGroups();
        _loadUsers();
        _loadAttachments();
        if (_canEdit) _loadViewers();
        _loadDeadlineRequests();
        _loadOverdueClearRequests();
        _loadRenewalRequest();
        _loadTerminationRequest();
        // 🔧 آفلاین سبک: کش جزئیات همین کار، فقط برای مشاهده وقتی بعداً
        // اینترنت نبود
        ApiClient.saveOfflineCache(_offlineCacheKey, {
          'task': _task,
          'history': _history,
          'can_edit': _canEdit,
        });
      } else {
        setState(() {
          _error = res.data['message'] ?? 'خطا در دریافت اطلاعات';
          _isLoading = false;
        });
      }
    } catch (e) {
      final cached = await ApiClient.readOfflineCache(_offlineCacheKey);
      if (cached != null && cached['data'] is Map) {
        final data = Map<String, dynamic>.from(cached['data']);
        setState(() {
          _task = data['task'];
          _history = data['history'] ?? [];
          _canEdit = data['can_edit'] == true;
          _isDeleted =
              data['task']?['is_deleted'] == 1 ||
              data['task']?['is_deleted'] == true;
          _isOfflineData = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = (e is dio.DioException && e.response == null)
              ? 'اینترنت ندارید و هنوز داده‌ای برای نمایش آفلاین ذخیره نشده'
              : 'خطا در اتصال به سرور';
          _isLoading = false;
        });
      }
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
        AppSnack.success('✅ موفق', 'گروه به‌روزرسانی شد');
      } else {
        AppSnack.error('خطا', res.data['message'] ?? 'خطا در تغییر گروه');
      }
    } catch (e) {
      print('❌ Group error: $e');
      if (e is dio.DioException) {
        print('📋 Status: ${e.response?.statusCode}');
        print('📋 Data: ${e.response?.data}');
      }
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  void _showGroupSheet() {
    final c = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surfaceContainerLow,
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
                    title: Text(
                      g['name'] ?? '',
                      style: TextStyle(color: c.textStrong),
                    ),
                    onTap: () {
                      Get.back();
                      _changeGroup(g['id']);
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
        AppSnack.success('✅ موفق', 'فایل آپلود شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در آپلود');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      AppSnack.error('خطا', 'خطا در آپلود فایل');
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
        AppSnack.success('✅ موفق', 'فایل حذف شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در حذف');
      }
    } catch (e) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Future<void> _renameAttachment(int attId, String newName) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/rename-attachment.php',
        data: {'attachment_id': attId, 'new_name': newName},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _loadAttachments();
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تغییر نام');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  void _showRenameAttachmentDialog(Map<String, dynamic> att) {
    // 🔧 اسم بدون پسوند نشون داده می‌شه چون سرور خودش پسوندِ قبلی رو
    // به نامِ جدید اضافه می‌کنه (rename-attachment.php)
    final currentName = (att['file_original_name'] ?? '').toString();
    final dotIndex = currentName.lastIndexOf('.');
    final nameWithoutExt = dotIndex > 0
        ? currentName.substring(0, dotIndex)
        : currentName;
    final controller = TextEditingController(text: nameWithoutExt);
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تغییر نام فایل',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'نام جدید را وارد کنید',
            hintStyle: TextStyle(color: c.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Get.back();
              _renameAttachment(att['id'], name);
            },
            child: Text('ذخیره', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    final url = '${ApiClient.baseUrl}/$filePath';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      AppSnack.error('خطا', 'امکان باز کردن فایل نیست');
    }
  }

  Future<void> _loadViewers() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/list-viewers.php',
        queryParameters: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(() => _viewers = data['viewers'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _addViewer(int userId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/add-viewers.php',
        data: {
          'task_id': widget.taskId,
          'user_ids': [userId],
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _loadViewers();
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در افزودن بیننده');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _removeViewer(int userId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/remove-viewer.php',
        data: {'task_id': widget.taskId, 'user_id': userId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _loadViewers();
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در حذف بیننده');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  // ── تمدید موعد انجام ──────────────────────────────

  Future<void> _loadDeadlineRequests() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/get-deadline-requests.php',
        queryParameters: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(() => _deadlineRequests = data['requests'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _requestDeadlineExtension(
    DateTime newDeadline,
    String reason,
  ) async {
    final dateStr =
        '${newDeadline.year.toString().padLeft(4, '0')}-${newDeadline.month.toString().padLeft(2, '0')}-${newDeadline.day.toString().padLeft(2, '0')}';
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
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ ثبت شد',
          data['message'] ?? 'درخواست تمدید موعد ثبت شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ثبت درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _approveDeadlineRequest(int requestId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-deadline.php',
        data: {'request_id': requestId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success('✅ تأیید شد', data['message'] ?? 'درخواست تأیید شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تأیید درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _rejectDeadlineRequest(int requestId, String reason) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/reject-deadline.php',
        data: {'request_id': requestId, 'rejection_reason': reason},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.warning('رد شد', data['message'] ?? 'درخواست رد شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در رد درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  // ── رفع تأخیرِ دوره‌ای ─────────────────────────────

  Future<void> _loadOverdueClearRequests() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/get-overdue-clear-requests.php',
        queryParameters: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(() => _overdueClearRequests = data['requests'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _requestOverdueClear(String reason) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/request-overdue-clear.php',
        data: {'task_id': widget.taskId, 'reason': reason},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ ثبت شد',
          data['message'] ?? 'درخواست رفع تأخیر ثبت شد',
        );
      } else {
        AppSnack.warning('توجه', data['message'] ?? 'خطا در ثبت درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _approveOverdueClear(int requestId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-overdue-clear.php',
        data: {'request_id': requestId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success('✅ تأیید شد', data['message'] ?? 'درخواست تأیید شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تأیید درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _rejectOverdueClear(int requestId, String reason) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/reject-overdue-clear.php',
        data: {'request_id': requestId, 'rejection_reason': reason},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.warning('رد شد', data['message'] ?? 'درخواست رد شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در رد درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  // ── تمدید دوره ─────────────────────────────────────

  Future<void> _loadRenewalRequest() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/get-pending-renewal.php',
        queryParameters: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(
          () => _renewalRequest = data['request'] as Map<String, dynamic>?,
        );
      }
    } catch (_) {}
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _todayIso() => _isoDate(DateTime.now());

  Future<void> _applyRenewalDirect(
    DateTime newStart,
    DateTime? newEnd,
    String reason,
  ) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/apply-renewal.php',
        data: {
          'task_id': widget.taskId,
          'new_start_date': _isoDate(newStart),
          if (newEnd != null) 'new_end_date': _isoDate(newEnd),
          'reason': reason,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ تمدید شد',
          data['message'] ?? 'دوره‌ی کار تمدید شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تمدید دوره');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _requestRenewal(
    DateTime newStart,
    DateTime? newEnd,
    String reason,
  ) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/request-renewal.php',
        data: {
          'task_id': widget.taskId,
          'new_start_date': _isoDate(newStart),
          if (newEnd != null) 'new_end_date': _isoDate(newEnd),
          'reason': reason,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ ثبت شد',
          data['message'] ?? 'درخواست تمدید دوره ثبت شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ثبت درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _approveRenewal(int requestId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-renewal.php',
        data: {'request_id': requestId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success('✅ تأیید شد', data['message'] ?? 'درخواست تأیید شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تأیید درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _rejectRenewal(int requestId, String reason) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/reject-renewal.php',
        data: {'request_id': requestId, 'rejection_reason': reason},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.warning('رد شد', data['message'] ?? 'درخواست رد شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در رد درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  // ── درخواست/بررسیِ اتمام کار دوره‌ای ─────────────────

  Future<void> _loadTerminationRequest() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/tasks/get-termination-request.php',
        queryParameters: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        setState(
          () => _terminationRequest = data['request'] as Map<String, dynamic>?,
        );
      }
    } catch (_) {}
  }

  Future<void> _requestTermination(String reason) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/request-termination.php',
        data: {'task_id': widget.taskId, 'reason': reason},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ ثبت شد',
          data['message'] ?? 'درخواست اتمام کار ثبت شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ثبت درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _reviewTermination(
    int requestId, {
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/review-termination.php',
        data: {
          'request_id': requestId,
          'action': approve ? 'approve' : 'reject',
          if (!approve) 'rejection_reason': rejectionReason ?? '',
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          approve ? '✅ تأیید شد' : 'رد شد',
          data['message'] ?? '',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در بررسی درخواست');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _terminatePeriodNow() async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/terminate-period.php',
        data: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success('✅ اتمام یافت', data['message'] ?? 'کار اتمام یافت');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در اتمام کار');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
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
      // 🔧 رفعِ باگ: list-all.php مخصوصِ صفحه‌ی مدیریتِ گروه‌هاست و نیازِ
      // مجوزِ manage_task_groups دارد — کارمندِ عادی با آن ۴۰۳ می‌گرفت و
      // فهرستِ گروه‌ها همیشه خالی می‌ماند. list.php همان فیلترِ
      // شخصی+سازمانی را سمتِ سرور انجام می‌دهد، بدون نیاز به آن مجوز.
      final res = await ApiClient.dio.get('/api/task-groups/list.php');
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
      AppSnack.warning('قفل', 'این آیتم تکمیل شده و قابل تغییر نیست');
      return;
    }
    if (item['can_toggle_this'] != true) {
      AppSnack.warning('توجه', 'این آیتم به فرد دیگری ارجاع شده است');
      return;
    }
    final newValue = !(item['is_done'] == 1 || item['is_done'] == true);
    try {
      final res = await ApiClient.dio.post(
        '/api/checklist/toggle.php',
        data: {'item_id': item['id'], 'is_done': newValue},
      );
      if (res.data['success'] == true) {
        // 🔧 اصلاح: حتماً باید ست شود تا وقتی از این صفحه خارج می‌شویم،
        // صفحه‌ی «لیست کارها» بفهمد چیزی تغییر کرده و خودش را تازه کند
        // (وگرنه وضعیتِ قدیمی/نادرست در لیست باقی می‌ماند).
        _hasChanges = true;

        _loadChecklist();
        // 🔧 اصلاح: قبلاً فقط وقتی auto_completed بود جزئیات کار
        // تازه‌سازی می‌شد؛ برای همین با تیک زدن اولین آیتم، وضعیت بالای
        // صفحه («شروع نشده») به‌روز نمی‌شد. الان همیشه تازه‌سازی می‌کنیم.
        _loadDetail();

        if (res.data['auto_completed'] == true) {
          AppSnack.success(
            '✅ تکمیل شد',
            'همه آیتم‌های چک‌لیست تکمیل شدند. کار طبق روال ادامه یافت.',
          );
        }
      } else {
        AppSnack.error('خطا', res.data['message'] ?? 'خطا در تغییر آیتم');
      }
    } catch (e) {
      print('❌ Toggle error: $e');
      if (e is dio.DioException) {
        print('📋 Status: ${e.response?.statusCode}');
        print('📋 Data: ${e.response?.data}');
      }
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  // ── چک‌لیست: افزودن/ویرایش/حذف آیتم (فقط تعریف‌کننده) ──

  Future<void> _addChecklistItem(String title) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/checklist/add-item.php',
        data: {'task_id': widget.taskId, 'title': title},
      );
      if (res.data['success'] == true) {
        _hasChanges = true;
        _loadChecklist();
      } else {
        AppSnack.error('خطا', res.data['message'] ?? 'خطا در افزودن آیتم');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _editChecklistItem(int itemId, String title) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/checklist/update-item.php',
        data: {'item_id': itemId, 'title': title},
      );
      if (res.data['success'] == true) {
        _hasChanges = true;
        _loadChecklist();
      } else {
        AppSnack.error('خطا', res.data['message'] ?? 'خطا در ویرایش آیتم');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  Future<void> _deleteChecklistItem(int itemId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/checklist/delete-item.php',
        data: {'item_id': itemId},
      );
      if (res.data['success'] == true) {
        _hasChanges = true;
        _loadChecklist();
        _loadDetail();
      } else {
        AppSnack.error('خطا', res.data['message'] ?? 'خطا در حذف آیتم');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  void _showAddChecklistItemDialog() {
    final controller = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'افزودن آیتم چک‌لیست',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'عنوان آیتم را وارد کنید',
            hintStyle: TextStyle(color: c.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              Get.back();
              _addChecklistItem(title);
            },
            child: Text('افزودن', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  void _showEditChecklistItemDialog(Map<String, dynamic> item) {
    final controller = TextEditingController(
      text: item['title']?.toString() ?? '',
    );
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ویرایش آیتم چک‌لیست',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'عنوان آیتم را وارد کنید',
            hintStyle: TextStyle(color: c.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              Get.back();
              _editChecklistItem(item['id'], title);
            },
            child: Text('ذخیره', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChecklistItem(Map<String, dynamic> item) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف آیتم چک‌لیست',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Text(
          'آیا از حذف این آیتم مطمئن هستید؟',
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
              _deleteChecklistItem(item['id']);
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
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
    final c = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Get.back(result: _hasChanges);
      },
      child: Scaffold(
        backgroundColor: c.bgPage,
        appBar: AppBar(
          backgroundColor: c.bgPage,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'جزئیات کار',
            style: TextStyle(
              color: c.textStrong,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          leading: IconButton(
            icon: Transform.rotate(
              angle: math.pi,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: c.textStrong,
                size: 20,
              ),
            ),
            onPressed: () => Get.back(result: _hasChanges),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _error != null
            ? _buildError(c)
            : Column(
                children: [
                  if (_isOfflineData) const OfflineBanner(),
                  Expanded(child: _buildContent()),
                ],
              ),
        bottomNavigationBar: (_isLoading || _error != null || _task == null)
            ? null
            : _buildActionBar(),
      ),
    );
  }

  Widget _buildError(AppColors c) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 48, color: c.textMuted),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: c.textMuted)),
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
      final c = AppColors.of(context);
      return SafeArea(
        top: false,
        // 🔧 طبق درخواست: فاصله‌ی بیشتر از پایین
        minimum: const EdgeInsets.only(bottom: 18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: _floatingBar(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: c.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'این کار حذف شده است',
                  style: TextStyle(fontSize: 13, color: c.textMuted),
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
          // 🔧 بسط دیالوگِ تأییدِ ساده — اگر تعریف‌کننده یا مسئولِ فعلی
          // گزینه‌ی بیشتری داشته باشند، یک شیتِ کوچک انتخاب باز می‌شود؛
          // وگرنه مستقیم همان تأییدِ ساده‌ی قبلی انجام می‌شود
          onTap: () => _showApproveOptionsSheet(
            isCreator: isCreator,
            isAssignee: isAssignee,
          ),
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

    // ── یادآوری (فقط تعریف‌کننده، وقتی خودش مسئولِ انجام نیست) ──
    final canRemind =
        isCreator &&
        !isAssignee &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected';
    if (canRemind) {
      buttons.add(
        _circleAction(
          icon: Icons.notifications_active_outlined,
          label: 'یادآوری',
          color: const Color(0xFF8E57FE),
          onTap: _showSendReminderDialog,
        ),
      );
    }

    // ── تمدید موعد (فقط مسئولِ فعلی، برای کارِ غیرِ روتین با موعد) ──
    final canRequestDeadline =
        isAssignee &&
        t['is_workflow_task'] != 1 &&
        t['is_workflow_task'] != true &&
        t['deadline'] != null &&
        !isPending &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected' &&
        t['has_pending_deadline_request'] != 1 &&
        t['has_pending_deadline_request'] != true;
    if (canRequestDeadline) {
      buttons.add(
        _circleAction(
          icon: Icons.event_repeat_rounded,
          label: 'تمدید موعد',
          color: const Color(0xFF3B82F6),
          onTap: _showRequestDeadlineDialog,
        ),
      );
    }

    // ── رفع تأخیرِ دوره‌ای (مسئول یا تعریف‌کننده، فقط کارِ دوره‌ای) ──
    final canRequestOverdueClear =
        (isAssignee || isCreator) &&
        t['task_type'] == 'continuous' &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected' &&
        t['has_pending_overdue_request'] != 1 &&
        t['has_pending_overdue_request'] != true;
    if (canRequestOverdueClear) {
      buttons.add(
        _circleAction(
          icon: Icons.history_toggle_off_rounded,
          label: 'رفع تأخیر',
          color: const Color(0xFF3B82F6),
          onTap: _showRequestOverdueClearDialog,
        ),
      );
    }

    // ── تمدید دوره (فقط کارِ دوره‌ای که پایانِ دوره‌اش رسیده) ──
    final isReadyForRenewal =
        t['task_type'] == 'continuous' &&
        (t['end_date'] ?? '').toString().isNotEmpty &&
        (t['end_date'].toString().compareTo(_todayIso()) <= 0) &&
        t['is_pending_approval'] != 1 &&
        t['is_pending_approval'] != true &&
        t['has_pending_renewal_request'] != 1 &&
        t['has_pending_renewal_request'] != true;
    if (isReadyForRenewal && isCreator) {
      buttons.add(
        _circleAction(
          icon: Icons.autorenew_rounded,
          label: 'تمدید دوره',
          color: const Color(0xFF3B82F6),
          onTap: () => _showRenewalDialog(directApply: true),
        ),
      );
    } else if (isReadyForRenewal && isAssignee) {
      buttons.add(
        _circleAction(
          icon: Icons.autorenew_rounded,
          label: 'درخواست تمدید',
          color: const Color(0xFF3B82F6),
          onTap: () => _showRenewalDialog(directApply: false),
        ),
      );
    }

    // ── اتمام کار دوره‌ای ──
    final canRequestTermination =
        isAssignee &&
        !isCreator &&
        t['task_type'] == 'continuous' &&
        (status == 'not_started' || status == 'in_progress');
    if (canRequestTermination) {
      buttons.add(
        _circleAction(
          icon: Icons.flag_outlined,
          label: 'درخواست اتمام',
          color: const Color(0xFFF59E0B),
          onTap: _showRequestTerminationDialog,
        ),
      );
    }
    final canTerminateNow =
        isCreator &&
        (t['task_type'] == 'periodic' || t['task_type'] == 'continuous') &&
        status != 'completed' &&
        status != 'approved';
    if (canTerminateNow) {
      buttons.add(
        _circleAction(
          icon: Icons.flag_circle_outlined,
          label: 'اتمام دوره',
          color: const Color(0xFFF59E0B),
          onTap: _confirmTerminatePeriodNow,
        ),
      );
    }

    // ── بازتعریف کار (تعریف‌کننده یا مسئولِ فعلی) ──
    if (_canEdit || isAssignee) {
      buttons.add(
        _circleAction(
          icon: Icons.copy_all_outlined,
          label: 'بازتعریف',
          color: const Color(0xFF8B5CF6),
          onTap: _openRedefine,
        ),
      );
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

    return SafeArea(
      top: false,
      // 🔧 طبق درخواست: فاصله‌ی بیشتر از پایین — قبلاً فقط ۸ بود و
      // خیلی به لبه/دکمه‌های ناوبریِ گوشی چسبیده بود
      minimum: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: _floatingBar(
          // 🔧 تا ۵ دکمه: یک ردیفِ وسط‌چین؛ بیشتر از ۵: ردیفِ افقیِ اسکرول‌شونده
          // با فلشِ چپ/راست تا کاربر بداند دکمه‌های بیشتری هست
          child: buttons.length > 5
              ? ScrollableChipRow(gap: 22, children: buttons)
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 22,
                  runSpacing: 10,
                  children: buttons,
                ),
        ),
      ),
    );
  }

  // 🔧 کادرِ شناورِ نوار پایین — گرد مثل تلگرام، با حاشیه از کناره‌ها
  // (باریک‌تر از عرض کامل صفحه) و سایه‌ی بنفشِ سازمانی تا از پس‌زمینه
  // مجزا دیده شود.
  //
  // 🔧 طبق درخواست: قبلاً وقتی دکمه‌ها زیاد بودند (۴-۵ تا)، ردیف از
  // عرضِ کادر سرریز می‌کرد و دکمه‌های کناری از کادر بیرون می‌زدند. حالا
  // به‌جای یک ردیفِ ثابت/اسکرول‌شونده (که خودش شکننده بود)، از Wrap
  // استفاده می‌شود: اگر دکمه‌ها جا شوند در یک ردیفِ وسط‌چین می‌مانند؛
  // اگر جا نشوند، به‌طورِ خودکار (و همیشه داخلِ کادر) به خطِ بعد می‌روند —
  // هرگز از کادر بیرون نمی‌زنند.
  Widget _floatingBar({required Widget child}) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // دکمه دایره‌ای آیکونی + برچسب زیرش
  // 🔧 اصلاح: عنوان زیر دکمه حذف شد (فقط به‌صورت Tooltip در دسترس
  // است) و دایره ~۲۰٪ کوچک‌تر شد (۵۲ → ۴۲)
  Widget _circleAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: _isUpdating ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: _isUpdating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: Colors.white, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  // 🔧 محافظِ ساخت: اگر هر بخشی از بدنه (به‌خاطرِ داده‌ی غیرمنتظره) استثنا
  // پرتاب کند، به‌جای یک صفحه‌ی کاملاً خالی/خاکستری (ErrorWidgetِ پیش‌فرضِ
  // ریلیز)، پیامِ خطای واقعی نمایش داده می‌شود تا هم کاربر گیج نشود، هم
  // بتوان علتِ دقیق را از رویِ همین متن پیدا کرد
  Widget _buildContent() {
    try {
      return _buildContentBody();
    } catch (e) {
      final c = AppColors.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: c.danger),
              const SizedBox(height: 12),
              Text(
                'خطا در نمایش جزئیات کار',
                style: TextStyle(
                  color: c.textStrong,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: TextStyle(color: c.textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildContentBody() {
    final t = _task!;
    final status = t['status'] as String? ?? '';
    final priority = t['priority'] as String? ?? '';
    final statusLbl = TaskLabels.statusLabel(status);
    final statusClr = TaskLabels.statusColor(status);
    final priorityLbl = TaskLabels.priorityLabel(priority);
    final priorityClr = TaskLabels.priorityColor(priority);
    final isContinuous = t['task_type'] == 'continuous';
    final c = AppColors.of(context);
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
                // عنوان — طبق عکسِ ارسالی، عنوان تمام‌عرض و خودش یک ردیفِ
                // جداست؛ نشان‌ها همه با هم در ردیفِ بعدی می‌آیند
                Text(
                  t['title'] ?? '',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.textStrong,
                  ),
                ),
                const SizedBox(height: 10),
                // نشان‌ها — طبقِ عکس: اولویت+نوع (پرشده) سمتِ راست،
                // وضعیت (فقط قاب/بدونِ پرشدگی) سمتِ چپ
                Row(
                  children: [
                    _chip(priorityLbl, priorityClr),
                    const SizedBox(width: 8),
                    _chip(isContinuous ? 'دوره‌ای' : 'مقطعی', c.primary),
                    const Spacer(),
                    _outlineChip(statusLbl, statusClr),
                  ],
                ),
                if ((t['description'] ?? '').toString().isNotEmpty) ...[
                  Divider(height: 28, color: c.borderSoft),
                  Text(
                    'توضیحات',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textStrong,
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
                const Divider(height: 26),
                _infoRow(
                  Icons.assignment_ind_outlined,
                  'مسئول',
                  t['assignee_name'] ?? '—',
                ),
                const Divider(height: 26),
                if (isContinuous) ...[
                  _infoRow(
                    Icons.play_circle_outline,
                    'تاریخ شروع',
                    _toShamsi(t['start_date']),
                  ),
                  const Divider(height: 26),
                  _infoRow(
                    Icons.event_busy_outlined,
                    'تاریخ پایان',
                    _toShamsi(t['end_date']),
                  ),
                  const Divider(height: 26),
                  _infoRow(
                    Icons.repeat_rounded,
                    'دوره تکرار',
                    TaskLabels.periodLabel(t['period_type']),
                  ),
                ] else
                  _infoRow(
                    Icons.event_outlined,
                    'موعد انجام',
                    _toShamsi(t['due_date']),
                  ),
                const Divider(height: 26),
                _buildGroupRow(t),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── درخواست‌های باز (تمدید موعد / رفع تأخیرِ دوره‌ای) ──
          ..._deadlineRequests.map(
            (r) => _requestBanner(
              icon: Icons.event_repeat_rounded,
              title: 'درخواست تمدید موعد',
              subtitle:
                  '${r['requester_name'] ?? ''} — تا ${r['requested_new_deadline_jalali'] ?? ''}',
              isApprover: r['is_approver'] == true,
              onReview: () => _showDeadlineReviewDialog(r),
            ),
          ),
          ..._overdueClearRequests.map(
            (r) => _requestBanner(
              icon: Icons.history_toggle_off_rounded,
              title: 'درخواست رفع تأخیرِ دوره‌ای',
              subtitle:
                  '${r['requester_name'] ?? ''} — ${toPersianDigits(r['periods_count']?.toString() ?? '0')} دوره',
              isApprover: r['is_approver'] == true,
              onReview: () => _showOverdueClearReviewDialog(r),
            ),
          ),
          if (_renewalRequest != null)
            _requestBanner(
              icon: Icons.autorenew_rounded,
              title: 'درخواست تمدید دوره',
              subtitle:
                  '${_renewalRequest!['requester_name'] ?? ''} — از ${toPersianDigits(_renewalRequest!['new_start_date']?.toString() ?? '')}',
              isApprover:
                  _currentUserId != null &&
                  _renewalRequest!['current_approver_id']?.toString() ==
                      _currentUserId.toString(),
              onReview: () => _showRenewalReviewDialog(_renewalRequest!),
            ),
          if (_terminationRequest != null)
            _requestBanner(
              icon: Icons.flag_outlined,
              title: 'درخواست اتمام کار',
              subtitle:
                  _terminationRequest!['requester_name']?.toString() ?? '',
              isApprover:
                  _currentUserId != null &&
                  _terminationRequest!['reviewer_id']?.toString() ==
                      _currentUserId.toString(),
              onReview: () =>
                  _showTerminationReviewDialog(_terminationRequest!),
            ),
          // ── چک‌لیست ──
          // 🔧 قبلاً فقط وقتی آیتمی از قبل بود نمایش داده می‌شد؛ حالا اگر
          // تعریف‌کننده باشیم، حتی با چک‌لیست خالی هم بخش نشان داده
          // می‌شود تا بشود اولین آیتم را اضافه کرد
          if (_checklistTotal > 0 || _canEdit) ...[
            _sectionHeader(
              c,
              title: 'چک‌لیست',
              extra: _checklistTotal > 0
                  ? toPersianDigits('$_checklistDone از $_checklistTotal')
                  : null,
              open: _checklistOpen,
              onToggle: () => setState(() => _checklistOpen = !_checklistOpen),
              trailing: _canEdit
                  ? _addPillButton(
                      c,
                      label: 'افزودن',
                      onTap: _showAddChecklistItemDialog,
                    )
                  : null,
            ),
            _accordionBody(
              _checklistOpen,
              _card(
                child: Column(
                  children: [
                    if (_checklistTotal > 0) ...[
                      // نوار پیشرفت
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _checklistPercent / 100,
                          minHeight: 8,
                          backgroundColor: c.borderSoft,
                          valueColor: AlwaysStoppedAnimation(c.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // آیتم‌ها
                      ..._checklist.map((item) => _checklistItem(item)),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'هنوز آیتمی اضافه نشده',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ── بینندگان (فقط تعریف‌کننده مدیریت می‌کند) ──
          if (_canEdit) ...[
            _sectionHeader(
              c,
              title: 'بینندگان',
              open: _viewersOpen,
              onToggle: () => setState(() => _viewersOpen = !_viewersOpen),
              trailing: _addPillButton(
                c,
                label: 'افزودن',
                onTap: _showManageViewersSheet,
              ),
            ),
            _accordionBody(
              _viewersOpen && _viewers.isNotEmpty,
              _card(
                child: Column(
                  children: _viewers
                      .map(
                        (v) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: c.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  size: 15,
                                  color: c.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  (v['full_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? 'کاربر'
                                      : v['full_name'].toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textStrong,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _removeViewer(v['id']),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // ── پیوست‌ها ──
          _sectionHeader(
            c,
            title: 'پیوست‌ها',
            open: _attachmentsOpen,
            onToggle: () =>
                setState(() => _attachmentsOpen = !_attachmentsOpen),
            trailing: _addPillButton(
              c,
              label: 'افزودن',
              onTap: _isUploading ? null : _pickAndUploadFile,
              loading: _isUploading,
            ),
          ),
          _accordionBody(
            _attachmentsOpen,
            _attachments.isEmpty
                ? _card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'فایلی پیوست نشده',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                : _card(
                    child: Column(
                      children: _attachments
                          .map((a) => _attachmentItem(a))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // ── تاریخچه ──
          if (_history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  // 🔧 طبق درخواست: آیکن پشتِ (سمتِ راستِ) متن
                  Icon(Icons.history_rounded, size: 16, color: c.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'تاریخچه فعالیت‌ها',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.textStrong,
                    ),
                  ),
                ],
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

  // 🔧 طبق درخواست: چک‌لیست/بینندگان/پیوست‌ها آکاردئونی و پیش‌فرض بسته
  bool _checklistOpen = false;
  bool _viewersOpen = false;
  bool _attachmentsOpen = false;

  Widget _sectionHeader(
    AppColors c, {
    required String title,
    String? extra,
    required bool open,
    required VoidCallback onToggle,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            // 🔧 طبق درخواست: فلش «قبل» از عنوان (سمتِ راستِ آن) و رو به چپ.
            // chevron_right در تمِ RTL خودکار آینه می‌شود و رو به چپ دیده می‌شود.
            AnimatedRotation(
              turns: open ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: c.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: c.textStrong,
              ),
            ),
            if (extra != null) ...[
              const SizedBox(width: 8),
              Text(extra, style: TextStyle(fontSize: 13, color: c.textMuted)),
            ],
            const Spacer(),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _accordionBody(bool open, Widget child) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: open ? child : const SizedBox(width: double.infinity),
    );
  }

  void _showDelegateSheet() {
    if (_users.isEmpty) {
      AppSnack.warning('توجه', 'کاربری برای ارجاع یافت نشد');
      return;
    }

    int? selectedUserId;
    String? selectedUserName;
    String searchQuery = '';
    final notesController = TextEditingController();
    final searchController = TextEditingController();

    String userDisplay(dynamic u) {
      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
    }

    final c = AppColors.of(context);

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = searchQuery.trim().toLowerCase();
          final filteredUsers = q.isEmpty
              ? _users
              : _users.where((u) {
                  final display = userDisplay(u).toLowerCase();
                  final phone = (u['phone'] ?? '').toString().toLowerCase();
                  return display.contains(q) || phone.contains(q);
                }).toList();

          // 🔧 رفعِ باگ: قبلاً این شیت با mainAxisSize.min + Flexible
          // بدونِ هیچ محدودیتِ ارتفاعی ساخته می‌شد — وقتی لیستِ کاربران
          // یا کیبورد جا را کم می‌کرد، دکمه‌ی «ارجاع» از دیدِ کاربر
          // (پشتِ لبه‌ی صفحه/دکمه‌های گوشی) بیرون می‌رفت. حالا کلِ شیت
          // یک ارتفاعِ سقف‌دار دارد و فقط لیستِ کاربران داخلش اسکرول
          // می‌شود؛ نتیجه‌ی جستجو هم زنده و بدونِ نیاز به Enter/دکمه به‌روز
          // می‌شود (onChanged از قبل همین‌طور بود، مشکلِ اصلی کمبودِ فضا بود)
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              // 🔧 رفعِ باگِ «تا بالای صفحه می‌رود»: Get.bottomSheet خودش
              // (مستقل از isScrollControlled) همیشه دورِ کل محتوا یک
              // Padding(bottom: viewInsets.bottom) می‌کشد؛ اضافه‌کردنِ
              // دوباره‌اش اینجا فاصله را دوبرابر و شیت را تا نزدیکیِ
              // بالای صفحه هل می‌داد
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
                      'ارجاع کار',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: c.textStrong,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // فیلد جستجو — طبق درخواست پررنگ‌تر از قبل (نه خاکستریِ کم‌رنگ)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        autofocus: false,
                        onChanged: (v) => setSheetState(() => searchQuery = v),
                        style: TextStyle(color: c.textStrong, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'جستجوی نام یا شماره...',
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: c.textMuted,
                            size: 20,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: c.textMuted,
                                    size: 18,
                                  ),
                                  onPressed: () => setSheetState(() {
                                    searchController.clear();
                                    searchQuery = '';
                                  }),
                                )
                              : null,
                          filled: true,
                          fillColor: c.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
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
                            borderSide: BorderSide(
                              color: c.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // لیست کاربران — حالا داخلِ یک Expandedِ واقعاً
                    // محدودشده اسکرول می‌شود (نه شیتِ کل)
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? Center(
                              child: Text(
                                'نتیجه‌ای یافت نشد',
                                style: TextStyle(
                                  color: c.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView(
                              children: filteredUsers.map((u) {
                                final display = userDisplay(u);
                                final selected = selectedUserId == u['id'];
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: selected
                                        ? c.primary
                                        : c.primary.withValues(alpha: 0.12),
                                    child: Text(
                                      display.toString().isNotEmpty
                                          ? display.toString()[0]
                                          : '?',
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : c.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    display,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: c.textStrong,
                                    ),
                                  ),
                                  trailing: selected
                                      ? Icon(
                                          Icons.check_circle,
                                          color: c.primary,
                                        )
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        controller: notesController,
                        style: TextStyle(color: c.textStrong, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'توضیح (اختیاری)...',
                          hintStyle: TextStyle(
                            color: c.textMuted,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: c.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: c.borderSoft),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    // دکمه ارجاع — طبق درخواست، دیگر پشتِ دکمه‌های
                    // ناوبریِ گوشی نمی‌رود
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12 + MediaQuery.of(ctx).padding.bottom,
                      ),
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
                            backgroundColor: c.primary,
                            disabledBackgroundColor: c.primary.withValues(
                              alpha: 0.35,
                            ),
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
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> _sendReminder(String message) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/send-reminder.php',
        data: {'task_id': widget.taskId, 'message': message},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        AppSnack.success(
          '✅ ارسال شد',
          data['message'] ?? 'یادآوری با موفقیت ارسال شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ارسال یادآوری');
      }
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  void _showSendReminderDialog() {
    final messageController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      Dialog(
        backgroundColor: c.surface,
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
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: c.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ارسال یادآوری',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'متن یادآوری',
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: TextStyle(color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'مثلاً: لطفاً این کار را در اولویت قرار دهید...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
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
                        style: TextStyle(color: c.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final msg = messageController.text.trim();
                        if (msg.isEmpty) {
                          AppSnack.error('خطا', 'متن یادآوری الزامی است');
                          return;
                        }
                        Get.back();
                        _sendReminder(msg);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ارسال'),
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

  void _showRequestDeadlineDialog() {
    DateTime? selectedDate;
    final reasonController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'درخواست تمدید موعد',
            style: TextStyle(fontSize: 16, color: c.textStrong),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showCustomPersianDatePicker(
                    ctx,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: Jalali.now(),
                  );
                  if (picked != null)
                    setDialogState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: c.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selectedDate == null
                            ? 'موعد جدید را انتخاب کنید'
                            : _toShamsi(selectedDate!.toIso8601String()),
                        style: TextStyle(
                          fontSize: 13,
                          color: selectedDate == null
                              ? c.textMuted
                              : c.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'دلیل درخواست تمدید (الزامی)...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('انصراف', style: TextStyle(color: c.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (selectedDate == null) {
                  AppSnack.error('خطا', 'موعد جدید را انتخاب کنید');
                  return;
                }
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  AppSnack.error('خطا', 'دلیل درخواست الزامی است');
                  return;
                }
                Get.back();
                _requestDeadlineExtension(selectedDate!, reason);
              },
              child: Text('ارسال درخواست', style: TextStyle(color: c.primary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeadlineReviewDialog(Map<String, dynamic> request) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'بررسی درخواست تمدید موعد',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewInfoRow(
              'درخواست‌دهنده',
              request['requester_name']?.toString() ?? '',
            ),
            _reviewInfoRow(
              'موعد فعلی',
              request['current_deadline_jalali']?.toString() ?? '',
            ),
            _reviewInfoRow(
              'موعد پیشنهادی',
              request['requested_new_deadline_jalali']?.toString() ?? '',
            ),
            _reviewInfoRow('دلیل', request['reason']?.toString() ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _showRejectionReasonDialog(
                title: 'رد درخواست تمدید موعد',
                onSubmit: (reason) =>
                    _rejectDeadlineRequest(request['id'], reason),
              );
            },
            child: Text('رد', style: TextStyle(color: c.danger)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _approveDeadlineRequest(request['id']);
            },
            child: Text('تأیید', style: TextStyle(color: c.success)),
          ),
        ],
      ),
    );
  }

  void _showRequestOverdueClearDialog() {
    final reasonController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'درخواست رفع تأخیرِ دوره‌ای',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'دلیل درخواست (اختیاری)...',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
            filled: true,
            fillColor: c.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _requestOverdueClear(reasonController.text.trim());
            },
            child: Text('ارسال درخواست', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  void _showOverdueClearReviewDialog(Map<String, dynamic> request) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'بررسی درخواست رفع تأخیر',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewInfoRow(
              'درخواست‌دهنده',
              request['requester_name']?.toString() ?? '',
            ),
            _reviewInfoRow(
              'تعداد دوره‌های معوقه',
              toPersianDigits(request['periods_count']?.toString() ?? '0'),
            ),
            if ((request['reason'] ?? '').toString().isNotEmpty)
              _reviewInfoRow('دلیل', request['reason'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _showRejectionReasonDialog(
                title: 'رد درخواست رفع تأخیر',
                onSubmit: (reason) =>
                    _rejectOverdueClear(request['id'], reason),
              );
            },
            child: Text('رد', style: TextStyle(color: c.danger)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _approveOverdueClear(request['id']);
            },
            child: Text('تأیید', style: TextStyle(color: c.success)),
          ),
        ],
      ),
    );
  }

  void _showRenewalDialog({required bool directApply}) {
    DateTime? newStart;
    DateTime? newEnd;
    final reasonController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            directApply ? 'تمدید دوره' : 'درخواست تمدید دوره',
            style: TextStyle(fontSize: 16, color: c.textStrong),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showCustomPersianDatePicker(
                    ctx,
                    initialDate: newStart ?? DateTime.now(),
                    firstDate: Jalali.now(),
                  );
                  if (picked != null) setDialogState(() => newStart = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: c.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        newStart == null
                            ? 'تاریخ شروع دوره‌ی جدید'
                            : _toShamsi(newStart!.toIso8601String()),
                        style: TextStyle(
                          fontSize: 13,
                          color: newStart == null ? c.textMuted : c.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showCustomPersianDatePicker(
                    ctx,
                    initialDate: newEnd ?? newStart ?? DateTime.now(),
                    firstDate: Jalali.now(),
                  );
                  if (picked != null) setDialogState(() => newEnd = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 18,
                        color: c.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        newEnd == null
                            ? 'تاریخ پایان (اختیاری)'
                            : _toShamsi(newEnd!.toIso8601String()),
                        style: TextStyle(
                          fontSize: 13,
                          color: newEnd == null ? c.textMuted : c.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: TextStyle(color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'دلیل (اختیاری)...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('انصراف', style: TextStyle(color: c.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (newStart == null) {
                  AppSnack.error(
                    'خطا',
                    'تاریخ شروع دوره‌ی جدید را انتخاب کنید',
                  );
                  return;
                }
                Get.back();
                if (directApply) {
                  _applyRenewalDirect(
                    newStart!,
                    newEnd,
                    reasonController.text.trim(),
                  );
                } else {
                  _requestRenewal(
                    newStart!,
                    newEnd,
                    reasonController.text.trim(),
                  );
                }
              },
              child: Text(
                directApply ? 'تمدید' : 'ارسال درخواست',
                style: TextStyle(color: c.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenewalReviewDialog(Map<String, dynamic> request) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'بررسی درخواست تمدید دوره',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewInfoRow(
              'درخواست‌دهنده',
              request['requester_name']?.toString() ?? '',
            ),
            _reviewInfoRow(
              'شروع جدید',
              toPersianDigits(request['new_start_date']?.toString() ?? ''),
            ),
            _reviewInfoRow(
              'پایان جدید',
              toPersianDigits(
                (request['new_end_date'] ?? 'نامحدود').toString(),
              ),
            ),
            if ((request['reason'] ?? '').toString().isNotEmpty)
              _reviewInfoRow('دلیل', request['reason'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _showRejectionReasonDialog(
                title: 'رد درخواست تمدید دوره',
                reasonRequired: true,
                onSubmit: (reason) => _rejectRenewal(request['id'], reason),
              );
            },
            child: Text('رد', style: TextStyle(color: c.danger)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _approveRenewal(request['id']);
            },
            child: Text('تأیید', style: TextStyle(color: c.success)),
          ),
        ],
      ),
    );
  }

  void _showRequestTerminationDialog() {
    final reasonController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'درخواست اتمام کار',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'دلیل درخواست اتمام (الزامی)...',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
            filled: true,
            fillColor: c.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                AppSnack.error('خطا', 'دلیل درخواست الزامی است');
                return;
              }
              Get.back();
              _requestTermination(reason);
            },
            child: Text('ارسال درخواست', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  void _showTerminationReviewDialog(Map<String, dynamic> request) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'بررسی درخواست اتمام کار',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewInfoRow(
              'درخواست‌دهنده',
              request['requester_name']?.toString() ?? '',
            ),
            _reviewInfoRow('دلیل', request['reason']?.toString() ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _showRejectionReasonDialog(
                title: 'رد درخواست اتمام کار',
                reasonRequired: true,
                onSubmit: (reason) => _reviewTermination(
                  request['id'],
                  approve: false,
                  rejectionReason: reason,
                ),
              );
            },
            child: Text('رد', style: TextStyle(color: c.danger)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _reviewTermination(request['id'], approve: true);
            },
            child: Text('تأیید', style: TextStyle(color: c.success)),
          ),
        ],
      ),
    );
  }

  void _confirmTerminatePeriodNow() {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'اتمام دوره',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Text(
          'آیا از پایان‌دادنِ فوریِ این کارِ دوره‌ای مطمئن هستید؟',
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
              _terminatePeriodNow();
            },
            child: Text('اتمام', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  // 🔧 بازتعریف کار — یک تسکِ تازه با همان عنوان/توضیح/نوع/اولویت/گروه/
  // چک‌لیست/پیوست‌های تسکِ فعلی، برای مسئولِ جدیدی که خودِ کاربر انتخاب
  // می‌کند (فرم انتخاب مسئول/تاریخ خالی می‌ماند، دقیقاً مثل دسکتاپ)
  Future<void> _openRedefine() async {
    final t = _task;
    if (t == null) return;
    final result = await Get.to(
      () => CreateTaskPage(
        currentUserId: _currentUserId,
        redefineFrom: {
          'title': t['title'],
          'description': t['description'],
          'task_type': t['task_type'],
          'priority': t['priority'],
          'group_id': t['group_id'],
          'group_name': t['group_name'],
          'checklist_titles': _checklist.map((i) => i['title']).toList(),
          'attachment_ids': _attachments.map((a) => a['id']).toList(),
        },
      ),
    );
    if (result == true) {
      AppSnack.success(
        '✅ بازتعریف شد',
        'کار تازه ساخته شد — این کار همچنان دست‌نخورده باقی می‌ماند',
      );
    }
  }

  Widget _reviewInfoRow(String label, String value) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectionReasonDialog({
    required String title,
    required ValueChanged<String> onSubmit,
    bool reasonRequired = false,
  }) {
    final controller = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(fontSize: 16, color: c.textStrong)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: reasonRequired
                ? 'دلیل رد (الزامی)...'
                : 'دلیل رد (اختیاری)...',
            hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
            filled: true,
            fillColor: c.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reasonRequired && reason.isEmpty) {
                AppSnack.error('خطا', 'دلیل رد الزامی است');
                return;
              }
              Get.back();
              onSubmit(reason);
            },
            child: Text('رد کردن', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  void _showManageViewersSheet() {
    String searchQuery = '';
    final searchController = TextEditingController();
    final c = AppColors.of(context);

    String userDisplay(dynamic u) {
      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
    }

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) {
          final viewerIds = _viewers.map((v) => v['id'].toString()).toSet();
          final q = searchQuery.trim().toLowerCase();
          final candidates = _users.where((u) {
            if (viewerIds.contains(u['id'].toString())) return false;
            if (q.isEmpty) return true;
            final display = userDisplay(u).toLowerCase();
            final phone = (u['phone'] ?? '').toString().toLowerCase();
            return display.contains(q) || phone.contains(q);
          }).toList();

          // 🔧 رفعِ باگِ «تا بالای صفحه می‌رود»: دیگر اینجا padding برایِ
          // صفحه‌کلید اضافه نمی‌شود — Get.bottomSheet خودش (مستقل از
          // isScrollControlled) همیشه این فاصله را دورِ کل محتوا می‌کشد
          return Container(
            decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
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
                  'افزودن بیننده',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: c.textStrong,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'بیننده فقط می‌تواند کار را ببیند، بدون اقدام روی آن',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (v) => setSheetState(() => searchQuery = v),
                    style: TextStyle(color: c.textStrong),
                    decoration: InputDecoration(
                      hintText: 'جستجوی نام یا شماره...',
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
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: candidates.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'کاربری یافت نشد',
                            style: TextStyle(color: c.textMuted, fontSize: 13),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: candidates.map((u) {
                            final display = userDisplay(u);
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: c.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  display.toString().isNotEmpty
                                      ? display.toString()[0]
                                      : '?',
                                  style: TextStyle(
                                    color: c.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              title: Text(
                                display,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: c.textStrong,
                                ),
                              ),
                              trailing: Icon(
                                Icons.add_circle_outline,
                                color: c.primary,
                              ),
                              onTap: () {
                                _addViewer(u['id']);
                                setSheetState(() {});
                              },
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
    );
  }

  void _showRejectDialog() {
    final notesController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      Dialog(
        backgroundColor: c.surface,
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
                      color: c.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.cancel_outlined,
                      color: c.danger,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'رد کار',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'دلیل رد (الزامی)',
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'دلیل رد کار را بنویسید...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
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
                        style: TextStyle(color: c.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final notes = notesController.text.trim();
                        if (notes.isEmpty) {
                          AppSnack.error('خطا', 'دلیل رد الزامی است');
                          return;
                        }
                        Get.back();
                        _approveOrReject(false, notes: notes);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.danger,
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
    final c = AppColors.of(context);
    Get.dialog(
      Dialog(
        backgroundColor: c.surface,
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
                      color: c.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: c.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تکمیل کار',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'توضیحات (اختیاری)',
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: TextStyle(color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'توضیحی درباره انجام کار...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
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
                        style: TextStyle(color: c.textMuted),
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
                        backgroundColor: c.success,
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
        AppSnack.success('✅ موفق', data['message'] ?? 'کار ارجاع شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ارجاع');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
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
        AppSnack.success(
          approve ? '✅ تأیید شد' : 'رد شد',
          data['message'] ?? '',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در عملیات');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  // 🔧 «تأیید و نگه‌داری» — فقط تعریف‌کننده: کار تأیید و در فهرست خودش می‌ماند
  Future<void> _approveAndKeep() async {
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-and-keep.php',
        data: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ تأیید شد',
          data['message'] ?? 'کار تأیید و نزد شما نگه‌داشته شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در عملیات');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  // 🔧 «تأیید و ارجاع» — فقط مسئولِ فعلی: کار تأیید و هم‌زمان به فرد
  // دیگری ارجاع می‌شود
  Future<void> _approveAndDelegate(int toUserId) async {
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-and-delegate.php',
        data: {'task_id': widget.taskId, 'to_user_id': toUserId},
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success(
          '✅ تأیید شد',
          data['message'] ?? 'کار تأیید و ارجاع داده شد',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در عملیات');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  void _showApproveOptionsSheet({
    required bool isCreator,
    required bool isAssignee,
  }) {
    final c = AppColors.of(context);
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: c.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          0,
          12,
          0,
          12 + MediaQuery.of(context).padding.bottom,
        ),
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'تأیید کار',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: c.textStrong,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: c.success),
              title: Text(
                'تأیید ساده',
                style: TextStyle(fontSize: 14, color: c.textStrong),
              ),
              onTap: () {
                Get.back();
                _approveOrReject(true);
              },
            ),
            if (isCreator)
              ListTile(
                leading: Icon(Icons.person_outline, color: c.primary),
                title: Text(
                  'تأیید و نگه‌داری نزد من',
                  style: TextStyle(fontSize: 14, color: c.textStrong),
                ),
                subtitle: Text(
                  'کار تأیید می‌شود و ادامه‌ی آن نزد شما می‌ماند',
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
                onTap: () {
                  Get.back();
                  _approveAndKeep();
                },
              ),
            if (isAssignee)
              ListTile(
                leading: Icon(Icons.send_rounded, color: c.warning),
                title: Text(
                  'تأیید و ارجاع به فرد دیگر',
                  style: TextStyle(fontSize: 14, color: c.textStrong),
                ),
                onTap: () {
                  Get.back();
                  _showApproveAndDelegatePicker();
                },
              ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  void _showApproveAndDelegatePicker() {
    if (_users.isEmpty) {
      AppSnack.warning('توجه', 'کاربری برای ارجاع یافت نشد');
      return;
    }
    String searchQuery = '';
    final searchController = TextEditingController();
    final c = AppColors.of(context);

    String userDisplay(dynamic u) {
      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      return name.isEmpty ? (u['phone']?.toString() ?? 'بدون نام') : name;
    }

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = searchQuery.trim().toLowerCase();
          final filteredUsers = q.isEmpty
              ? _users
              : _users.where((u) {
                  final display = userDisplay(u).toLowerCase();
                  final phone = (u['phone'] ?? '').toString().toLowerCase();
                  return display.contains(q) || phone.contains(q);
                }).toList();

          // 🔧 رفعِ باگِ «تا بالای صفحه می‌رود»: دیگر اینجا padding برایِ
          // صفحه‌کلید اضافه نمی‌شود — Get.bottomSheet خودش این فاصله را
          // دورِ کل محتوا می‌کشد
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
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
                    'تأیید و ارجاع به',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: c.textStrong,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: (v) => setSheetState(() => searchQuery = v),
                      style: TextStyle(color: c.textStrong),
                      decoration: InputDecoration(
                        hintText: 'جستجوی نام یا شماره...',
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
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filteredUsers.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'نتیجه‌ای یافت نشد',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: filteredUsers.map((u) {
                              final display = userDisplay(u);
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: c.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Text(
                                    display.toString().isNotEmpty
                                        ? display.toString()[0]
                                        : '?',
                                    style: TextStyle(
                                      color: c.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  display,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: c.textStrong,
                                  ),
                                ),
                                onTap: () {
                                  Get.back();
                                  _approveAndDelegate(u['id']);
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.transparent,
    );
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
        AppSnack.info(
          '🗑️ حذف شد',
          'کار حذف شد',
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
        AppSnack.error('خطا', data['message'] ?? 'خطا در حذف');
      }
    } catch (e) {
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
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
        AppSnack.success('✅ بازگردانی شد', 'کار بازگردانده شد');
      }
    } catch (_) {}
  }

  void _confirmDelete() {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف کار',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Text(
          'آیا از حذف این کار مطمئن هستید؟',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await _deleteTask();
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
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
        AppSnack.success('✅ موفق', data['message'] ?? 'وضعیت به‌روزرسانی شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تغییر وضعیت');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', 'خطا در اتصال به سرور');
    }
  }

  Widget _attachmentItem(Map<String, dynamic> att) {
    final isImage = att['is_image'] == true;
    final fileType = (att['file_type'] ?? '').toString();
    final canDelete = att['can_delete'] == true;
    // 🔧 طبق rename-attachment.php، فقط کسی که خودش فایل را آپلود کرده
    // می‌تواند نامش را عوض کند (شرطش با can_delete یکی نیست)
    final canRename =
        _currentUserId != null &&
        att['uploader_id']?.toString() == _currentUserId.toString();

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
      color = ThemeController.isDark ? Colors.white : Colors.grey;
    }

    final c = AppColors.of(context);
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textStrong,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${att['file_size_formatted'] ?? ''} • ${att['uploader_name'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: c.textMuted),
                ),
              ],
            ),
          ),
          // دانلود
          IconButton(
            icon: Icon(Icons.download_outlined, size: 20, color: c.primary),
            onPressed: () => _openFile(att['file_path'] ?? ''),
          ),
          // تغییر نام
          if (canRename)
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 19, color: c.textMuted),
              onPressed: () => _showRenameAttachmentDialog(att),
            ),
          // حذف
          if (canDelete)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: c.danger),
              onPressed: () => _confirmDeleteAttachment(att['id']),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteAttachment(int attId) {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف فایل',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Text(
          'آیا از حذف این فایل مطمئن هستید؟',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // اول دیالوگ را ببند
              await _deleteAttachment(attId); // بعد حذف کن
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> h) {
    final action = h['action'] as String? ?? '';
    final actionLbl = TaskLabels.actionLabel(action);
    final actionClr = TaskLabels.actionColor(action);
    final actionIco = TaskLabels.actionIcon(action);

    // نام فردی که عمل را انجام داد
    final fromName =
        '${h['from_user_first_name'] ?? ''} ${h['from_user_last_name'] ?? ''}'
            .trim();
    // نام فرد مقصد (برای ارجاع)
    final toName =
        '${h['to_user_first_name'] ?? ''} ${h['to_user_last_name'] ?? ''}'
            .trim();
    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: actionClr.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(actionIco, color: actionClr, size: 14),
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
                      actionLbl,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textStrong,
                      ),
                    ),
                    if (fromName.isNotEmpty) ...[
                      Text(
                        ' توسط ',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                      Text(
                        fromName,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
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
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ),
                // توضیحات
                if (_formatHistoryNotes(action, h['notes']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatHistoryNotes(action, h['notes']),
                      style: TextStyle(fontSize: 12, color: c.textMuted),
                    ),
                  ),
                // تاریخ و ساعت
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _toShamsiDateTime(h['created_at']?.toString()),
                    style: TextStyle(
                      fontSize: 10,
                      color: c.textMuted.withValues(alpha: 0.7),
                    ),
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
    // 🔧 آیتمِ ارجاع‌شده سمت سرور اصلاً قابل ویرایش نیست (فقط حذف)؛
    // دکمه‌ی ویرایش رو از همون سمت کلاینت هم پنهان می‌کنیم که کاربر با
    // خطای بی‌مورد مواجه نشه
    final isAssigned = assigneeName.toString().isNotEmpty;
    final canManage = _canEdit && !isDone;
    final c = AppColors.of(context);

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
                color: isDone ? c.primary : Colors.transparent,
                border: isDone
                    ? null
                    : Border.all(
                        color: canToggle ? c.textMuted : c.borderSoft,
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
                      color: isDone ? c.textMuted : c.textStrong,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (assigneeName.toString().isNotEmpty)
                    Text(
                      'مسئول: $assigneeName',
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                ],
              ),
            ),
            // 🔧 ویرایش/حذف — فقط برای تعریف‌کننده و آیتم‌های تیک‌نخورده؛
            // ویرایش علاوه‌بر این فقط برای آیتم‌های ارجاع‌نشده (سرور
            // ویرایشِ آیتمِ ارجاع‌شده را رد می‌کند)
            if (canManage) ...[
              if (!isAssigned)
                GestureDetector(
                  onTap: () => _showEditChecklistItemDialog(item),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: c.textMuted,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () => _confirmDeleteChecklistItem(item),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: c.textMuted,
                  ),
                ),
              ),
            ]
            // قفل اگر مجاز نیست
            // قفل: یا تیک‌خورده (قفل دائم) یا مجاز نیست
            else if (isDone)
              Icon(Icons.lock_rounded, size: 16, color: c.textMuted)
            else if (!canToggle)
              Icon(
                Icons.lock_outline,
                size: 16,
                color: c.textMuted.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  // ── ویجت‌های کمکی ──
  // 🔧 کمکی‌هایِ اصلیِ محتوا (کارت/چیپ/ردیفِ اطلاعات/بنرِ درخواست) با
  // AppColors هماهنگ شدند — چون در بیشترِ صفحه استفاده می‌شوند، همین
  // چند نقطه، اکثرِ صفحه را برایِ تمِ تاریک درست می‌کند
  Widget _card({required Widget child}) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSoft),
      ),
      child: child,
    );
  }

  Widget _requestBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isApprover,
    required VoidCallback onReview,
  }) {
    final c = AppColors.of(context);
    final color = c.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: c.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isApprover)
            TextButton(
              onPressed: onReview,
              child: Text(
                'بررسی',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            )
          else
            Text(
              'در انتظار بررسی',
              style: TextStyle(fontSize: 11, color: color),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupRow(Map<String, dynamic> t) {
    final c = AppColors.of(context);
    final hasGroup = (t['group_name'] ?? '').toString().isNotEmpty;
    final color = _parseColor(t['group_color']);

    return InkWell(
      onTap: _canEdit ? _showGroupSheet : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_outlined, size: 14, color: c.primary),
          ),
          const SizedBox(width: 10),
          Text('گروه', style: TextStyle(fontSize: 13, color: c.textMuted)),
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            ),
          ] else
            Text(
              'بدون گروه',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
          if (_canEdit) ...[
            const SizedBox(width: 6),
            Icon(Icons.edit_outlined, size: 16, color: c.primary),
          ],
        ],
      ),
    );
  }

  // 🔧 طبق عکسِ ارسالی: آیکن داخلِ یک دایره‌ی کوچکِ بنفشِ کم‌رنگ (نه
  // آیکنِ ساده‌ی تنها)
  Widget _infoRow(IconData icon, String label, String value) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: c.primary),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: c.textMuted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textStrong,
          ),
        ),
      ],
    );
  }

  // 🔧 دکمه‌ی «افزودن +» بنفشِ کوچک — تکرار‌شده جلوی چک‌لیست/بینندگان/
  // پیوست‌ها (طبق عکسِ ارسالی)
  Widget _addPillButton(
    AppColors c, {
    required String label,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: c.primary),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  // 🔧 طبق عکسِ ارسالی: نشانِ وضعیت فقط قاب دارد (بدونِ پرشدگی)، برخلافِ
  // نشان‌هایِ اولویت/نوع که پرشده‌اند
  Widget _outlineChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
    ),
  );

  String _formatHistoryNotes(String action, dynamic rawNotes) {
    final notes = (rawNotes ?? '').toString();
    if (notes.isEmpty) return '';

    if (action == 'deadline_extended') {
      try {
        final data = jsonDecode(notes) as Map<String, dynamic>;
        final oldDeadline = data['old_deadline']?.toString();
        final newDeadline = data['new_deadline']?.toString();
        final reason = data['reason']?.toString();

        final parts = <String>[];
        if (oldDeadline != null && newDeadline != null) {
          parts.add(
            'موعد از ${_toShamsi(oldDeadline)} به ${_toShamsi(newDeadline)} تغییر کرد',
          );
        }
        if (reason != null && reason.trim().isNotEmpty) {
          parts.add('دلیل: $reason');
        }
        return parts.join('\n');
      } catch (_) {
        return notes;
      }
    }

    return notes;
  }
}
