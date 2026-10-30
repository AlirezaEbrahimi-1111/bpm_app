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
import '../../core/widgets/app_switch.dart';
import '../../core/plan/plan_access.dart';
import '../../core/plan/org_permissions.dart';
import '../subscription/plan_gate.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/starred_tasks_preference.dart';
import '../../core/theme/app_radius.dart';
import 'widgets/task_badges.dart';
import 'widgets/persian_date_picker_sheet.dart';
import 'widgets/task_group_management_sheet.dart';
import 'widgets/attachment_picker.dart';
import 'create_task_page.dart';
import '../../core/navigation/app_nav.dart';
import '../shell/main_shell.dart';

class TaskDetailPage extends StatefulWidget {
  final int taskId;
  final int? currentUserId;
  const TaskDetailPage({super.key, required this.taskId, this.currentUserId});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

/// یک آیتمِ عملیاتیِ نوارِ پایین که در شیتِ «سایر عملیات» جا می‌شود —
/// داده‌ی خام (نه ویجتِ آماده) تا هم به‌صورتِ لیست و هم شبکه‌ای قابلِ‌رندر باشد
typedef _MoreAction = ({
  IconData icon,
  String label,
  Color color,
  VoidCallback onTap,
});

/// دکمه‌ی نوارِ اصلی — همان داده‌ی [_MoreAction] به‌علاوه‌ی قفلِ پلنِ اختیاری،
/// تا اگر جا نشد بتواند به منویِ «بیشتر» منتقل شود
typedef _PrimaryAction = ({
  _MoreAction a,
  PlanFeature? gate,
  String? gateLabel,
});

class _TaskDetailPageState extends State<TaskDetailPage> {
  static const _primary = Color(0xFF6C63FF);

  Map<String, dynamic>? _task;
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _error;
  List<dynamic> _checklist = [];
  int _checklistDone = 0;
  int _checklistTotal = 0;
  bool get _checklistIncomplete =>
      _checklistTotal > 0 && _checklistDone < _checklistTotal;

  /// «تکمیل» از نظرِ نقش/وضعیت مجاز است (بدونِ درنظرگرفتنِ چک‌لیست) — همان
  /// completeBtnEligible وب: مسئولِ فعلی و کار در حالِ انجام
  bool get _completeEligible {
    final t = _task;
    if (t == null || _currentUserId == null) return false;
    return t['status'] == 'in_progress' &&
        t['assignee_id']?.toString() == _currentUserId.toString();
  }

  int _checklistPercent = 0;
  List<dynamic> _groups = [];
  List<dynamic> _sections = [];
  bool _canEdit = false;
  bool _hasChanges = false;
  bool _isDeleted = false;
  List<dynamic> _users = [];
  List<dynamic> _attachments = [];
  bool _isUploading = false;
  List<dynamic> _viewers = [];
  // مثلِ وب: سرور (list-viewers.php → can_manage) تعیین می‌کند چه کسی ردیفِ
  // «دسترسی به» را ببیند — سازنده، مدیرِ سازنده، یا ناظرِ کلِ سازمان
  bool _canManageViewers = false;
  // ردیف‌هایِ بازِ بینندگان (جزئیاتِ دسترسی) + مقادیرِ ویرایش‌نشده‌ی سوییچ‌ها
  final Set<String> _openViewerRows = {};
  final Map<String, Map<String, bool>> _viewerDrafts = {};
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
    // ستاره‌یِ همین کار ممکن است تازه در وب زده شده باشد (منتخبِ مشترک)
    StarredTasksPreference.sync();
  }

