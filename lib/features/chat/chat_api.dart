import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/plan/plan_access.dart';

/// لایه‌ی API چت — همان endpointهای چتِ وب (api/chat/*.php) بدون تغییر.
///
/// مرحله‌ی ۱: فهرست گفتگوها، پیام‌ها (صفحه‌بندی + polling)، ارسال متن/فایل،
/// پاسخ، ویرایش، حذف، رسیدِ خواندن، شروعِ گفتگوی تازه، حضور (ping).
class ChatApi {
  ChatApi._();

  /// مجموعِ پیام‌های خوانده‌نشده (گفتگوهای بی‌صدا حساب نمی‌شوند — مثلِ تلگرام)
  /// برای بجِ تبِ «چت» در نوار پایین
  static final ValueNotifier<int> unreadTotal = ValueNotifier<int>(0);

  /// «امروز» به تاریخِ سرور (Y-m-d) — آخرین مقداری که conversations.php داده
  static String serverDate = '';

  static bool get enabled => PlanAccess.allows(PlanFeature.chat);

  static String? absoluteUrl(dynamic path) {
    final p = path?.toString() ?? '';
    if (p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return '${ApiClient.baseUrl}/${p.startsWith('/') ? p.substring(1) : p}';
  }

  static String fileUrl(int attachmentId, {bool view = false}) =>
      '${ApiClient.baseUrl}/api/chat/download.php?id=$attachmentId${view ? '&view=1' : ''}';

  static Future<Map<String, String>> authHeaders() async {
    final t = await ApiClient.getToken();
    return t == null ? {} : {'Authorization': 'Bearer $t'};
  }

  static Map<String, dynamic> _ok(dio.Response res) {
    final data = ApiClient.parseResponse(res.data);
    if (data['success'] != true) {
      throw ChatException(
        (data['message'] ?? 'خطا در ارتباط با سرور').toString(),
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static Never _fail(Object e) {
    if (e is ChatException) throw e;
    if (e is dio.DioException) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null)
        throw ChatException(d['message'].toString());
    }
    throw ChatException('خطا در ارتباط با سرور');
  }

  // ── گفتگوها ──
  static Future<List<Map<String, dynamic>>> conversations({
    bool archived = false,
  }) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/conversations.php',
        queryParameters: {'archived': archived ? 1 : 0},
      );
      final data = _ok(res);
      serverDate = (data['server_date'] ?? serverDate).toString();
      final list = (data['conversations'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!archived) {
        unreadTotal.value = list.fold<int>(
          0,
          (s, c) =>
              s +
              (c['is_muted'] == true
                  ? 0
                  : (c['unread_count'] as num? ?? 0).toInt()),
        );
      }
      return list;
    } catch (e) {
      _fail(e);
    }
  }

  /// فقط به‌روزرسانیِ بجِ «چت» (از پوسته‌ی اصلی، هر چند ثانیه)
  static Future<void> refreshUnread() async {
    if (!enabled) return;
    try {
      await conversations();
    } catch (_) {}
  }

