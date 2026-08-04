import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class ApiClient {
  static const String baseUrl = 'https://bpm.computeryekta.com';
  static const _storage = FlutterSecureStorage();

  // ════════════════════════════════════════════════════════
  // توکن در حافظه نگه داشته می‌شود (کلید حل باگ race condition)
  // ════════════════════════════════════════════════════════
  static String? _cachedToken;

  // ════════════════════════════════════════════════════════
  // شناسه کاربر جاری — سراسری، یک‌بار موقع لاگین ذخیره می‌شود
  // ════════════════════════════════════════════════════════
  static int? currentUserId;

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
        headers: {'Content-Type': 'application/json'},
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
          if (status == 401 || status == 403) {
            onSessionExpired?.call();
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
    await _storage.write(key: 'cached_user', value: jsonEncode(user));
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
        return userMap;
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
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'remember_me');
    await _storage.delete(key: 'remember_me_expiry');
    await _storage.delete(key: 'cached_user');
  }
}
