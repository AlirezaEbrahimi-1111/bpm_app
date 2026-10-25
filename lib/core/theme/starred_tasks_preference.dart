import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';

/// لیستِ کارهایِ «منتخب» (ستاره‌دار).
///
/// 🔧 ۱۴۰۵/۰۸/۰۳ — طبقِ درخواست: منتخب بینِ وب و اپ **مشترک و دائمی** است.
/// منبعِ اصلی سرور است (همان تنظیمِ داشبوردِ وب:
/// api/dashboard/prefs-get.php و prefs-set.php، کلیدِ starred_tasks با
/// قالبِ «task:123»). رویِ گوشی فقط یک کپی برایِ نمایشِ فوری/آفلاین
/// نگه داشته می‌شود.
///
/// - زدنِ ستاره: فوراً رویِ صفحه عوض می‌شود و «افزودن/برداشتنِ همین یکی»
///   به سرور می‌رود (نه کلِ فهرست — تا ستاره‌ای که هم‌زمان در وب زده شده
///   پاک نشود). اگر اینترنت نبود، در صف می‌ماند و در همگام‌سازیِ بعدی
///   فرستاده می‌شود.
/// - [sync] (داشبورد و جزئیاتِ کار صدا می‌زنند): صفِ مانده را می‌فرستد و
///   فهرستِ تازه را از سرور می‌گیرد؛ ستاره‌هایِ وب این‌جا دیده می‌شوند.
/// - ستاره‌هایِ قدیمیِ گوشی (قبل از این تغییر) یک‌بار با فهرستِ سرور ادغام
///   می‌شوند.
class StarredTasksPreference {
  StarredTasksPreference._();

  static const _storage = FlutterSecureStorage();

  /// ستاره‌هایِ نسخه‌یِ قبلی (فقط محلی، شناسه‌یِ خالی مثلِ «123»)
  static const _legacyKey = 'starred_task_ids';

  /// کپیِ محلیِ آخرین فهرستِ سرور + صفِ عملیاتِ نرسیده — جدا برایِ هر کاربر
  static String _cacheKey(int uid) => 'starred_cache_$uid';
  static String _pendingKey(int uid) => 'starred_pending_$uid';

  static final ValueNotifier<Set<String>> idsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  static bool _syncing = false;

  static int? get _uid => ApiClient.currentUserId;

  /// یک‌بار در شروعِ اپ صدا زده می‌شود — کپیِ محلیِ همین کاربر برایِ نمایشِ فوری
  static Future<void> init() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final saved = await _storage.read(key: _cacheKey(uid));
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved);
        if (decoded is List) idsNotifier.value = _taskIds(decoded);
      }
    } catch (_) {
      // خطای خواندن یعنی تا همگام‌سازی لیست خالی بماند
    }
  }

  static bool isStarred(dynamic taskId) =>
      idsNotifier.value.contains(taskId.toString());

  static Future<void> toggle(dynamic taskId) async {
    final id = taskId.toString();
    final updated = Set<String>.from(idsNotifier.value);
    final on = !updated.contains(id);
    if (on) {
      updated.add(id);
    } else {
      updated.remove(id);
    }
    idsNotifier.value = updated; // فوری — همه‌جا (داشبورد و جزئیاتِ کار)

    final uid = _uid;
    if (uid == null) return;
    final op = {'op': on ? 'add' : 'remove', 'item': 'task:$id'};
    try {
      final list = await _send(op);
      if (list != null) _applyServer(uid, list);
    } catch (_) {
      // بدونِ اینترنت/خطای سرور: در صف بماند تا همگام‌سازیِ بعدی
      await _enqueue(uid, op);
    }
  }

  /// صفِ مانده را بفرست و فهرستِ تازه را از سرور بگیر.
  static Future<void> sync() async {
    final uid = _uid;
    if (uid == null || _syncing) return;
    _syncing = true;
    try {
      await _migrateLegacy(uid);

      final pending = await _readPending(uid);
      while (pending.isNotEmpty) {
        await _send(pending.first); // خطا = توقف؛ صف دستِ‌نخورده می‌ماند
        pending.removeAt(0);
        await _writePending(uid, pending);
      }

      final res = await ApiClient.dio.get('/api/dashboard/prefs-get.php');
      final data = ApiClient.parseResponse(res.data);
      final prefs = data['prefs'];
      if (data['success'] == true && prefs is Map && prefs['starred_tasks'] is List) {
        _applyServer(uid, prefs['starred_tasks'] as List);
      }
    } catch (_) {
      // بی‌اینترنت: همان کپیِ محلی می‌ماند
    } finally {
      _syncing = false;
    }
  }

  /// ستاره‌هایِ نسخه‌یِ قبلیِ اپ → یک‌بار ادغام با فهرستِ سرور
  static Future<void> _migrateLegacy(int uid) async {
    final raw = await _storage.read(key: _legacyKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    final items = decoded is List
        ? decoded
            .map((e) => e.toString())
            .where((e) => int.tryParse(e) != null)
            .map((e) => 'task:$e')
            .toList()
        : <String>[];
    if (items.isNotEmpty) {
      final list = await _send({'op': 'merge', 'items': items});
      if (list != null) _applyServer(uid, list);
    }
    await _storage.delete(key: _legacyKey);
  }

  /// یک عملیات به سرور؛ فهرستِ کاملِ بعد از آن را برمی‌گرداند
  static Future<List?> _send(Map<String, dynamic> op) async {
    final res = await ApiClient.dio.post(
      '/api/dashboard/prefs-set.php',
      data: {'pref_key': 'starred_tasks', ...op},
    );
    final data = ApiClient.parseResponse(res.data);
    if (data['success'] != true) {
      throw Exception(data['message']?.toString() ?? 'ذخیره‌یِ منتخب ناموفق بود');
    }
    final list = data['starred_tasks'];
    return list is List ? list : null;
  }

  static void _applyServer(int uid, List list) {
    if (_uid != uid) return; // در این فاصله کاربر عوض شده
    idsNotifier.value = _taskIds(list);
    _storage
        .write(key: _cacheKey(uid), value: jsonEncode(list))
        .catchError((_) {});
  }

  /// «task:123» → «123» (کلیدهایِ دیگرِ وب مثلِ «wf:7» در اپ نمایش داده نمی‌شوند ولی رویِ سرور می‌مانند)
  static Set<String> _taskIds(List list) => list
      .map((e) => e.toString())
      .where((e) => e.startsWith('task:'))
      .map((e) => e.substring(5))
      .toSet();

  static Future<List<Map<String, dynamic>>> _readPending(int uid) async {
    try {
      final raw = await _storage.read(key: _pendingKey(uid));
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _writePending(
      int uid, List<Map<String, dynamic>> list) async {
    try {
      if (list.isEmpty) {
        await _storage.delete(key: _pendingKey(uid));
      } else {
        await _storage.write(key: _pendingKey(uid), value: jsonEncode(list));
      }
    } catch (_) {}
  }

  static Future<void> _enqueue(int uid, Map<String, dynamic> op) async {
    final list = await _readPending(uid);
    // عملیاتِ قبلیِ همین کار بی‌اثر است — فقط آخرین بماند
    list.removeWhere((e) => e['item'] == op['item']);
    list.add(op);
    await _writePending(uid, list);
  }

  /// خروج از حساب: فهرستِ کاربرِ قبلی رویِ صفحه نماند
  static void clearSession() {
    idsNotifier.value = <String>{};
  }
}