  // ── پیام‌ها ──
  static Future<Map<String, dynamic>> messages(
    int conversationId, {
    int? beforeId,
    int? afterId,
    int limit = 40,
  }) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/messages.php',
        queryParameters: {
          'conversation_id': conversationId,
          'limit': limit,
          'before_id': ?beforeId,
          'after_id': ?afterId,
        },
      );
      return _ok(res);
    } catch (e) {
      _fail(e);
    }
  }

  static Future<int> send(
    int conversationId,
    String text, {
    int? replyToId,
    List<ChatUpload> files = const [],
  }) async {
    try {
      final form = dio.FormData();
      form.fields
        ..add(MapEntry('conversation_id', '$conversationId'))
        ..add(MapEntry('message', text));
      if (replyToId != null)
        form.fields.add(MapEntry('reply_to_message_id', '$replyToId'));
      for (final f in files) {
        form.files.add(
          MapEntry(
            'attachments[]',
            dio.MultipartFile.fromBytes(
              f.bytes,
              filename: f.name,
              // send.php نوع فایل را از همین Content-Type بررسی می‌کند
              contentType: dio.DioMediaType.parse(f.mime),
            ),
          ),
        );
      }
      final res = await ApiClient.dio.post('/api/chat/send.php', data: form);
      return (_ok(res)['message_id'] as num).toInt();
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> edit(int messageId, String text) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/edit-message.php',
          data: {'message_id': messageId, 'message': text},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> delete(int messageId, {required bool forEveryone}) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/delete-message.php',
          data: {'message_id': messageId, 'for_everyone': forEveryone},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> markRead(int conversationId, {int? upToId}) async {
    try {
      await ApiClient.dio.post(
        '/api/chat/mark-read.php',
        data: {'conversation_id': conversationId, 'up_to_id': ?upToId},
      );
    } catch (_) {}
  }

  /// user_id → آخرین پیامی که خوانده (برای تیک‌های ✓✓)
  static Future<Map<int, int>> readReceipts(int conversationId) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/read-receipts.php',
        queryParameters: {'conversation_id': conversationId},
      );
      final data = _ok(res);
      final out = <int, int>{};
      for (final p in (data['participants'] as List? ?? [])) {
        final m = p as Map;
        out[(m['user_id'] as num).toInt()] =
            (m['last_read_message_id'] as num? ?? 0).toInt();
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<int> start(int userId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/chat/start.php',
        data: {'user_id': userId},
      );
      return (_ok(res)['conversation_id'] as num).toInt();
    } catch (e) {
      _fail(e);
    }
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/search-users.php',
        queryParameters: {'q': q},
      );
      return (_ok(res)['users'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _fail(e);
    }
  }

  // ── گروه‌ها (مرحله‌ی ۲) ──

  /// ساختِ گروه → شناسه‌ی گفتگو
  static Future<int> createGroup(String title, List<int> memberIds) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/chat/create-group.php',
        data: {'title': title, 'member_ids': memberIds},
      );
      return (_ok(res)['conversation_id'] as num).toInt();
    } catch (e) {
      _fail(e);
    }
  }

  /// اعضا + اختیاراتِ من: {is_owner, can_manage, my_permissions, all_permissions,
  /// group_title, group_avatar_url, members:[{id, full_name, is_owner, is_admin,
  /// permissions, avatar_url, is_online, last_seen_at}]}
  static Future<Map<String, dynamic>> groupMembers(int conversationId) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/group-members.php',
        queryParameters: {'conversation_id': conversationId},
      );
      return _ok(res);
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> addMembers(
    int conversationId,
    List<int> memberIds,
  ) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/group-add-members.php',
          data: {'conversation_id': conversationId, 'member_ids': memberIds},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> removeMember(int conversationId, int userId) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/group-remove-member.php',
          data: {'conversation_id': conversationId, 'user_id': userId},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> leaveGroup(int conversationId) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/leave-group.php',
          data: {'conversation_id': conversationId},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  static Future<void> renameGroup(int conversationId, String title) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/rename-group.php',
          data: {'conversation_id': conversationId, 'title': title},
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  static Future<String?> uploadGroupAvatar(
    int conversationId,
    ChatUpload image,
  ) async {
    try {
      final form = dio.FormData();
      form.fields.add(MapEntry('conversation_id', '$conversationId'));
      form.files.add(
        MapEntry(
          'avatar',
          dio.MultipartFile.fromBytes(
            image.bytes,
            filename: image.name,
            contentType: dio.DioMediaType.parse(image.mime),
          ),
        ),
      );
      final res = await ApiClient.dio.post(
        '/api/chat/upload-group-avatar.php',
        data: form,
      );
      return _ok(res)['avatar_path']?.toString();
    } catch (e) {
      _fail(e);
    }
  }

  /// ارتقا/عزل مدیر، بعد اختیاراتِ دقیق — همان ترتیبِ وب (تغییرِ نقش اختیارات را پاک می‌کند)
  static Future<void> setMemberAccess(
    int conversationId,
    int userId, {
    required bool admin,
    required List<String> permissions,
  }) async {
    try {
      _ok(
        await ApiClient.dio.post(
          '/api/chat/set-member-role.php',
          data: {
            'conversation_id': conversationId,
            'user_id': userId,
            'role': admin ? 'admin' : 'member',
          },
        ),
      );
      _ok(
        await ApiClient.dio.post(
          '/api/chat/set-member-permissions.php',
          data: {
            'conversation_id': conversationId,
            'user_id': userId,
            'permissions': permissions,
          },
        ),
      );
    } catch (e) {
      _fail(e);
    }
  }

  /// بی‌صدا/باصدا (شخصی) → وضعیتِ جدید
  static Future<bool> toggleMute(int conversationId) async {
    try {
      final res = await ApiClient.dio.post(
        '/api/chat/toggle-mute.php',
        data: {'conversation_id': conversationId},
      );
      return _ok(res)['is_muted'] == true;
    } catch (e) {
      _fail(e);
    }
  }

  /// جستجو در پیام‌های یک گفتگو: [{message_id, sender_name, is_own, snippet, date_jalali, time_jalali}]
  static Future<List<Map<String, dynamic>>> searchMessages(
    int conversationId,
    String q,
  ) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/search-messages.php',
        queryParameters: {'q': q, 'conversation_id': conversationId},
      );
      return (_ok(res)['results'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _fail(e);
    }
  }

  /// پیام‌های اطرافِ یک پیام (برای پرش از نتیجه‌ی جستجو)
  static Future<Map<String, dynamic>> messagesAround(
    int conversationId,
    int messageId, {
    int limit = 30,
  }) async {
    try {
      final res = await ApiClient.dio.get(
        '/api/chat/messages.php',
        queryParameters: {
          'conversation_id': conversationId,
          'around_id': messageId,
          'limit': limit,
        },
      );
      return _ok(res);
    } catch (e) {
      _fail(e);
    }
  }

  /// برچسبِ فارسیِ اختیاراتِ گروه — همان GROUP_PERMISSION_LABELS وب
  static const groupPermissionLabels = {
    'pin': 'سنجاق‌کردن پیام',
    'add_member': 'افزودن عضو',
    'remove_member': 'حذف عضو',
    'avatar': 'تغییر اطلاعات گروه (نام و عکس)',
  };

  /// حضور: «آنلاین» در چت — سرور به کاربرِ آنلاین Push نمی‌فرستد
  static Future<void> ping() async {
    try {
      await ApiClient.dio.post('/api/chat/ping.php');
    } catch (_) {}
  }
}

class ChatException implements Exception {
  final String message;
  ChatException(this.message);
  @override
  String toString() => message;
}

/// فایلی که کاربر برای ارسال انتخاب کرده
class ChatUpload {
  final String name;
  final Uint8List bytes;
  ChatUpload(this.name, this.bytes);

  String get ext =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isImage => const ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

  /// MIMEهای مجاز در api/chat/send.php
  String get mime => switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'ogg' => 'audio/ogg',
    _ => 'application/octet-stream',
  };

  static const allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'mp3',
    'm4a',
    'ogg',
  ];
}
