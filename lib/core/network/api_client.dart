import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../plan/plan_access.dart';

class ApiClient {
  static const String baseUrl = 'https://bpm.itmalek.com';
  static const _storage = FlutterSecureStorage();

  // ════════════════════════════════════════════════════════
  // توکن در حافظه نگه داشته می‌شود (کلید حل باگ race condition)
  // ════════════════════════════════════════════════════════
  static String? _cachedToken;

  // ════════════════════════════════════════════════════════
  // شناسه کاربر جاری — سراسری، یک‌بار موقع لاگین ذخیره می‌شود
  // ════════════════════════════════════════════════════════
  static int? currentUserId;

  /// 🔧 کپیِ کاملِ آخرین کاربرِ لاگین‌شده، به‌صورتِ همزمان (sync) در دسترس —
  /// برایِ ویجت‌هایی مثلِ دکمه‌ی شناورِ «افزودنِ کار» که در صفحاتِ مختلف
  /// (بدونِ آن‌که user به‌عنوانِ پارامتر بهشان پاس داده شده باشد) هم باید
  /// نقش/شناسه‌ی کاربر را بدانند
  static Map<String, dynamic>? currentUser;

  /// پاسخِ 403 با کد PLAN_RESTRICTED؛ UI (شِل) نمایشِ شیتِ ارتقا را تنظیم می‌کند
  static void Function(String? message)? onPlanRestricted;

  // ════════════════════════════════════════════════════════
  // اگر سرور توکن را نامعتبر/منقضی اعلام کند (۴۰۱/۴۰۳)، این callback
  // صدا زده می‌شود تا برنامه کاربر را به صفحه‌ی ورود برگرداند — به‌جای
  // این‌که صفحات مختلف بی‌صدا خالی/خراب بمانند (مثلاً بعد از ورود
  // خودکار با «مرا به خاطر بسپار» وقتی توکن ذخیره‌شده دیگر معتبر نیست).
  // ════════════════════════════════════════════════════════
  static void Function()? onSessionExpired;

  /// یک بار در شروع اپ صدا زده می‌شود تا توکن از حافظه امن خوانده شود
  static Future<void> init() async {
    try {
      _cachedToken = await _storage.read(key: 'access_token');
    } catch (e) {
      _cachedToken = null;
    }
  }

