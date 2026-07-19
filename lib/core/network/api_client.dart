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

  // ── پاک کردن توکن (خروج) ──
  static Future<void> clearToken() async {
    _cachedToken = null;
    currentUserId = null; // شناسه کاربر هم پاک شود
    await _storage.delete(key: 'access_token');
  }

  // ── خواندن توکن ──
  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: 'access_token');
    return _cachedToken;
  }
}