  // 🔧 حالا فقط پوششی رویِ ApiClient.errorMessage (منطقِ مشترک، چون همین
  // باگ در فایل‌های دیگر هم تکرار شده بود) — برایِ این‌که ۳۰ جایی که
  // همین‌جا صدا می‌زنند دست‌نخورده بمانند
  String _dioErrorMessage(Object e, String fallback) =>
      ApiClient.errorMessage(e, fallback);

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
        _loadSections();
        _loadAttachments();
        // اگر پلن «دسترسی به» را ندارد، سرور با PLAN_RESTRICTED رد می‌کند و
        // پیامِ ارتقایِ پلن بی‌جا روی هر بار بازکردنِ کار می‌پرید — پس صدا نزن
        if (PlanAccess.allows(PlanFeature.taskViewers)) _loadViewers();
        _loadDeadlineRequests();
        _loadOverdueClearRequests();
        _loadRenewalRequest();
        _loadTerminationRequest();
        // با بازشدن کار، همهٔ اعلان‌های مربوط به آن (کار، چک‌لیست، مرحلهٔ روتین)
        // خوانده‌شده شوند — مثل وب (قبلا فقط بعد از تصمیم روی تمدید موعد)
        ApiClient.markTaskNotificationsRead(widget.taskId);
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
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
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
                    AppNav.back();
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
                      AppNav.back();
                      _changeGroup(g['id']);
                    },
                  );
                }),
                // 🔧 این میانبر دقیقاً همان شیتِ مدیریتیِ کاملِ گروه‌هاست
                // (مثلِ منوی کناری) — پس همان دو محورِ نقش+پلن را دارد:
                // اگر نقش اجازه ندهد، میانبر کاملاً مخفی می‌شود؛ اگر پلن
                // قفل کند، کم‌رنگ+قفل‌دار می‌ماند
                if (hasOrgPermission(
                  ApiClient.currentUser?['role']?.toString(),
                  OrgPermission.manageTaskGroups,
                )) ...[
                  Divider(height: 12, color: c.borderSoft),
                  PlanGate(
                    feature: PlanFeature.managementGroups,
                    label: 'مدیریت گروه‌ها',
                    child: ListTile(
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
                        AppNav.back();
                        showTaskGroupManagementSheet(
                          context,
                          onChanged: _loadGroups,
                        );
                      },
                    ),
                  ),
                ],
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
        setState(() {
          _attachments = data['attachments'] ?? [];
          // 🔧 طبق درخواست: اگر پیوستی هست، بخش پیش‌فرض باز است (فقط
          // بارِ اول — بستنِ دستیِ کاربر با بارگذاریِ بعدی دوباره باز نمی‌شود)
          if (!_attachmentsAutoOpened && _attachments.isNotEmpty) {
            _attachmentsOpen = true;
            _attachmentsAutoOpened = true;
          }
        });
      }
    } catch (_) {}
  }

  // 🔧 طبقِ بک‌اند (api/tasks/upload-attachment.php): عکس/سند، صوتی
  // (mp3/m4a/ogg) و حالا ویدیو (mp4/mov) هم پشتیبانی می‌شود
  static const _allowedAttachmentExtensions = [
    'jpg',
    'jpeg',
    'png',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'mp3',
    'm4a',
    'ogg',
    'mp4',
    'mov',
  ];

  // 🔧 طبق درخواست: علاوه‌بر انتخاب از فایل‌ها، گرفتنِ عکسِ مستقیم با
  // دوربین و ضبطِ صدای مستقیم هم به‌عنوانِ پیوست امکان‌پذیر شد — هر سه
  // مسیر به همین یک تابعِ آپلود می‌رسند
  Future<void> _openAttachmentSheet() async {
    try {
      final file = await showAttachmentSourceSheet(
        context,
        allowedExtensions: _allowedAttachmentExtensions,
      );
      if (file != null) await _uploadPlatformFile(file);
    } catch (_) {
      AppSnack.error('خطا', 'خطا در انتخاب فایل');
    }
  }

  // 🔧 طبق درخواست: دکمه‌ی پیوستِ داخلِ دیالوگِ یادداشت هم مستقیماً
  // همین شیتِ سه‌راهی را باز می‌کند
  Future<void> _pickAndUploadFile() => _openAttachmentSheet();

  Future<void> _uploadPlatformFile(
    PlatformFile file, {
    int? checklistItemId,
  }) async {
    if (_isUploading) return;
    final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
    // 🔧 رفعِ باگ: برخی پیکرهای فایل (مخصوصاً وقتی کاربر از «Browse»ی
    // سیستمی به‌جای فیلترِ اپ استفاده می‌کند) فیلترِ allowedExtensions
    // را رعایت نمی‌کنند — پس خودمان هم باید اینجا چک کنیم، نه فقط
    // منتظرِ ردِ سرور بمانیم
    if (!_allowedAttachmentExtensions.contains(ext)) {
      AppSnack.error(
        'فرمت فایل پشتیبانی نمی‌شود',
        'فقط عکس، PDF، Word، Excel، فایل صوتی mp3/m4a/ogg و ویدیوی mp4/mov مجاز است.',
      );
      return;
    }

    try {
      setState(() => _isUploading = true);

      final formData = dio.FormData.fromMap({
        'task_id': widget.taskId,
        if (checklistItemId != null) 'checklist_item_id': checklistItemId,
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
      AppSnack.error('خطا', ApiClient.errorMessage(e, 'خطا در آپلود فایل'));
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
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
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
        setState(() {
          _viewers = data['viewers'] ?? [];
          _canManageViewers =
              data['can_manage'] == true || data['can_manage'] == 1;
          _viewerDrafts.clear();
        });
      }
    } catch (_) {}
  }

  /// 🔧 رفعِ باگِ «درجا اضافه نمی‌شود»: قبلاً بارگذاریِ دوباره‌ی فهرست
  /// منتظر نمی‌ماند و شیت پیش از پاسخِ سرور تازه می‌شد. حالا تا پایانِ
  /// بارگذاری صبر می‌کند و نتیجه را برمی‌گرداند
  Future<bool> _addViewer(int userId, {Map<String, bool>? perms}) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/add-viewers.php',
        data: {
          'task_id': widget.taskId,
          'user_ids': [userId],
          // مثلِ فرمِ افزودنِ وب: سه سوییچِ دسترسی (پیش‌فرض همه روشن)
          if (perms != null) ...{
            'can_view_attachments': perms['att'] ?? true,
            'can_view_history': perms['hist'] ?? true,
            'can_view_checklist': perms['chk'] ?? true,
          },
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        await _loadViewers();
        AppSnack.success('✅ انجام شد', 'دسترسی اضافه شد');
        return true;
      }
      AppSnack.error('خطا', data['message'] ?? 'خطا در افزودن دسترسی');
    } catch (e) {
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
    return false;
  }

  bool _flag(dynamic v) => v == true || v == 1 || v == '1';

  Map<String, bool> _viewerDraft(dynamic v) => _viewerDrafts.putIfAbsent(
    v['id'].toString(),
    () => {
      'att': _flag(v['can_view_attachments']),
      'hist': _flag(v['can_view_history']),
      'chk': _flag(v['can_view_checklist']),
    },
  );

  // ویرایشِ دسترسیِ بیننده‌ی موجود — مثلِ وب همان add-viewers.php با یک نفر
  // (سمتِ سرور ON DUPLICATE KEY UPDATE)
  Future<void> _applyViewerPermission(dynamic v) async {
    final d = _viewerDraft(v);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/add-viewers.php',
        data: {
          'task_id': widget.taskId,
          'user_ids': [v['id']],
          'can_view_attachments': d['att'],
          'can_view_history': d['hist'],
          'can_view_checklist': d['chk'],
        },
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        AppSnack.success('✅ انجام شد', 'تغییرات اعمال شد');
        _loadViewers();
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در اعمال تغییرات');
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

  /// حذفِ موعدِ کار — فقط وقتی واقعاً معنی دارد که سرور هم چک می‌کند:
  /// کارِ مقطعی که سازنده و مسئولِ انجامش یک نفر باشند (خودِ آن شخص)
  void _confirmClearDueDate() {
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'حذف موعد',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: Text(
          'موعد این کار حذف شود؟ این کار دیگر موعدی نخواهد داشت.',
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              AppNav.back();
              _clearDueDate();
            },
            child: Text('حذف موعد', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDueDate() async {
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/clear-due-date.php',
        data: {'task_id': widget.taskId},
      );
      final data = ApiClient.parseResponse(res.data);
      if (data['success'] == true) {
        _hasChanges = true;
        _loadDetail();
        AppSnack.success('✅ انجام شد', data['message'] ?? 'موعد کار حذف شد');
      } else {
        AppSnack.warning('توجه', data['message'] ?? 'خطا در حذف موعد');
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
        ApiClient.markTaskNotificationsRead(widget.taskId);
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
        ApiClient.markTaskNotificationsRead(widget.taskId);
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
        _leaveAfterAction('✅ اتمام یافت', data['message'] ?? 'کار اتمام یافت');
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

  Future<void> _loadSections() async {
    try {
      final res = await ApiClient.dio.get(
        '/api/organization/activity-sections.php',
      );
      if (res.data['success'] == true) {
        setState(() => _sections = res.data['sections'] ?? []);
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
          // 🔧 طبق درخواست: اگر چک‌لیست آیتم دارد، پیش‌فرض باز (فقط بارِ اول)
          if (!_checklistAutoOpened && _checklist.isNotEmpty) {
            _checklistOpen = true;
            _checklistAutoOpened = true;
          }
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
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
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

  Future<void> _editChecklistItem(
    int itemId,
    String title, {
    String? description,
    String? assigneeType,
    dynamic assigneeValue,
  }) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/checklist/update-item.php',
        data: {
          'item_id': itemId,
          'title': title,
          'description': description ?? '',
          // 🔧 طبق درخواست: ارجاعِ آیتمِ چک‌لیست به یک کاربر/بخشِ دیگر —
          // عیناً طبقِ نسخه‌ی وب، فقط وقتی کلید ارسال می‌شود که کاربر
          // واقعاً روی گزینه‌ای در انتخاب‌گر زده باشد (طبق منطقِ
          // has_assignee سمتِ بک‌اند؛ نبودِ کلید یعنی «ارجاع را تغییر نده»)
          if (assigneeType != null) 'assignee_type': assigneeType,
          if (assigneeType != null) 'assignee_value': assigneeValue,
        },
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              AppNav.back();
              _addChecklistItem(title);
            },
            child: Text('افزودن', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  /// افزودن/ویرایشِ توضیحِ آیتمِ چک‌لیست — مثلِ startEditDesc وب؛ عنوان و
  /// ارجاعِ فعلیِ آیتم دست نمی‌خورد (کلیدِ assignee ارسال نمی‌شود)
  void _showChecklistDescDialog(Map<String, dynamic> item) {
    final controller = TextEditingController(
      text: item['description']?.toString() ?? '',
    );
    final c = AppColors.of(context);
    Get.dialog(
      AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Text(
          'توضیحات',
          style: TextStyle(fontSize: 16, color: c.textStrong),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          style: TextStyle(color: c.textStrong),
          decoration: InputDecoration(
            hintText: 'توضیحات...',
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              AppNav.back();
              _editChecklistItem(
                item['id'],
                (item['title'] ?? '').toString(),
                description: controller.text.trim(),
              );
            },
            child: Text('ثبت', style: TextStyle(color: c.primary)),
          ),
        ],
      ),
    );
  }

  void _showEditChecklistItemDialog(Map<String, dynamic> item) {
    final controller = TextEditingController(
      text: item['title']?.toString() ?? '',
    );
    // 🔧 طبق درخواست: امکانِ افزودن/ویرایشِ توضیحِ آیتم هم اضافه شد
    final descController = TextEditingController(
      text: item['description']?.toString() ?? '',
    );
    final c = AppColors.of(context);

    // 🔧 طبق درخواست: امکانِ ارجاعِ آیتمِ چک‌لیست به یک نفر/یک بخشِ دیگر
    // — عیناً طبقِ نسخه‌ی وب. این دیالوگ فقط برای آیتم‌هایِ هنوز
    // ارجاع‌نشده صدا زده می‌شود (گیت `!isAssigned` در `_checklistItem`)
    // چون بک‌اند ویرایشِ آیتمِ ارجاع‌شده را با ۴۰۹ رد می‌کند — پس همیشه
    // از حالتِ «بدون انتخاب» شروع می‌شود
    String? assigneeType;
    dynamic assigneeValue;
    String? assigneeLabel;

    Get.dialog(
      StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'ویرایش آیتم چک‌لیست',
              style: TextStyle(fontSize: 16, color: c.textStrong),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: c.textStrong),
                    decoration: InputDecoration(
                      hintText: 'عنوان آیتم را وارد کنید',
                      hintStyle: TextStyle(color: c.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 3,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: c.textStrong, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'توضیحات (اختیاری)...',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: c.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () =>
                        _showChecklistAssigneeSheet(c, (type, value, label) {
                          setDialogState(() {
                            assigneeType = type;
                            assigneeValue = value;
                            assigneeLabel = label;
                          });
                        }),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            assigneeType == 'section'
                                ? Icons.groups_outlined
                                : Icons.person_outline_rounded,
                            size: 18,
                            color: assigneeLabel != null
                                ? c.primary
                                : c.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              assigneeLabel ?? 'ارجاع به (اختیاری)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                color: assigneeLabel != null
                                    ? c.primary
                                    : c.textMuted,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: c.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => AppNav.back(),
                child: Text('انصراف', style: TextStyle(color: c.textMuted)),
              ),
              TextButton(
                onPressed: () {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  AppNav.back();
                  _editChecklistItem(
                    item['id'],
                    title,
                    description: descController.text.trim(),
                    assigneeType: assigneeType,
                    assigneeValue: assigneeValue,
                  );
                },
                child: Text('ذخیره', style: TextStyle(color: c.primary)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 🔧 انتخاب‌گرِ ارجاعِ آیتمِ چک‌لیست — عیناً طبقِ نسخه‌ی وب، فقط
  // «کاربر» و «بخش» (بدون گزینه‌هایِ «خودم»/«همه کاربران»/«همه بخش‌ها»
  // که مخصوصِ ارجاعِ کل کار است، نه یک آیتمِ تکی)
  void _showChecklistAssigneeSheet(
    AppColors c,
    void Function(String type, dynamic value, String label) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChecklistAssigneeSheet(
        users: _users,
        sections: _sections,
        onSelected: onSelected,
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              AppNav.back();
              _deleteChecklistItem(item['id']);
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  /// تاریخ و ساعتِ یک رویدادِ تاریخچه، در دو خطِ جدا — عیناً مطابقِ وب
  /// («تاریخ» روی یک خط، «ساعت» زیرش)
  (String, String) _historyDateParts(String? gregorian) {
    if (gregorian == null || gregorian.isEmpty) return ('', '');
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
      return (
        toPersianDigits('${j.day} ${mo[j.month - 1]} ${j.year}'),
        toPersianDigits('$h:$m'),
      );
    } catch (_) {
      return (gregorian, '');
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

  /// تاریخ و ساعت — مثلِ formatDateTime نسخه‌ی وب: «۱۹ مهر ۱۴۰۵ - ۱۰:۲۳»
  String _toShamsiDateTime(String? gregorian) {
    final date = _toShamsi(gregorian);
    if (gregorian == null || gregorian.length < 16) return date;
    final d = DateTime.tryParse(gregorian.replaceFirst(' ', 'T'));
    if (d == null) return date;
    String p(int n) => n.toString().padLeft(2, '0');
    return '$date - ${toPersianDigits('${p(d.hour)}:${p(d.minute)}')}';
  }

  /// 🔧 طبق درخواست: ردیفِ «مهلت انجام» — همیشه نمایش داده می‌شود و متن/رنگش
  /// عیناً TF.remainingBadge وب (assets/js/task-filters.js) است:
  /// تکمیل / n روز / n روز دیگر / امروز / n روز کاری تاخیر، و برایِ کارِ روتین
  /// ساعتی (n ساعت مانده / اکنون / ... تاخیر). عددها از سرور (enrichTaskDates)
  List<Widget> _remainingOrDelayRow(AppColors c, Map<String, dynamic> t) {
    int? n(dynamic v) => v == null ? null : int.tryParse(v.toString());
    const overdue = (Color(0xFFFFE8E8), Color(0xFFD61F1F));
    const today = (Color(0xFFFFF3D6), Color(0xFFC2740A));
    const soon = (Color(0xFFFFF0CC), Color(0xFFA5620A));
    const normal = (Color(0x1F1B7B39), Color(0xFF1B7B39));
    (Color, Color)? style;
    String text = '-';
    var icon = Icons.schedule_rounded;

    final status = t['status'];
    final isWf = t['is_workflow_task'] == 1 || t['is_workflow_task'] == true;
    if (status == 'completed' || status == 'approved') {
      style = normal;
      text = 'تکمیل';
    } else {
      final due = taskEffectiveDue(t);
      if (due != null && isWf) {
        final hd = n(t['hours_delayed']) ?? 0;
        final hr = n(t['hours_remaining']);
        if (hd > 0) {
          style = overdue;
          text = _formatHourDelay(hd, 'تاخیر');
          icon = Icons.history_rounded;
        } else if (hr == 0) {
          style = today;
          text = 'اکنون';
        } else if (hr != null) {
          style = hr <= 24 ? soon : normal;
          text = '${toPersianDigits(hr.toString())} ساعت مانده';
        }
      } else if (due != null) {
        final d = DateTime.tryParse(due);
        if (d != null) {
          final now = DateTime.now();
          final diff = DateTime(
            d.year,
            d.month,
            d.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays;
          if (diff < 0) {
            final wd = (n(t['working_days_delayed']) ?? 0).clamp(1, 1 << 30);
            style = overdue;
            text = '${toPersianDigits(wd.toString())} روز کاری تاخیر';
            icon = Icons.history_rounded;
          } else if (diff == 0) {
            style = today;
            text = 'امروز';
          } else if (diff <= 3) {
            style = soon;
            text = '${toPersianDigits(diff.toString())} روز دیگر';
          } else {
            style = normal;
            text = '${toPersianDigits(diff.toString())} روز';
          }
        }
      }
    }

    return [
      const Divider(height: 26),
      Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timelapse_rounded, size: 14, color: c.primary),
          ),
          const SizedBox(width: 10),
          Text(
            'مهلت انجام',
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
          const Spacer(),
          if (style == null)
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textStrong,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: style.$1,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: style.$2),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: style.$2,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  /// معادلِ formatHourDelay وب: «۵ ساعت» یا «۲ روز و ۳ ساعت»
  String _formatHourDelay(int hours, String suffix) {
    if (hours < 24) return toPersianDigits('$hours ساعت $suffix');
    final days = hours ~/ 24;
    final rem = hours % 24;
    var text = '$days روز';
    if (rem > 0) text += ' و $rem ساعت';
    return toPersianDigits('$text $suffix');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 🔧 طبق درخواست: نوارِ ناوبریِ پوسته‌ی اصلی اینجا هم (زیرِ نوارِ
    // عملیاتِ خودِ این صفحه، نه به‌جایِ آن) نمایش داده می‌شود
    final actionBar = (_isLoading || _error != null || _task == null)
        ? null
        : _buildActionBar();
    // 🔧 طبق درخواست: دکمه‌ی جست‌وجویِ سراسری (AppShellOverlays) در این صفحه نیست
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) AppNav.back(result: _hasChanges);
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
            onPressed: () => AppNav.back(result: _hasChanges),
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
                  // طبق درخواست این صفحه نوارِ ناوبریِ پایین ندارد، پس
                  // فاصله‌ی امن (نوارِ دکمه‌هایِ گوشی) را خودِ این نوار می‌گیرد
                  if (actionBar != null) SafeArea(top: false, child: actionBar),
                ],
              ),
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

    // 🔧 طبق درخواست: نوارِ اصلی حداکثر همین ۴ تا را نشان می‌دهد — درجِ
    // توضیح، شروع/تکمیل/تأیید، ارجاع، حذفِ کار. هر عملیاتِ دیگری («رد»،
    // یادآوری، تمدید موعد، رفعِ تأخیر، تمدید/درخواستِ تمدیدِ دوره،
    // درخواستِ اتمام، اتمامِ دوره، بازتعریف) داخلِ لیستِ «بیشتر» می‌رود و
    // فقط با یک دکمه‌ی اضافه (که خودش جزوِ این ۴ تا نیست) قابلِ‌دسترسیه
    final List<_PrimaryAction> primary = [];
    final List<_MoreAction> more = [];

    // ── حالت منتظر تأیید: رد (بیشتر) / تأیید (اصلی) ──
    if (isPending && (isCreator || isAssignee)) {
      primary.add((
        a: (
          icon: Icons.check_circle_rounded,
          label: 'تأیید',
          color: const Color(0xFF1B7B39),
          // 🔧 بسط دیالوگِ تأییدِ ساده — اگر تعریف‌کننده یا مسئولِ فعلی
          // گزینه‌ی بیشتری داشته باشند، یک شیتِ کوچک انتخاب باز می‌شود؛
          // وگرنه مستقیم همان تأییدِ ساده‌ی قبلی انجام می‌شود
          onTap: () => _showApproveOptionsSheet(
            isCreator: isCreator,
            isAssignee: isAssignee,
          ),
        ),
        gate: null,
        gateLabel: null,
      ));
      // 🔧 طبق درخواست: «رد» هم جزوِ دکمه‌هایِ اصلی (کنارِ «تأیید»)
      primary.add((
        a: (
          icon: Icons.cancel_rounded,
          label: 'رد',
          color: const Color(0xFFEF4444),
          onTap: _showRejectDialog,
        ),
        gate: null,
        gateLabel: null,
      ));
    } else if (isAssignee) {
      // ── شروع / تکمیل (هر دو اصلی‌اند، فقط یکی هم‌زمان) ──
      if (status == 'not_started' ||
          status == 'delegated' ||
          status == 'rejected') {
        primary.add((
          a: (
            icon: Icons.play_arrow_rounded,
            label: 'شروع',
            color: const Color(0xFF8E57FE),
            onTap: () => _updateStatus('in_progress'),
          ),
          gate: null,
          gateLabel: null,
        ));
      } else if (status == 'in_progress') {
        // 🔧 طبق درخواست (عیناً applyChecklistGate وب): تا وقتی همه‌ی آیتم‌هایِ
        // چک‌لیست تیک نخورده‌اند، «تکمیل» نشان داده نمی‌شود
        if (!_checklistIncomplete) {
          primary.add((
            a: (
              icon: Icons.check_circle_outline_rounded,
              label: 'تکمیل',
              color: const Color(0xFF1B7B39),
              onTap: _showCompleteDialog,
            ),
            gate: null,
            gateLabel: null,
          ));
        }
        // ── درجِ توضیح — دقیقاً همان شرطِ نمایشِ «تکمیل»، یعنی همیشه
        // کنارِ هم هستند (مثلِ وب: addDiscBtn همیشه با completeBtn) ──
        primary.add((
          a: (
            icon: Icons.chat_outlined,
            label: 'درج توضیح',
            color: const Color(0xFF8E57FE),
            onTap: _showAddNoteDialog,
          ),
          gate: null,
          gateLabel: null,
        ));
      }

      // ── ارجاع (اصلی) ──
      final canDelegate =
          status != 'completed' &&
          status != 'approved' &&
          status != 'rejected' &&
          !isPending;
      if (canDelegate) {
        primary.add((
          a: (
            icon: Icons.arrow_circle_right_outlined,
            label: 'ارجاع',
            color: const Color(0xFFF59E0B),
            onTap: _showDelegateSheet,
          ),
          gate: PlanFeature.delegate,
          gateLabel: 'ارجاع کار',
        ));
      }
    }

    // ── یادآوری (بیشتر) ──
    final canRemind =
        isCreator &&
        !isAssignee &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected';
    if (canRemind) {
      more.add((
        icon: Icons.notifications_none_rounded,
        label: 'یادآوری',
        color: const Color(0xFFF59E0B),
        onTap: _showSendReminderDialog,
      ));
    }

    // ── تمدید موعد (بیشتر) ──
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
      more.add((
        icon: Icons.hourglass_bottom_rounded,
        label: 'تمدید موعد',
        color: const Color(0xFF1B7B39),
        onTap: _showRequestDeadlineDialog,
      ));
    }

    // ── رفع تأخیرِ دوره‌ای (بیشتر) ──
    final canRequestOverdueClear =
        (isAssignee || isCreator) &&
        t['task_type'] == 'continuous' &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected' &&
        t['has_pending_overdue_request'] != 1 &&
        t['has_pending_overdue_request'] != true;
    if (canRequestOverdueClear) {
      more.add((
        icon: Icons.cleaning_services_outlined,
        label: 'رفع تأخیر',
        color: const Color(0xFF8E57FE),
        onTap: _showRequestOverdueClearDialog,
      ));
    }

    // ── تمدید دوره (بیشتر) ──
    final isReadyForRenewal =
        t['task_type'] == 'continuous' &&
        (t['end_date'] ?? '').toString().isNotEmpty &&
        (t['end_date'].toString().compareTo(_todayIso()) <= 0) &&
        t['is_pending_approval'] != 1 &&
        t['is_pending_approval'] != true &&
        t['has_pending_renewal_request'] != 1 &&
        t['has_pending_renewal_request'] != true;
    if (isReadyForRenewal && isCreator) {
      more.add((
        icon: Icons.autorenew_rounded,
        label: 'تمدید دوره',
        color: const Color(0xFF06B6D4),
        onTap: () => _showRenewalDialog(directApply: true),
      ));
    } else if (isReadyForRenewal && isAssignee) {
      more.add((
        icon: Icons.autorenew_rounded,
        label: 'درخواست تمدید',
        color: const Color(0xFF06B6D4),
        onTap: () => _showRenewalDialog(directApply: false),
      ));
    }

    // ── اتمام کار دوره‌ای (بیشتر) ──
    final canRequestTermination =
        isAssignee &&
        !isCreator &&
        t['task_type'] == 'continuous' &&
        (status == 'not_started' || status == 'in_progress');
    if (canRequestTermination) {
      more.add((
        icon: Icons.flag_rounded,
        label: 'درخواست اتمام',
        color: const Color(0xFFF59E0B),
        onTap: _showRequestTerminationDialog,
      ));
    }
    // 🔧 رفعِ باگ: «periodic» یعنی کارِ «مقطعی» (نه دوره‌ای) — قبلاً این
    // گزینه برایِ کارهایِ مقطعی هم نشان داده می‌شد. مثلِ نسخه‌ی وب فقط
    // کارهایِ دوره‌ای (continuous)، و نه برایِ کارِ ردشده
    final canTerminateNow =
        isCreator &&
        t['task_type'] == 'continuous' &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected';
    if (canTerminateNow) {
      more.add((
        icon: Icons.stop_circle_outlined,
        label: 'اتمام دوره',
        color: const Color(0xFFEF4444),
        onTap: _confirmTerminatePeriodNow,
      ));
    }

    // ── بازتعریف کار (بیشتر) ──
    if (_canEdit || isAssignee) {
      more.add((
        icon: Icons.autorenew_rounded,
        label: 'بازتعریف',
        color: const Color(0xFF8E57FE),
        onTap: _openRedefine,
      ));
    }

    // ── حذفِ کار (اصلی) ──
    if (_canEdit) {
      primary.add((
        a: (
          icon: Icons.delete_outline_rounded,
          label: 'حذف',
          color: const Color(0xFFEF4444),
          onTap: _confirmDelete,
        ),
        gate: null,
        gateLabel: null,
      ));
    }

    // اگر هیچ دکمه‌ای نبود، نوار را نشان نده
    if (primary.isEmpty && more.isEmpty) return null;

    return SafeArea(
      top: false,
      // 🔧 طبق درخواست: فاصله‌ی بیشتر از پایین — قبلاً فقط ۸ بود و
      // خیلی به لبه/دکمه‌های ناوبریِ گوشی چسبیده بود
      minimum: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: _floatingBar(
          // 🔧 طبق درخواست: نوار تحتِ هیچ شرایطی دوخطی نمی‌شود — هر چند
          // دکمه که در یک ردیف جا شود نشان داده می‌شود؛ اگر جا نشد، دکمه‌هایِ
          // آخر مخفی و به ابتدایِ منویِ «بیشتر» منتقل می‌شوند
          child: Builder(
            builder: (context) {
              // 🔧 طبق درخواست: همیشه حداکثر ۴ دکمه‌ی اصلی + دکمه‌ی پنجمِ
              // «بیشتر». اگر دکمه‌هایِ اصلی کمتر از ۴ تا باشند، از اولِ
              // فهرستِ «بیشتر» پُر می‌شوند؛ هر چه بیشتر از ۴ بود، به «بیشتر» می‌رود
              const maxPrimary = 4;
              final shown = List<_PrimaryAction>.of(primary);
              final rest = List<_MoreAction>.of(more);
              while (shown.length < maxPrimary && rest.isNotEmpty) {
                shown.add((a: rest.removeAt(0), gate: null, gateLabel: null));
              }
              final overflow = <_MoreAction>[
                for (final p in shown.skip(maxPrimary)) _gatedAction(p),
              ];
              final visible = shown.take(maxPrimary).toList();
              final menuItems = [...overflow, ...rest];
              final children = <Widget>[
                for (final p in visible) _primaryButton(p),
                if (menuItems.isNotEmpty) _moreButton(menuItems),
              ];
              // پنج دکمه‌ی ۴۴ پیکسلی با فاصله‌ی مساوی همیشه در یک ردیف جا می‌شوند
              return Row(
                mainAxisAlignment: children.length >= 4
                    ? MainAxisAlignment.spaceEvenly
                    : MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0 && children.length < 4) const SizedBox(width: 18),
                    children[i],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// دکمه‌ی گردِ نوارِ اصلی؛ اگر قفلِ پلن داشته باشد داخلِ PlanGate
  Widget _primaryButton(_PrimaryAction p) {
    final btn = _circleAction(
      icon: p.a.icon,
      label: p.a.label,
      color: p.a.color,
      onTap: p.a.onTap,
    );
    if (p.gate == null) return btn;
    return PlanGate(feature: p.gate!, label: p.gateLabel, child: btn);
  }

  /// همان عملیات برایِ منویِ «بیشتر» — قفلِ پلن موقعِ لمس بررسی می‌شود
  _MoreAction _gatedAction(_PrimaryAction p) {
    if (p.gate == null) return p.a;
    return (
      icon: p.a.icon,
      label: p.a.label,
      color: p.a.color,
      onTap: () {
        if (!checkPlanAccess(p.gate!, label: p.gateLabel)) return;
        p.a.onTap();
      },
    );
  }

  Widget _moreButton(List<_MoreAction> items) {
    return Builder(
      builder: (btnCtx) => _circleAction(
        icon: Icons.more_horiz_rounded,
        label: 'بیشتر',
        color: const Color(0xFF64748B),
        onTap: () => _showMoreActionsMenu(btnCtx, items),
      ),
    );
  }

  /// 🔧 طبق درخواست (طبقِ عکسِ ارسالی): «بیشتر» یک «اسپید دایل» باز می‌کند —
  /// صفحه کم‌رنگ می‌شود و هر عملیات یک دکمه‌ی گردِ رنگی، درست بالایِ خودِ
  /// دکمه‌ی «بیشتر» روی هم چیده می‌شود، با برچسب کنارش. نزدیک‌ترین دکمه به
  /// «بیشتر» اولین گزینه است؛ لمسِ بیرون یا ضربدر = بستن
  Future<void> _showMoreActionsMenu(
    BuildContext btnCtx,
    List<_MoreAction> actions,
  ) async {
    final c = AppColors.of(context);
    final btnBox = btnCtx.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(btnCtx).context.findRenderObject() as RenderBox?;
    if (btnBox == null || overlay == null) return;
    final topLeft = btnBox.localToGlobal(Offset.zero, ancestor: overlay);
    final screen = overlay.size;
    // مرکزِ دایره‌ی خودِ دکمه‌ی «بیشتر» (دایره ۴۲ پیکسل، بالایِ ویجت)
    final centerX = topLeft.dx + btnBox.size.width / 2;
    final circleCenterY = topLeft.dy + 21;
    // برچسب‌ها سمتی می‌آیند که جایِ بیشتری دارد
    final labelsOnRight = centerX < screen.width / 2;
    const fab = 48.0;

    final selected = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'بستن',
      barrierColor: c.bgPage.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) {
        Widget item(int i) {
          final a = actions[i];
          final circle = Material(
            color: a.color,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(ctx).pop(i),
              child: SizedBox(
                width: fab,
                height: fab,
                child: Icon(a.icon, color: Colors.white, size: 22),
              ),
            ),
          );
          final label = GestureDetector(
            onTap: () => Navigator.of(ctx).pop(i),
            child: Text(
              a.label,
              style: TextStyle(
                fontFamily: 'Vazir',
                fontSize: 14,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
                color: c.textStrong,
              ),
            ),
          );
          // ورودِ پله‌پله: هر دکمه کمی دیرتر از دکمه‌ی پایینی‌اش
          final t = CurvedAnimation(
            parent: anim,
            curve: Interval(
              (i * 0.08).clamp(0.0, 0.6),
              1,
              curve: Curves.easeOutBack,
            ),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ScaleTransition(
              scale: t,
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: labelsOnRight
                    ? [circle, const SizedBox(width: 14), label]
                    : [label, const SizedBox(width: 14), circle],
              ),
            ),
          );
        }

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: labelsOnRight
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            // اولین گزینه نزدیک‌ترین به «بیشتر» (پایین‌ترین)
            for (var i = actions.length - 1; i >= 0; i--) item(i),
          ],
        );

        // 🔧 Material = تمِ متن (بدونِ آن، متن زیرخطِ زردِ پیش‌فرض می‌گرفت)؛
        // جهتِ LTR برایِ ستون تا همه‌ی دایره‌ها دقیقاً در یک راستا (بالایِ
        // «بیشتر») باشند و برچسب‌ها از کنارِ آن‌ها هم‌تراز شروع شوند
        return Material(
          type: MaterialType.transparency,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned(
                  left: labelsOnRight ? centerX - fab / 2 : null,
                  right: labelsOnRight
                      ? null
                      : screen.width - centerX - fab / 2,
                  top: MediaQuery.of(ctx).padding.top + 8,
                  bottom: screen.height - circleCenterY + 21 + 10,
                  child: Align(
                    alignment: labelsOnRight
                        ? Alignment.bottomLeft
                        : Alignment.bottomRight,
                    child: SingleChildScrollView(reverse: true, child: column),
                  ),
                ),
                // جایِ دکمه‌ی «بیشتر»: ضربدرِ بستن
                Positioned(
                  left: centerX - 21,
                  top: circleCenterY - 21,
                  child: FadeTransition(
                    opacity: anim,
                    child: Material(
                      color: const Color(0xFF64748B),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
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
    );
    if (selected != null && mounted) actions[selected].onTap();
  }

  /// «درج توضیح» — دقیقاً معادلِ addDiscBtn در وب: یادداشتِ تکمیلی روی
  /// همان وضعیتِ فعلی ثبت می‌شود (بدونِ تغییرِ وضعیت)، با امکانِ پیوستِ
  /// فایل. برخلافِ وب، متنِ یادداشت به نامِ کاربر پیشوند نمی‌خورد، چون
  /// تاریخچه‌ی اپ از قبل «توسط X» را جداگانه نشان می‌دهد
  void _showAddNoteDialog() {
    final t = _task!;
    final status = t['status'] as String? ?? '';
    final notesController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                        color: const Color(0xFF0E7490).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF0E7490),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'درج توضیح',
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
                  'توضیحات تکمیلی',
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: TextStyle(color: c.textStrong),
                  decoration: InputDecoration(
                    hintText: 'توضیحات خود را وارد کنید...',
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
                const SizedBox(height: 10),
                // 🔧 پیوستِ فایل (اختیاری) — از همان آپلودرِ موجودِ کار
                // استفاده می‌شود (مستقل از ذخیره‌ی خودِ یادداشت)
                TextButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () async {
                          await _pickAndUploadFile();
                          setDialogState(() {});
                        },
                  icon: Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: c.primary,
                  ),
                  label: Text(
                    _isUploading ? 'در حال آپلود...' : 'پیوست فایل (اختیاری)',
                    style: TextStyle(color: c.primary, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => AppNav.back(),
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
                            AppSnack.error('خطا', 'لطفا توضیحات را وارد کنید');
                            return;
                          }
                          AppNav.back();
                          _updateStatus(status, notes: notes);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E7490),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        child: const Text('درج توضیح'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
  // 🔧 طبق درخواست: برچسب دوباره زیرِ دکمه نمایش داده می‌شود (نه فقط
  // Tooltip) — با عرضِ محدود تا برچسب‌های بلند، دکمه را کش ندهند
  Widget _circleAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final c = AppColors.of(context);
    return GestureDetector(
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
          const SizedBox(height: 4),
          SizedBox(
            width: 44,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: c.textMuted, height: 1.2),
            ),
          ),
        ],
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
    final priorityLbl = TaskLabels.priorityLabel(priority);
    final isContinuous = t['task_type'] == 'continuous';
    final isAssignee =
        _currentUserId != null &&
        t['assignee_id']?.toString() == _currentUserId.toString();
    final isCreator =
        _currentUserId != null &&
        t['creator_id']?.toString() == _currentUserId.toString();
    final isPending =
        status == 'pending_approval' &&
        (t['is_pending_approval'] == 1 || t['is_pending_approval'] == true);
    final c = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── هدرِ بنفشِ کار ──
          // 🔧 طبق درخواست (مثلِ نسخه‌ی وب — .taskDetail-header): نوارِ بنفشِ
          // یکدست (#8e57fe) که عنوان، توضیحات و بج‌هایِ زیرش رویِ آن است
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: BoxDecoration(
              color: _headerPurple,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ستاره‌ی «منتخب» قبل از عنوان (مثلِ وب: سفید، روشن = زرد)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: StarredTasksPreference.idsNotifier,
                      builder: (context, starred, _) {
                        final isStarred = starred.contains(
                          widget.taskId.toString(),
                        );
                        return GestureDetector(
                          onTap: () =>
                              StarredTasksPreference.toggle(widget.taskId),
                          child: Icon(
                            isStarred
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isStarred
                                ? const Color(0xFFF5B94D)
                                : Colors.white,
                            size: 24,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // 🔧 طبق درخواست: توضیحات زیرِ عنوان نمایش داده نمی‌شود
                const SizedBox(height: 14),
                // بج‌ها به ترتیبِ وب: نوع، اولویت، وضعیت
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _headerBadge(
                      isContinuous ? 'دوره‌ای' : 'مقطعی',
                      bg: Colors.white,
                      fg: const Color(0xFF374151),
                      border: const Color(0xFFD1D5DB),
                    ),
                    _headerBadge(
                      priorityLbl,
                      bg: (_webPriorityColors[priority] ?? _webBadgeDefault).$1,
                      fg: (_webPriorityColors[priority] ?? _webBadgeDefault).$2,
                    ),
                    // حذف نرم وضعیت کار را عوض نمی‌کند؛ بدون این شرط کار حذف‌شده «در حال انجام» دیده می‌شد
                    if (_isDeleted)
                      _headerBadge(
                        'حذف شده',
                        bg: const Color(0xFFB91C1C),
                        fg: Colors.white,
                        border: const Color(0xFF991B1B),
                      )
                    else
                      (status == 'completed' || status == 'approved')
                          ? _headerBadge(
                              statusLbl,
                              bg: const Color(0xFF15803D),
                              fg: Colors.white,
                              border: const Color(0xFF166534),
                            )
                          : _headerBadge(
                              statusLbl,
                              bg: (_webStatusColors[status] ?? _webBadgeDefault)
                                  .$1,
                              fg: (_webStatusColors[status] ?? _webBadgeDefault)
                                  .$2,
                            ),
                  ],
                ),
              ],
            ),
          ),
          // 🔧 طبق درخواست: کارتِ «یادداشت ارجاع» زیرِ هدر حذف شد
          const SizedBox(height: 12),

          // ── درخواست‌های باز (تمدید موعد / رفع تأخیرِ دوره‌ای) ──
          // 🔧 طبق درخواست: زیرِ هدرِ عنوان و بالایِ «اطلاعات کار»
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
              title: 'درخواست رفع تأخیر دوره‌ای',
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
          // ── کارت اطلاعات ──
          // 🔧 طبق درخواست: شماره تسک، ایجادکننده، مسئول انجام، گروه،
          // تاریخ ایجاد، موعد انجام (با آیکن‌های تمدید/حذف موعد جلویش)
          _card(
            child: Column(
              children: [
                // 🔧 طبق درخواست (مثلِ وب — .info-section h5): عنوانِ «اطلاعات
                // کار» با آیکن، هر دو بنفشِ #8e57fe و پررنگ
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: _headerPurple,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'اطلاعات کار',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _headerPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _infoRow(
                  Icons.tag_rounded,
                  'شماره',
                  toPersianDigits(t['id']?.toString() ?? '—'),
                ),
                const Divider(height: 26),
                PlanGate(
                  feature: PlanFeature.taskCreatorInfo,
                  label: 'نمایش سازنده کار',
                  child: _infoRow(
                    Icons.person_outline,
                    'ایجاد کننده',
                    t['creator_name'] ?? '—',
                  ),
                ),
                const Divider(height: 26),
                _infoRow(
                  Icons.assignment_ind_outlined,
                  'مسئول انجام',
                  t['assignee_name'] ?? '—',
                ),
                const Divider(height: 26),
                _buildGroupRow(t),
                // 🔧 طبق درخواست (مثلِ وب): «دسترسی به» درست بعد از «گروه»
                // سازنده‌ی کار همیشه ردیف را می‌بیند (اگر پلن نداشته باشد،
                // PlanGate آن را قفل‌دار نشان می‌دهد)؛ بقیه طبقِ can_manage سرور
                if (_canManageViewers || _canEdit) ...[
                  const Divider(height: 26),
                  PlanGate(
                    feature: PlanFeature.taskViewers,
                    label: 'دسترسی به',
                    child: _viewersRow(c),
                  ),
                ],
                const Divider(height: 26),
                _infoRow(
                  Icons.event_note_outlined,
                  'تاریخ ایجاد',
                  // 🔧 طبق درخواست (مثلِ وب — formatDateTime): تاریخ + ساعت
                  _toShamsiDateTime(t['created_at']),
                ),
                if (isContinuous) ...[
                  const Divider(height: 26),
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
                    TaskLabels.periodLabelOf(t),
                  ),
                ] else ...[
                  const Divider(height: 26),
                  _dueDateRow(
                    c,
                    t,
                    status: status,
                    isCreator: isCreator,
                    isAssignee: isAssignee,
                    isPending: isPending,
                  ),
                  // 🔧 طبق درخواست (مثلِ وب): «مهلت انجام» درست بعد از موعد انجام
                  ..._remainingOrDelayRow(c, t),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 🔧 طبق درخواست: چک‌لیست/بینندگان/پیوست‌ها دیگر کارت‌های جدا
          // ندارند — همه در یک کارتِ مشترک، با خطِ افقی بینِ بخش‌ها
          _checklistViewersAttachmentsCard(c),
          const SizedBox(height: 12),
          // ── تاریخچه ──
          // 🔧 طبق درخواست: دقیقاً مطابقِ وب — عنوان همیشه نشان داده
          // می‌شود (حتی وقتی تاریخچه خالی است، با متنِ «بدون تاریخچه»؛
          // قبلاً کلِ کارت وقتی خالی بود مخفی می‌شد)
          Builder(
            builder: (context) {
              final items = _visibleHistory;
              // 🔧 طبق درخواست: متن‌هایِ تاریخچه قابلِ‌انتخاب و کپی (لمسِ طولانی)
              return _card(
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // 🔧 طبق درخواست: آیکن پشتِ (سمتِ راستِ) متن
                          Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: c.textMuted,
                          ),
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
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Text(
                          'بدون تاریخچه',
                          style: TextStyle(fontSize: 13, color: c.textMuted),
                        )
                      else
                        for (int i = 0; i < items.length; i++)
                          _historyItem(items[i], isLast: i == items.length - 1),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  int? _currentUserId;
  bool _isUpdating = false;

  // 🔧 طبق درخواست: چک‌لیست/پیوست‌ها آکاردئونی؛ خالی = بسته، اگر محتوا
  // داشته باشند پیش‌فرض باز (یک بار، بعد از اولین بارگذاری)
  bool _checklistOpen = false;
  bool _attachmentsOpen = false;
  bool _checklistAutoOpened = false;
  bool _attachmentsAutoOpened = false;

  // 🔧 طبق درخواست: چک‌لیست/بینندگان/پیوست‌ها دیگر هرکدام کارتِ جدایِ
  // خودشان را ندارند — همه در یک کارتِ مشترک، با خطِ افقی (Divider)
  // بینِ هر بخش. چون بینندگان/چک‌لیست شرطی نمایش داده می‌شوند، لیستِ
  // بخش‌ها اول جمع‌آوری و بعد بینشان خط گذاشته می‌شود (نه بعدِ آخری)
  Widget _checklistViewersAttachmentsCard(AppColors c) {
    final sections = <Widget>[];

    // 🔧 طبق درخواست (مثلِ وب): اول «پیوست‌ها»، بعد «چک‌لیست»
    // ── پیوست‌ها ──
    sections.add(
      Column(
        children: [
          _sectionHeader(
            c,
            title: 'پیوست‌ها',
            open: _attachmentsOpen,
            onToggle: () =>
                setState(() => _attachmentsOpen = !_attachmentsOpen),
            trailing: _addPillButton(
              c,
              label: 'افزودن',
              onTap: _isUploading ? null : _openAttachmentSheet,
              loading: _isUploading,
            ),
          ),
          _accordionBody(
            _attachmentsOpen,
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: _attachments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'فایلی پیوست نشده',
                          style: TextStyle(color: c.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      children: _attachments
                          .map((a) => _attachmentItem(a))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );

    // ── چک‌لیست ──
    // 🔧 قبلاً فقط وقتی آیتمی از قبل بود نمایش داده می‌شد؛ حالا اگر
    // تعریف‌کننده باشیم، حتی با چک‌لیست خالی هم بخش نشان داده می‌شود
    // تا بشود اولین آیتم را اضافه کرد
    if (_checklistTotal > 0 || _canEdit) {
      sections.add(
        Column(
          children: [
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
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
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
                      // مثلِ وب (checklistCompleteGateNote): چرا «تکمیل» نیست
                      if (_completeEligible && _checklistIncomplete)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                            border: Border.all(color: const Color(0xFFFCD34D)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_rounded,
                                size: 16,
                                color: Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'برای نمایش دکمه‌ی «تکمیل»، ابتدا ${toPersianDigits((_checklistTotal - _checklistDone).toString())} آیتم باقی‌مانده‌ی چک‌لیست را تیک بزنید.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: c.textStrong,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
          ],
        ),
      );
    }

    final withDividers = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) {
        withDividers.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1, color: c.borderSoft),
          ),
        );
      }
      withDividers.add(sections[i]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSoft),
      ),
      child: Column(children: withDividers),
    );
  }

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
                // 🔧 طبق درخواست: هم‌اندازه‌ی برچسب‌هایِ «سازنده/مسئول/موعد انجام»
                fontSize: 13,
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
    if (!checkPlanAccess(PlanFeature.delegate, label: 'ارجاع کار')) return;
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

    // 🔧 طبق درخواست: عیناً طبقِ نسخه‌ی وب — اگر این کار تا الان هیچ
    // موعدی نداشته، چون دارد به کسِ دیگری ارجاع می‌شود، تعیینِ موعد
    // الزامی می‌شود
    final t = _task ?? {};
    final hasDueDate = t['due_date'] != null || t['deadline'] != null;
    final needsDueDate = t['task_type'] == 'periodic' && !hasDueDate;
    DateTime? delegateDueDate;

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
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
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
                                    ? Icon(Icons.check_circle, color: c.primary)
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
                      // 🔧 رفعِ باگ: توضیحِ ارجاع چندخطی — قبلاً تک‌خطی بود و Enter خطِ جدید نمی‌ساخت
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: c.textStrong, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'توضیح (اختیاری)...',
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
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

                  // 🔧 طبق درخواست: عیناً طبقِ نسخه‌ی وب — اگر کار هنوز
                  // موعدی نداشته، چون دارد به کسِ دیگری ارجاع می‌شود،
                  // تعیینِ موعد الزامی می‌شود
                  if (needsDueDate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showCustomPersianDatePicker(
                            ctx,
                            initialDate: delegateDueDate,
                          );
                          if (picked != null) {
                            setSheetState(() => delegateDueDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: delegateDueDate == null
                                  ? c.danger.withValues(alpha: 0.6)
                                  : c.borderSoft,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: delegateDueDate == null
                                    ? c.danger
                                    : c.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                delegateDueDate != null
                                    ? _toShamsi(
                                        delegateDueDate!.toIso8601String(),
                                      )
                                    : 'موعد انجام (الزامی)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: delegateDueDate == null
                                      ? c.danger
                                      : c.textStrong,
                                ),
                              ),
                            ],
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
                        onPressed:
                            (selectedUserId == null ||
                                (needsDueDate && delegateDueDate == null))
                            ? null
                            : () {
                                AppNav.back();
                                _delegateTask(
                                  selectedUserId!,
                                  notes: notesController.text.trim(),
                                  dueDate: delegateDueDate,
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
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
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
                  hintText: 'مثلا: لطفا این کار را در اولویت قرار دهید...',
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
                      onPressed: () => AppNav.back(),
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
                        AppNav.back();
                        _sendReminder(msg);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
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

  /// [setNew]: کار موعد ندارد (مثلاً موعدش حذف شده) و این دیالوگ برایِ
  /// «تعیینِ موعد» باز شده — همان API تمدید (مثلِ نسخه‌ی وب)؛ برایِ کارِ
  /// خودی سرور خودکار تأیید می‌کند
  ///
  /// 🔧 طبق درخواست: اول بلافاصله تقویم باز می‌شود و با یک لمس روی روز،
  /// همان تاریخ انتخاب می‌شود؛ بعد صفحه‌ی تمدید (تاریخِ انتخاب‌شده +
  /// توضیح/دلیل + «تأیید») می‌آید. انصراف از تقویم = هیچ اتفاقی نمی‌افتد
  Future<void> _showRequestDeadlineDialog({bool setNew = false}) async {
    final first = await showCustomPersianDatePicker(
      context,
      initialDate: DateTime.now(),
      firstDate: Jalali.now(),
      pickOnTap: true,
    );
    if (first == null || !mounted) return;
    DateTime? selectedDate = first;
    final reasonController = TextEditingController();
    final c = AppColors.of(context);
    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // 🔧 طبق درخواست: عنوانِ «درخواست تمدید موعد انجام» و زیرش موعدِ فعلی
          title: Text(
            setNew ? 'تعیین موعد' : 'درخواست تمدید موعد انجام',
            style: TextStyle(fontSize: 16, color: c.textStrong),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!setNew) ...[
                Row(
                  children: [
                    Text(
                      'موعد فعلی: ',
                      style: TextStyle(fontSize: 13, color: c.textMuted),
                    ),
                    Text(
                      _toShamsi(
                        (_task?['due_date'] ?? _task?['deadline'])?.toString(),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textStrong,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: () async {
                  final picked = await showCustomPersianDatePicker(
                    ctx,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: Jalali.now(),
                    pickOnTap: true,
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
                            ? (setNew
                                  ? 'موعد را انتخاب کنید'
                                  : 'موعد جدید را انتخاب کنید')
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
                  hintText: setNew
                      ? 'توضیح (الزامی)...'
                      : 'دلیل درخواست تمدید (الزامی)...',
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
              onPressed: () => AppNav.back(),
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
                AppNav.back();
                _requestDeadlineExtension(selectedDate!, reason);
              },
              child: Text('تأیید', style: TextStyle(color: c.primary)),
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
          // 🔧 طبق درخواست: جایِ «تأیید» و «رد» جابه‌جا شد
          TextButton(
            onPressed: () {
              AppNav.back();
              _approveDeadlineRequest(request['id']);
            },
            child: Text('تأیید', style: TextStyle(color: c.success)),
          ),
          TextButton(
            onPressed: () {
              AppNav.back();
              _showRejectionReasonDialog(
                title: 'رد درخواست تمدید موعد',
                onSubmit: (reason) =>
                    _rejectDeadlineRequest(request['id'], reason),
              );
            },
            child: Text('رد', style: TextStyle(color: c.danger)),
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
          'درخواست رفع تأخیر دوره‌ای',
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              AppNav.back();
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
              AppNav.back();
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
              AppNav.back();
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
              onPressed: () => AppNav.back(),
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
                AppNav.back();
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
              AppNav.back();
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
              AppNav.back();
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                AppSnack.error('خطا', 'دلیل درخواست الزامی است');
                return;
              }
              AppNav.back();
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
              AppNav.back();
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
              AppNav.back();
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
          'آیا از پایان‌دادن فوری این کار دوره‌ای مطمئن هستید؟',
          style: TextStyle(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              AppNav.back();
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reasonRequired && reason.isEmpty) {
                AppSnack.error('خطا', 'دلیل رد الزامی است');
                return;
              }
              AppNav.back();
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
    final adding = <String>{};
    // 🔧 طبق درخواست (مثلِ فرمِ افزودنِ وب): دسترسی‌هایِ کاربرِ جدید
    final perms = <String, bool>{'att': true, 'hist': true, 'chk': true};
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
                // 🔧 طبق درخواست: بدونِ عنوان/توضیح — فقط جستجویِ کاربران
                const SizedBox(height: 16),
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
                const SizedBox(height: 10),
                // سه سوییچِ دسترسی بالایِ فهرست — برایِ کاربری که انتخاب می‌شود
                // 🔧 طبق درخواست: سوییچ‌ها در یک کادرِ مجزا، تمام‌عرض و هم‌اندازه‌ی
                // کادرِ جستجو (پهنا با همان حاشیه‌ی ۱۶، ارتفاعِ ۴۸)، چیده‌شده از راست
                Container(
                  width: double.infinity,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderSoft),
                  ),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 6,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final e in const [
                        ('att', 'پیوست‌ها'),
                        ('hist', 'تاریخچه'),
                        ('chk', 'چک‌لیست'),
                      ])
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 34,
                              height: 24,
                              child: OverflowBox(
                                maxWidth: 64,
                                maxHeight: 48,
                                child: Transform.scale(
                                  scale: 0.85,
                                  child: AppSwitch(
                                    value: perms[e.$1] ?? true,
                                    activeColor: c.primary,
                                    onChanged: (v) =>
                                        setSheetState(() => perms[e.$1] = v),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              e.$2,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textStrong,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: candidates.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'کاربری یافت نشد',
                            style: TextStyle(color: c.textMuted, fontSize: 13),
                          ),
                        )
                      : Material(
                          type: MaterialType.transparency,
                          child: ListView(
                            shrinkWrap: true,
                            children: candidates.map((u) {
                              final display = userDisplay(u);
                              final uid = u['id'].toString();
                              final isAdding = adding.contains(uid);
                              // 🔧 طبق درخواست: کلِ ردیف (نام، آواتار، فضایِ خالی
                              // و آیکنِ «+») قابلِ‌لمس است، نه فقط نام
                              // 🔧 طبق درخواست: بعد از انتخابِ کاربر، فهرست بسته
                              // می‌شود و هیچ فیلدی (جستجو) فوکوس نمی‌گیرد
                              Future<void> add() async {
                                if (adding.contains(uid)) return;
                                setSheetState(() => adding.add(uid));
                                final ok = await _addViewer(
                                  u['id'],
                                  perms: perms,
                                );
                                adding.remove(uid);
                                if (ok) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  AppNav.back();
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => FocusManager.instance.primaryFocus
                                        ?.unfocus(),
                                  );
                                } else {
                                  setSheetState(() {});
                                }
                              }

                              return ListTile(
                                onTap: add,
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
                                trailing: isAdding
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: c.primary,
                                        ),
                                      )
                                    : IconButton(
                                        onPressed: add,
                                        icon: Icon(
                                          Icons.add_circle_outline,
                                          color: c.primary,
                                        ),
                                      ),
                              );
                            }).toList(),
                          ),
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
                      onPressed: () => AppNav.back(),
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
                        AppNav.back();
                        _approveOrReject(false, notes: notes);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
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
                      onPressed: () => AppNav.back(),
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
                        AppNav.back();
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
                          borderRadius: BorderRadius.circular(AppRadius.button),
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

  Future<void> _delegateTask(
    int toUserId, {
    String? notes,
    DateTime? dueDate,
  }) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/delegate.php',
        data: {
          'task_id': widget.taskId,
          'to_user_id': toUserId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (dueDate != null) 'due_date': _isoDate(dueDate),
        },
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);

      if (data['success'] == true) {
        _leaveAfterAction('✅ موفق', data['message'] ?? 'کار ارجاع شد');
      } else if (!_handleOverdueDelegateBlock(data)) {
        AppSnack.error('خطا', data['message'] ?? 'خطا در ارجاع');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (!_handleOverdueDelegateBlock(e)) {
        AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
      }
    }
  }

  /// 🔧 طبق درخواست (مثلِ نسخه‌ی وب): وقتی موعدِ کار گذشته و سرور ارجاع را با
  /// کدِ `overdue_periodic` رد می‌کند، کنارِ همان پیامِ هشدار دکمه‌ی
  /// «تمدید موعد» هم می‌آید. سرور این خطا را با HTTP 400 برمی‌گرداند، پس هم
  /// پاسخِ عادی و هم DioException را بررسی می‌کند. اگر این حالت نبود false
  bool _handleOverdueDelegateBlock(Object? dataOrError) {
    Object? body = dataOrError;
    if (dataOrError is dio.DioException) body = dataOrError.response?.data;
    if (body is String) body = ApiClient.parseResponse(body);
    if (body is! Map || body['code'] != 'overdue_periodic') return false;
    AppSnack.warning(
      'موعد کار گذشته',
      (body['message'] ??
              'موعد این کار گذشته است — امکان ارجاع نیست. ابتدا موعد کار را تمدید کنید')
          .toString(),
      duration: const Duration(seconds: 5),
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
          _showRequestDeadlineDialog();
        },
        child: const Text(
          'تمدید موعد',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
    return true;
  }

  Future<void> _approveOrReject(bool approve, {String? notes}) async {
    if (_isUpdating) return;
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
        ApiClient.markTaskNotificationsRead(widget.taskId);
        _leaveAfterAction(
          approve ? '✅ تأیید شد' : 'رد شد',
          data['message'] ?? '',
        );
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در عملیات');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
    }
  }

  // 🔧 «تأیید و نگه‌داری» — فقط تعریف‌کننده: کار تأیید و در فهرست خودش می‌ماند
  Future<void> _approveAndKeep({String? notes}) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-and-keep.php',
        data: {
          'task_id': widget.taskId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);
      if (data['success'] == true) {
        ApiClient.markTaskNotificationsRead(widget.taskId);
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
  Future<void> _approveAndDelegate(int toUserId, {String? notes}) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final res = await ApiClient.dio.post(
        '/api/tasks/approve-and-delegate.php',
        data: {
          'task_id': widget.taskId,
          'to_user_id': toUserId,
          'approve_notes': notes ?? '',
          'delegate_notes': notes ?? '',
        },
      );
      final data = ApiClient.parseResponse(res.data);
      setState(() => _isUpdating = false);
      if (data['success'] == true) {
        ApiClient.markTaskNotificationsRead(widget.taskId);
        _leaveAfterAction(
          '✅ تأیید شد',
          data['message'] ?? 'کار تأیید و ارجاع داده شد',
        );
      } else if (!_handleOverdueDelegateBlock(data)) {
        AppSnack.error('خطا', data['message'] ?? 'خطا در عملیات');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      if (!_handleOverdueDelegateBlock(e)) {
        AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
      }
    }
  }

  /// 🔧 رفعِ باگ (گزارشِ کاربر): قبلاً «تأیید» و «تأیید و نگه‌داری» بدونِ
  /// گرفتنِ توضیح مستقیم ثبت می‌شدند. حالا عیناً مثلِ مودالِ تأییدِ وب
  /// (approveModal): «توضیحات تأیید (اختیاری)» + دکمه‌هایِ تأیید / تأیید و
  /// نگه‌داری / تأیید و ارجاع — توضیح به هر سه ارسال می‌شود
  void _showApproveOptionsSheet({
    required bool isCreator,
    required bool isAssignee,
  }) {
    final c = AppColors.of(context);
    final notesController = TextEditingController();

    Widget action(
      String label,
      Color color,
      VoidCallback onTap, {
      bool filled = false,
    }) => SizedBox(
      width: double.infinity,
      height: 46,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
              child: Text(label),
            ),
    );

    Get.dialog(
      Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تأیید کار',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textStrong,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'با تأیید این کار، به مرحله بعد یا تأیید نهایی ارسال می‌شود.',
                style: TextStyle(fontSize: 12.5, color: c.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: c.textStrong),
                decoration: InputDecoration(
                  hintText: 'توضیحات تأیید (اختیاری)...',
                  hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: c.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              action('تأیید', c.success, () {
                AppNav.back();
                _approveOrReject(true, notes: notesController.text.trim());
              }, filled: true),
              if (isCreator) ...[
                const SizedBox(height: 8),
                action('تأیید و نگه‌داری', c.primary, () {
                  AppNav.back();
                  _approveAndKeep(notes: notesController.text.trim());
                }),
              ],
              if (isAssignee) ...[
                const SizedBox(height: 8),
                PlanGate(
                  feature: PlanFeature.delegate,
                  label: 'ارجاع کار',
                  child: action('تأیید و ارجاع', c.warning, () {
                    AppNav.back();
                    _showApproveAndDelegatePicker(
                      initialNotes: notesController.text.trim(),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => AppNav.back(),
                child: Text('انصراف', style: TextStyle(color: c.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApproveAndDelegatePicker({String initialNotes = ''}) {
    if (!checkPlanAccess(PlanFeature.delegate, label: 'ارجاع کار')) return;
    if (_users.isEmpty) {
      AppSnack.warning('توجه', 'کاربری برای ارجاع یافت نشد');
      return;
    }
    String searchQuery = '';
    final searchController = TextEditingController();
    // توضیحی که در دیالوگِ تأیید نوشته شده، همین‌جا ادامه پیدا می‌کند
    final notesController = TextEditingController(text: initialNotes);
    dynamic selectedUserId;
    String? selectedUserName;
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
                              final selected = selectedUserId == u['id'];
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
                                trailing: selected
                                    ? Icon(Icons.check_circle, color: c.primary)
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
                      // 🔧 رفعِ باگ: توضیحِ ارجاع چندخطی — قبلاً تک‌خطی بود و Enter خطِ جدید نمی‌ساخت
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(color: c.textStrong, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'توضیح (اختیاری)...',
                        hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
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
                                AppNav.back();
                                _approveAndDelegate(
                                  selectedUserId,
                                  notes: notesController.text.trim(),
                                );
                              },
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
                        child: Text(
                          selectedUserName == null
                              ? 'یک نفر را انتخاب کنید'
                              : 'تأیید و ارجاع به $selectedUserName',
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
        AppNav.back(result: true);
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
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              AppNav.back();
              await _deleteTask();
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  /// 🔧 طبق درخواست: بعد از عملیاتی که کار را از دستِ کاربر خارج یا تمام
  /// می‌کند (تکمیل، تأیید، رد، ارجاع، تأیید و ارجاع، اتمام دوره)، صفحه بسته
  /// می‌شود و به همان صفحه‌ای برمی‌گردد که جزئیات از آن باز شده بود (با
  /// نتیجه‌ی true تا آن صفحه لیستش را تازه کند)؛ اگر صفحه‌ی قبلی‌ای نبود
  /// (مثلاً باز شدن از نوتیفیکیشن)، به داشبورد می‌رود. پیامِ موفقیت روی
  /// همان صفحه‌ی مقصد نشان داده می‌شود.
  void _leaveAfterAction(String title, String message) {
    _hasChanges = true;
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      AppNav.back(result: true);
    } else {
      final user = ApiClient.currentUser;
      if (user != null) Get.offAll(() => MainShell(user: user));
    }
    AppSnack.success(title, message);
  }

  Future<void> _updateStatus(String status, {String? notes}) async {
    if (_isUpdating) return;
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
        if (status == 'completed') {
          _leaveAfterAction(
            '✅ موفق',
            data['message'] ?? 'وضعیت به‌روزرسانی شد',
          );
          return;
        }
        _hasChanges = true;
        _loadDetail();
        AppSnack.success('✅ موفق', data['message'] ?? 'وضعیت به‌روزرسانی شد');
      } else {
        AppSnack.error('خطا', data['message'] ?? 'خطا در تغییر وضعیت');
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      AppSnack.error('خطا', _dioErrorMessage(e, 'خطا در اتصال به سرور'));
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
                // 🔧 طبق درخواست: تاریخ و ساعتِ بارگذاری (created_at سرور)
                if ((att['created_at'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _toShamsiDateTime(att['created_at']?.toString()),
                      style: TextStyle(fontSize: 11, color: c.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          // دانلود
          IconButton(
            icon: Icon(Icons.download_outlined, size: 20, color: c.primary),
            onPressed: () => _openFile(att['file_path'] ?? ''),
          ),
          // 🔧 طبق درخواست: پیوست فقط «دانلود» و «حذف» دارد (بدونِ تغییرِ نام)
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
            onPressed: () => AppNav.back(),
            child: Text('انصراف', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              AppNav.back(); // اول دیالوگ را ببند
              await _deleteAttachment(attId); // بعد حذف کن
            },
            child: Text('حذف', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
    );
  }

  /// تاریخچه‌یِ قابلِ‌نمایش — دقیقاً مطابقِ وب، ردیف‌هایِ تکراریِ کارِ
  /// دوره‌ای حذف می‌شوند: وقتی تکمیلِ دوره نیاز به تأیید دارد، هم‌زمان
  /// یک ردیفِ 'completed'/'completed_rejected' (برایِ موتورِ دوره) و
  /// یک ردیفِ 'pending_approval' (همان رویداد) ثبت می‌شود؛ فقط دومی
  /// نشان داده می‌شود.
  List<dynamic> get _visibleHistory {
    DateTime? parseTime(dynamic h) {
      final raw = h['created_at']?.toString();
      if (raw == null || raw.isEmpty) return null;
      try {
        return DateTime.parse(raw.replaceFirst(' ', 'T'));
      } catch (_) {
        return null;
      }
    }

    final pendings = _history
        .where((h) => h['action'] == 'pending_approval')
        .toList();

    String toNameOf(dynamic h) =>
        '${h['to_user_first_name'] ?? ''} ${h['to_user_last_name'] ?? ''}'
            .trim();
    bool sameMoment(dynamic a, dynamic b) {
      if (a['from_user_id']?.toString() != b['from_user_id']?.toString()) {
        return false;
      }
      final ta = parseTime(a), tb = parseTime(b);
      return ta != null &&
          tb != null &&
          ta.difference(tb).inMilliseconds.abs() <= 2000;
    }

    // 🔧 تأییدِ وسطِ زنجیره (مطابقِ وب، ۱۴۰۵/۰۸/۰۵): سرور هم‌زمان 'approved' و
    // 'pending_approval' (به نفرِ بالاتر) ثبت می‌کند — یک رویدادند. ردیفِ «در انتظارِ
    // تأیید» پنهان و نامِ نفرِ بالاتر روی ردیفِ «تأیید» می‌نشیند (_forwarded_to).
    final merged = <dynamic>{};
    final withForward = _history
        .map((h) {
          if (h['action'] != 'approved') return h;
          final p = pendings.cast<dynamic>().firstWhere(
            (x) =>
                !merged.contains(x) &&
                sameMoment(x, h) &&
                toNameOf(x).isNotEmpty,
            orElse: () => null,
          );
          if (p == null) return h;
          merged.add(p);
          return <String, dynamic>{
            ...(h as Map).cast<String, dynamic>(),
            '_forwarded_to': toNameOf(p),
            // «…تأیید خودکار برای نفرات قبلی…»: نفراتِ میانی خودکار تأیید شده‌اند
            '_forward_auto': (p['notes'] ?? '').toString().contains(
              'تأیید خودکار',
            ),
          };
        })
        .where((h) => !merged.contains(h))
        .toList();

    return withForward.where((h) {
      final action = h['action'];
      if (action != 'completed' && action != 'completed_rejected') {
        return true;
      }
      final t = parseTime(h);
      if (t == null) return true;
      final hasMatch = pendings.any((p) {
        if (p['from_user_id']?.toString() != h['from_user_id']?.toString()) {
          return false;
        }
        final pt = parseTime(p);
        return pt != null && (pt.difference(t)).inMilliseconds.abs() <= 2000;
      });
      return !hasMatch;
    }).toList();
  }

  Widget _historyItem(Map<String, dynamic> h, {required bool isLast}) {
    // 🔧 ستون action در task_history مقدار 'deleted' را ندارد و سرور خالی ذخیره می‌کند؛
    // از روی متن ثابت همان ردیف تشخیص داده می‌شود تا «نامشخص» نشان داده نشود
    final rawAction = h['action'] as String? ?? '';
    final action =
        rawAction.isEmpty &&
            (h['notes'] ?? '').toString().trim() == 'کار حذف شد'
        ? 'deleted'
        : rawAction;
    final actionLbl = TaskLabels.actionLabel(action);
    final badgeBg = TaskLabels.historyBadgeBg(action);
    final badgeFg = TaskLabels.historyBadgeFg(action);

    // نام فردی که عمل را انجام داد
    final fromName =
        '${h['from_user_first_name'] ?? ''} ${h['from_user_last_name'] ?? ''}'
            .trim();
    // نام فرد مقصد (برای ارجاع/تأیید/تمدید موعد)
    final toName =
        '${h['to_user_first_name'] ?? ''} ${h['to_user_last_name'] ?? ''}'
            .trim();
    final c = AppColors.of(context);
    final (dateStr, timeStr) = _historyDateParts(h['created_at']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: c.borderSoft, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ستونِ زمان + بج — با خطِ عمودیِ جداکننده از ستونِ کاربر،
          // عیناً مطابقِ وب (ml-left / ml-action-badge)
          Container(
            width: 84,
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.borderSoft, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: c.textMuted.withValues(alpha: 0.75),
                    height: 1.6,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: c.textMuted.withValues(alpha: 0.75),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    actionLbl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // ستونِ کاربر + توضیحات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: c.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fromName.isEmpty ? 'نامشخص' : fromName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: c.textStrong,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                ..._historyCustomContent(h, action, fromName, toName, c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// متنِ اختصاصیِ هر نوع رویداد — عیناً مطابقِ منطقِ displayHistory در
  /// نسخه‌ی وب (pages/task-detail.php)
  List<Widget> _historyCustomContent(
    Map<String, dynamic> h,
    String action,
    String fromName,
    String toName,
    AppColors c,
  ) {
    final notes = (h['notes'] ?? '').toString();

    Widget note(String text, {bool small = false}) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 10.5 : 12,
          color: c.textMuted.withValues(alpha: small ? 0.75 : 1),
          height: 1.6,
        ),
      ),
    );

    // ── تمدید موعد: خطِ «قدیم ← جدید» + دلیل، به‌جایِ یادداشتِ خام ──
    if (action == 'deadline_extended') {
      final widgets = <Widget>[];
      Map<String, dynamic>? data;
      try {
        data = jsonDecode(notes) as Map<String, dynamic>;
      } catch (_) {
        data = null;
      }
      if (data == null) {
        if (notes.isNotEmpty) widgets.add(note(notes));
        return widgets;
      }
      final fromIsRequester = data['from_is_requester'] == true;
      if (toName.isNotEmpty && toName != fromName && !fromIsRequester) {
        widgets.add(note('به درخواست: $toName'));
      }
      final oldD = data['old_deadline'] == null
          ? 'نامشخص'
          : _toShamsi(data['old_deadline']?.toString());
      final newD = data['new_deadline'] == null
          ? 'نامشخص'
          : _toShamsi(data['new_deadline']?.toString());
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              Text(
                oldD,
                style: TextStyle(
                  fontSize: 12,
                  color: c.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const Icon(
                Icons.arrow_back_rounded,
                size: 13,
                color: Color(0xFFFFC107),
              ),
              Text(
                newD,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
        ),
      );
      final reason = data['reason']?.toString();
      if (reason != null && reason.trim().isNotEmpty) {
        widgets.add(note('دلیل: $reason', small: true));
      }
      return widgets;
    }

    // ── رد درخواست تمدید موعد: یادداشتِ خام جایگزینِ کاملِ متن می‌شود ──
    if (action == 'deadline_rejected') {
      final widgets = <Widget>[];
      if (toName.isNotEmpty) {
        widgets.add(note('درخواست تمدید موعد از $toName رد شد'));
      }
      if (notes.isNotEmpty) widgets.add(note('توضیح: $notes', small: true));
      return widgets;
    }

    // متن‌هایِ پیش‌فرضِ سرور (بدونِ توضیحِ کاربر) — پیشوند حذف، فقط توضیحِ خودِ کاربر می‌ماند
    String stripPrefix(String txt, List<String> prefixes) {
      var t = txt.trim();
      for (final px in prefixes) {
        if (t.startsWith(px)) t = t.substring(px.length);
      }
      return t.replaceFirst(RegExp(r'^[:：\s]+'), '').trim();
    }

    // ── تأییدِ وسطِ زنجیره (ادغام‌شده در _visibleHistory) ──
    final forwardedTo = (h['_forwarded_to'] ?? '').toString();
    if (action == 'approved' && forwardedTo.isNotEmpty) {
      final extra = stripPrefix(notes, [
        'تأیید شد و ارسال برای تأیید نفر بالاتر',
        'تأیید شد',
      ]);
      return [
        note('تأیید کرد و برای تأیید $forwardedTo ارسال شد'),
        if (h['_forward_auto'] == true)
          note('تأیید نفرات میانی زنجیره خودکار انجام شد', small: true),
        if (extra.isNotEmpty) note('توضیح: $extra', small: true),
      ];
    }

    // ── ارسالِ کارِ تکمیل‌شده برایِ تأیید ──
    if (action == 'pending_approval' &&
        toName.isNotEmpty &&
        notes.trim().startsWith('کار تکمیل شد')) {
      final extra = stripPrefix(notes, ['کار تکمیل شد']);
      return [
        note('کار را تکمیل کرد و برای تأیید $toName ارسال شد'),
        if (extra.isNotEmpty) note('توضیح: $extra', small: true),
      ];
    }

    // ── بقیه‌ی اکشن‌ها: یادداشتِ خام (اگر بود) + متنِ اختصاصیِ هر نوع ──
    // «تأیید شد:» بدونِ توضیح → «تأیید شد» (دو نقطه‌یِ آویزان حذف)
    final widgets = <Widget>[];
    final cleanNotes = notes.replaceFirst(RegExp(r'[:：\s]+$'), '');
    if (cleanNotes.trim().isNotEmpty) widgets.add(note(cleanNotes));

    switch (action) {
      case 'created':
        if (toName.isNotEmpty && toName != fromName) {
          widgets.insert(0, note('واگذار به: $toName'));
        }
        final desc = (_task?['description'] ?? '').toString();
        if (desc.isNotEmpty) widgets.add(note('توضیحات: $desc', small: true));
        break;
      case 'delegated':
        if (toName.isNotEmpty) widgets.insert(0, note('ارجاع به $toName'));
        break;
      case 'pending_approval':
        if (toName.isNotEmpty) widgets.add(note('در انتظار تأیید: $toName'));
        break;
      case 'deadline_requested':
        if (toName.isNotEmpty) widgets.add(note('در انتظار بررسی: $toName'));
        break;
    }
    return widgets;
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
    // 🔧 طبق درخواست: عیناً طبقِ نسخه‌ی وب — هایلایتِ آیتم‌هایی که
    // دقیقاً به خودِ کاربرِ جاری ارجاع شده‌اند
    final isAssignedToMe =
        item['assignee_type'] == 'user' &&
        _currentUserId != null &&
        item['assignee_value']?.toString() == _currentUserId.toString();
    final c = AppColors.of(context);

    return InkWell(
      onTap: (isDone || !canToggle) ? null : () => _toggleItem(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: isAssignedToMe
            ? BoxDecoration(
                color: c.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
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
                  // مثلِ وب: اگر توضیح دارد و قابلِ‌ویرایش است، با لمسِ
                  // خودِ متن ویرایش می‌شود
                  if ((item['description'] ?? '').toString().isNotEmpty)
                    GestureDetector(
                      onTap: (canManage && !isAssigned)
                          ? () => _showChecklistDescDialog(item)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item['description'].toString(),
                          style: TextStyle(fontSize: 11.5, color: c.textMuted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 🔧 طبق درخواست (مثلِ وب — chk-desc-icon): به‌جایِ پیوستِ فایل،
            // آیکنِ «پیام» برایِ افزودنِ توضیح؛ فقط برایِ تعریف‌کننده، آیتمِ
            // تیک‌نخورده و ارجاع‌نشده، و وقتی هنوز توضیحی ندارد
            if (canManage &&
                !isAssigned &&
                (item['description'] ?? '').toString().isEmpty)
              GestureDetector(
                onTap: () => _showChecklistDescDialog(item),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chat_outlined,
                    size: 16,
                    color: c.textMuted,
                  ),
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

  /// ردیفِ «دسترسی به» — مثلِ وب (renderViewersCell): دکمه‌ی «افزودن
  /// دسترسی»، و فهرستِ کاربران؛ پیش‌فرض فقط نام، با لمس جزئیاتِ دسترسی
  /// (پیوست‌ها/تاریخچه/چک‌لیست + اعمال + حذف) باز می‌شود
  Widget _viewersRow(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.visibility_outlined,
                size: 14,
                color: c.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'دسترسی به',
              style: TextStyle(fontSize: 13, color: c.textMuted),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showManageViewersSheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 16,
                    color: c.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'افزودن دسترسی',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_viewers.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 36),
            child: Text(
              'کسی اضافه نشده',
              style: TextStyle(fontSize: 12.5, color: c.textMuted),
            ),
          )
        else
          ..._viewers.map((v) => _viewerItem(c, v)),
      ],
    );
  }

  Widget _viewerItem(AppColors c, dynamic v) {
    final id = v['id'].toString();
    final open = _openViewerRows.contains(id);
    final d = _viewerDraft(v);
    final name = (v['full_name'] ?? '').toString().trim();
    Widget sw(String key, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🔧 طبق درخواست: فاصله‌ی سوییچ تا متن کمتر — Transform.scale فقط
        // ظاهر را کوچک می‌کرد و جایِ اصلی (پهنایِ کاملِ Switch) خالی می‌ماند؛
        // FittedBox خودِ اندازه‌ی چیدمان را هم کوچک می‌کند
        // اندازه‌ی ظاهری همان سوییچِ استانداردِ اپ (AppSwitch)؛ فقط جایِ خالیِ
        // دورش (پهنایِ اصلیِ Switch پیش از کوچک‌شدن) حذف می‌شود
        // طبق درخواست: حدودِ ۱۵٪ کوچک‌تر از سوییچِ استاندارد
        SizedBox(
          width: 34,
          height: 24,
          child: OverflowBox(
            maxWidth: 64,
            maxHeight: 48,
            child: Transform.scale(
              scale: 0.85,
              child: AppSwitch(
                value: d[key] ?? true,
                activeColor: c.primary,
                onChanged: (val) => setState(() => d[key] = val),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: c.textStrong)),
      ],
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        // 🔧 طبق درخواست: در تمِ تیره به‌جایِ زمینه‌ی مشکی، بنفشِ کم‌رنگ
        color: Theme.of(context).brightness == Brightness.dark
            ? c.primary.withValues(alpha: 0.18)
            : c.bgPage,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => open ? _openViewerRows.remove(id) : _openViewerRows.add(id),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? 'کاربر' : name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textStrong,
                    ),
                  ),
                ),
                Icon(
                  open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: c.textMuted,
                ),
              ],
            ),
          ),
          if (open) ...[
            const SizedBox(height: 6),
            // 🔧 طبق درخواست: «حذف» و «اعمال» آیکن شدند و در همان ردیفِ سه
            // سوییچ، منتهی‌الیه سمتِ چپ (اول حذف، بعد اعمال) قرار گرفتند
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      sw('att', 'پیوست‌ها'),
                      sw('hist', 'تاریخچه'),
                      sw('chk', 'چک‌لیست'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeViewer(v['id']),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: c.danger,
                  ),
                ),
                IconButton(
                  tooltip: 'اعمال',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _applyViewerPermission(v),
                  icon: Icon(Icons.check_rounded, size: 22, color: c.success),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// ردیفِ «موعد انجام» — مثلِ [_infoRow] ولی با دو آیکنِ کوچکِ عملیاتی
  /// جلویِ تاریخ: تمدیدِ موعد (برایِ مسئولِ فعلی، وقتی واقعاً امکانش
  /// هست — همان شرطِ دکمه‌ی شناورِ «تمدید موعد») و حذفِ موعد (فقط وقتی
  /// سازنده و مسئول یک نفرند و خودِ همان شخص است — دقیقاً همان شرطِ سرور
  /// در api/tasks/clear-due-date.php).
  Widget _dueDateRow(
    AppColors c,
    Map<String, dynamic> t, {
    required String status,
    required bool isCreator,
    required bool isAssignee,
    required bool isPending,
  }) {
    final hasDueDate = t['due_date'] != null || t['deadline'] != null;
    final canExtend =
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
    // درخواستِ تمدیدِ موعدی که خودِ مسئول فرستاده و هنوز بررسی نشده
    final extendPending =
        isAssignee &&
        t['deadline'] != null &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected' &&
        (t['has_pending_deadline_request'] == 1 ||
            t['has_pending_deadline_request'] == true);
    final canClear =
        isCreator &&
        t['task_type'] == 'periodic' &&
        t['creator_id']?.toString() == t['assignee_id']?.toString() &&
        hasDueDate;
    // 🔧 طبق درخواست (مثلِ نسخه‌ی وب): وقتی کار موعد ندارد (مثلاً موعدش
    // حذف شده)، علامتِ «+» برایِ مسئولِ انجام تا بتواند موعد بگذارد
    final canSetDueDate =
        !hasDueDate &&
        isAssignee &&
        t['task_type'] == 'periodic' &&
        t['is_workflow_task'] != 1 &&
        t['is_workflow_task'] != true &&
        !isPending &&
        status != 'completed' &&
        status != 'approved' &&
        status != 'rejected' &&
        t['has_pending_deadline_request'] != 1 &&
        t['has_pending_deadline_request'] != true;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.event_outlined, size: 14, color: c.primary),
        ),
        const SizedBox(width: 10),
        Text('موعد انجام', style: TextStyle(fontSize: 13, color: c.textMuted)),
        const Spacer(),
        // 🔧 طبق درخواست (مثلِ وب): اول تاریخ، بعد آیکن‌ها؛ هر آیکن یک
        // مربعِ ۲۶×۲۶ با پس‌زمینه‌ی طوسیِ روشن و آیکنِ طوسی
        // (.deadline-request-icon) که با لمس رنگِ معنایی‌اش را می‌گیرد —
        // تمدید: ساعت‌شنی/سبز، حذف: ضربدر/قرمز، تعیینِ موعد: «+»/سبز
        Text(
          hasDueDate ? _toShamsi(t['due_date']) : 'بدون موعد',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textStrong,
          ),
        ),
        // 🔧 طبق درخواست (عیناً وب — enable/disableRequestButton): آیکنِ
        // تمدید «+» است؛ وقتی درخواستی در انتظار است، ساعت‌شنیِ غیرفعال
        if (canExtend) ...[
          const SizedBox(width: 8),
          _DeadlineIconButton(
            icon: Icons.add_rounded,
            activeColor: const Color(0xFF1B7B39),
            tooltip: 'درخواست تمدید موعد انجام',
            onTap: _showRequestDeadlineDialog,
          ),
        ] else if (extendPending) ...[
          const SizedBox(width: 8),
          const _DeadlineIconButton(
            icon: Icons.hourglass_empty_rounded,
            activeColor: Color(0xFF9CA3AF),
            tooltip: 'درخواست در انتظار بررسی...',
            onTap: null,
          ),
        ],
        if (canSetDueDate) ...[
          const SizedBox(width: 8),
          _DeadlineIconButton(
            icon: Icons.add_rounded,
            activeColor: const Color(0xFF1B7B39),
            tooltip: 'تعیین موعد',
            onTap: () => _showRequestDeadlineDialog(setNew: true),
          ),
        ],
        if (canClear) ...[
          const SizedBox(width: 8),
          _DeadlineIconButton(
            icon: Icons.close_rounded,
            activeColor: const Color(0xFFDC2626),
            tooltip: 'حذف موعد انجام (این کار بدون ددلاین می‌ماند)',
            onTap: _confirmClearDueDate,
          ),
        ],
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
          borderRadius: BorderRadius.circular(AppRadius.chip),
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

  // رنگِ بنفشِ هدرِ کار — همان #8e57fe نسخه‌ی وب
  static const _headerPurple = Color(0xFF8E57FE);

  // 🔧 رفعِ باگِ «وضعیتِ سفید روی سفید»: رنگِ بج‌هایِ هدر عیناً از custom.css
  // وب (.status-* / .priority-*) — پس‌زمینه‌ی روشن + متنِ تیره‌ی رنگی،
  // مستقل از تمِ روشن/تاریک (چون رویِ هدرِ بنفش‌اند)
  static const (Color, Color) _webBadgeDefault = (
    Color(0xFFF1F3F5),
    Color(0xFF495057),
  );
  static const Map<String, (Color, Color)> _webStatusColors = {
    'not_started': (Color(0xFFF1F3F5), Color(0xFF495057)),
    'in_progress': (Color(0xFFE7F0FF), Color(0xFF1554D1)),
    'pending_approval': (Color(0xFFFFF4D6), Color(0xFFA16207)),
    'delegated': (Color(0xFFEEE6FF), Color(0xFF8E57FE)),
    'rejected': (Color(0xFFFFE3E6), Color(0xFFC81E1E)),
    'stopped': (Color(0xFFF1F3F5), Color(0xFF495057)),
    'period_done': (Color(0xFFCFFAFE), Color(0xFF0E7490)),
    'termination_requested': (Color(0xFFE0FFF2), Color(0xFF158463)),
    'needs_renewal': (Color(0xFFEEE6FF), Color(0xFF8E57FE)),
    'overdue': (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  };
  static const Map<String, (Color, Color)> _webPriorityColors = {
    'high': (Color(0xFFFFE3E3), Color(0xFFCC1F1F)),
    'medium': (Color(0xFFFFF0D0), Color(0xFFC26A06)),
    'low': (Color(0xFFDCEFE1), Color(0xFF1B7B39)),
  };

  // بجِ رویِ هدرِ بنفش — مثلِ وب، پس‌زمینه‌ی روشن و متنِ رنگی (کنتراستِ ثابت)
  Widget _headerBadge(
    String label, {
    required Color bg,
    required Color fg,
    Color? border,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(color: border ?? Colors.transparent),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
    ),
  );
}

// 🔧 طبق درخواست: ارجاعِ یک آیتمِ چک‌لیست به یک نفر یا یک بخشِ خاص —
// عیناً طبقِ نسخه‌ی وب (AssigneePicker با showSections:true، بدونِ
// گزینه‌هایِ «خودم»/«همه کاربران»/«همه بخش‌ها» که مخصوصِ ارجاعِ کلِ
// کار هستند، نه یک آیتمِ تکی)
class _ChecklistAssigneeSheet extends StatefulWidget {
  final List<dynamic> users;
  final List<dynamic> sections;
  final void Function(String type, dynamic value, String label) onSelected;

  const _ChecklistAssigneeSheet({
    required this.users,
    required this.sections,
    required this.onSelected,
  });

  @override
  State<_ChecklistAssigneeSheet> createState() =>
      _ChecklistAssigneeSheetState();
}

class _ChecklistAssigneeSheetState extends State<_ChecklistAssigneeSheet> {
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
            'ارجاع آیتم چک‌لیست',
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
            child: (filteredSections.isEmpty && filteredUsers.isEmpty)
                ? Center(
                    child: Text(
                      'نتیجه‌ای یافت نشد',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                  )
                : ListView(
                    controller: scrollController,
                    children: [
                      if (filteredSections.isNotEmpty) ...[
                        _header(c, 'بخش‌ها'),
                        ...filteredSections.map((s) {
                          final key = s['section_key'];
                          final label = s['section_label'] ?? key;
                          return _tile(
                            c,
                            icon: Icons.groups_outlined,
                            color: c.warning,
                            label: label,
                            onTap: () => _select('section', key, label),
                          );
                        }),
                      ],
                      if (filteredUsers.isNotEmpty) ...[
                        _header(c, 'کاربران'),
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
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: c.textMuted,
      ),
      textAlign: TextAlign.right,
    ),
  );

  Widget _tile(
    AppColors c, {
    IconData? icon,
    Color? color,
    String? avatar,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: (color ?? c.primary).withValues(alpha: 0.12),
        child: icon != null
            ? Icon(icon, size: 16, color: color ?? c.primary)
            : Text(
                avatar ?? '?',
                style: TextStyle(color: c.primary, fontSize: 13),
              ),
      ),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: c.textStrong),
        textAlign: TextAlign.right,
      ),
    );
  }
}

/// آیکنِ کنارِ «موعد انجام» — مثلِ .deadline-request-icon نسخه‌ی وب:
/// مربعِ ۲۶×۲۶، پس‌زمینه‌ی #e9e9e9 و آیکنِ #9ca3af؛ چون موبایل «هاور»
/// ندارد، هنگامِ لمس پس‌زمینه رنگِ معنایی و آیکن سفید می‌شود
class _DeadlineIconButton extends StatefulWidget {
  final IconData icon;
  final Color activeColor;
  final String tooltip;
  final VoidCallback? onTap;
  const _DeadlineIconButton({
    required this.icon,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_DeadlineIconButton> createState() => _DeadlineIconButtonState();
}

class _DeadlineIconButtonState extends State<_DeadlineIconButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (mounted && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(widget.onTap != null),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: _pressed ? widget.activeColor : const Color(0xFFE9E9E9),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _pressed ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