  // پاسخ را امن به Map تبدیل می‌کند (چه String باشد چه Map)
  static Map<String, dynamic> parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {'success': false, 'message': 'پاسخ نامعتبر'};
      } catch (_) {
        return {'success': false, 'message': 'پاسخ نامعتبر'};
      }
    }
    return {'success': false, 'message': 'پاسخ نامعتبر'};
  }

  // 🔧 رفعِ باگِ تکرارشده در چند صفحه: چون Dio به‌صورتِ پیش‌فرض رویِ هر
  // status code غیرِ ۲xx (۴۰۰/۴۰۳/۴۰۹/۵۰۰...) Exception پرتاب می‌کند،
  // پیامِ واقعیِ سرور (که در بدنه‌ی JSON پاسخ است) اگر در catch مستقیم
  // یک پیامِ ثابتِ عمومی نمایش داده شود، هرگز دیده نمی‌شود — حتی وقتی
  // سرور دقیقاً توضیح داده چرا رد کرده (مثلاً «موعد این کار گذشته است»).
  // این تابع پیامِ واقعی را (اگر موجود باشد) استخراج می‌کند.
  static String errorMessage(Object e, String fallback) {
    if (e is DioException && e.response?.data is Map) {
      final msg = (e.response!.data as Map)['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    }
    return fallback;
  }

  // ════════════════════════════════════════════════════════
  // یک نمونه Dio ثابت (نه getter که هر بار بسازد)
  // ════════════════════════════════════════════════════════
  static final Dio _dio = _createDio();

  static Dio get dio => _dio;

  static Dio _createDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json', 'X-Client': 'app'},
        responseType: ResponseType.json,
      ),
    );

    d.interceptors.add(
      InterceptorsWrapper(
        // این تابع async نیست و هیچ عملیات دیسکی ندارد → بدون رقابت
        onRequest: (options, handler) {
          final token = _cachedToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          final data = error.response?.data;
          final isPlanRestricted =
              data is Map && data['code'] == 'PLAN_RESTRICTED';
          if (status == 401 || (status == 403 && !isPlanRestricted)) {
            onSessionExpired?.call();
          }
          // 🔧 خطای پلن: کاربر خارج نمی‌شود؛ فقط پیامِ سرور نشان داده می‌شود
          if (isPlanRestricted) {
            onPlanRestricted?.call(data['message']?.toString());
          }
          return handler.next(error);
        },
      ),
    );

    return d;
  }

  // ── ذخیره توکن (هم در حافظه، هم روی دیسک) ──
  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'access_token', value: token);
  }

  // ── خواندن توکن ──
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: 'access_token');
    return _cachedToken;
  }

  // ════════════════════════════════════════════════════════
  // «مرا به خاطر بسپار»
  // اگر کاربر این گزینه را هنگام ورود فعال کرده باشد، دفعه‌ی بعد که
  // اپ باز شود، بدون نیاز به ورود مجدد مستقیم به صفحه‌ی اصلی می‌رود.
  // ════════════════════════════════════════════════════════

  // مدت اعتبار «مرا به خاطر بسپار»: ۱ ماه از آخرین ورود
  static const Duration rememberMeDuration = Duration(days: 30);

  static Future<void> saveRememberMe(bool value) async {
    await _storage.write(key: 'remember_me', value: value.toString());
    if (value) {
      final expiry = DateTime.now().add(rememberMeDuration);
      await _storage.write(
        key: 'remember_me_expiry',
        value: expiry.millisecondsSinceEpoch.toString(),
      );
    } else {
      await _storage.delete(key: 'remember_me_expiry');
    }
  }

  static Future<void> saveCachedUser(Map<String, dynamic> user) async {
    PlanAccess.setFromUser(user);
    currentUser = user;
    await _storage.write(key: 'cached_user', value: jsonEncode(user));
    // 🔧 طبق درخواست: شناساییِ کاربرِ جاری برایِ OneSignal — تا بک‌اند
    // بتواند با همین ID، دقیقاً به همین کاربر Push بفرستد
    final id = user['id'];
    if (id != null) OneSignal.login(id.toString());
  }

  /// اگر «مرا به خاطر بسپار» فعال بوده، هنوز یک ماه از آن نگذشته باشد و
  /// توکن معتبری ذخیره شده باشد، اطلاعات کاربر ذخیره‌شده را برمی‌گرداند
  /// تا ورود خودکار انجام شود. در غیر این صورت null برمی‌گرداند
  /// (یعنی باید صفحه‌ی ورود نمایش داده شود).
  static Future<Map<String, dynamic>?> getAutoLoginUser() async {
    try {
      final remember = await _storage.read(key: 'remember_me');
      if (remember != 'true') return null;

      final expiryStr = await _storage.read(key: 'remember_me_expiry');
      final expiryMs = int.tryParse(expiryStr ?? '');
      if (expiryMs == null ||
          DateTime.now().isAfter(
            DateTime.fromMillisecondsSinceEpoch(expiryMs),
          )) {
        await clearToken();
        return null;
      }

      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final userJson = await _storage.read(key: 'cached_user');
      if (userJson == null) return null;

      final decoded = jsonDecode(userJson);
      if (decoded is Map) {
        final userMap = Map<String, dynamic>.from(decoded);
        currentUserId = userMap['id'] is int
            ? userMap['id']
            : int.tryParse(userMap['id']?.toString() ?? '');
        currentUser = userMap;
        PlanAccess.setFromUser(userMap);
        // 🔧 ورودِ خودکار هم باید همان شناساییِ OneSignal را انجام دهد —
        // چون این مسیر از saveCachedUser رد نمی‌شود
        final id = userMap['id'];
        if (id != null) OneSignal.login(id.toString());
        return userMap;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // «آفلاین سبک» — کش آخرین داده‌ی موفق هر صفحه، فقط برای مشاهده وقتی
  // اینترنت نیست. هیچ نوشتنی (تکمیل کار، ارجاع و...) آفلاین ذخیره
  // نمی‌شود؛ این فقط حالت مشاهده‌ی آخرین اطلاعات است.
  // ════════════════════════════════════════════════════════
  static Future<void> saveOfflineCache(String key, dynamic data) async {
    try {
      await _storage.write(
        key: 'offline_cache_$key',
        value: jsonEncode({
          'data': data,
          'cached_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // خطای کش نباید کل اپ را مختل کند
    }
  }

  /// اگر کشی برای این کلید وجود داشته باشد، {'data':..., 'cachedAt':...}
  /// برمی‌گرداند؛ وگرنه null.
  static Future<Map<String, dynamic>?> readOfflineCache(String key) async {
    try {
      final raw = await _storage.read(key: 'offline_cache_$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          'data': decoded['data'],
          'cachedAt': DateTime.tryParse(decoded['cached_at']?.toString() ?? ''),
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── پاک کردن کامل جلسه (خروج) ──
  static Future<void> clearToken() async {
    _cachedToken = null;
    currentUserId = null; // شناسه کاربر هم پاک شود
    currentUser = null;
    PlanAccess.reset();
    // 🔧 با خروج، شناساییِ OneSignal هم باید پاک شود تا کاربرِ بعدی که
    // با همین گوشی لاگین می‌کند، اشتباهاً پیامِ کاربرِ قبلی را نگیرد
    OneSignal.logout();
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'remember_me');
    await _storage.delete(key: 'remember_me_expiry');
    await _storage.delete(key: 'cached_user');
    // کش‌های آفلاین هم پاک شوند — کاربر بعدی روی همین گوشی نباید
    // اطلاعات کاربر قبلی را (حتی به‌صورت آفلاین) ببیند
    for (final key in [
      'dashboard',
      'my_tasks',
      'delegated_tasks',
      'notifications',
    ]) {
      await _storage.delete(key: 'offline_cache_$key');
    }
  }
}
