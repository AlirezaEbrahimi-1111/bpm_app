import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

class AuthService {
  // پیام روشن‌تر برای انواع خطای شبکه — به‌جای یک پیام یکسان برای همه
  static String _networkErrorMessage(DioException e, String fallback) {
    if (e.response != null) {
      return e.response?.data['message']?.toString() ?? fallback;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'پاسخ سرور طول کشید — دوباره تلاش کنید';
      default:
        return 'خطا در اتصال به سرور — اینترنت را بررسی کنید';
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/auth/login.php',
        data: {'username': username, 'password': password},
      );

      if (response.data['success'] == true) {
        // ذخیره توکن
        await ApiClient.saveToken(response.data['token']);
        return {
          'success': true,
          'user': response.data['user'],
          'message': response.data['message'],
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'خطا در ورود',
        };
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'خطا در ورود',
        };
      }
      return {
        'success': false,
        'message': 'خطا در اتصال به سرور — اینترنت را بررسی کنید',
      };
    } catch (e) {
      return {'success': false, 'message': 'خطای ناشناخته'};
    }
  }

  // ── ارسال کد یکبارمصرف (OTP) به شماره موبایل ──
  // 🔧 اصلاح: تایم‌اوت مشخص (۱۵ ثانیه) روی همین درخواست — سمت سرور این
  // مسیر یک تماس به پنل پیامک هم می‌زند که گاهی کند/ناپایدار است؛ به‌جای
  // این‌که کاربر با یک اسپینر بی‌پایان بماند، بعد از ۱۵ ثانیه پیام روشن
  // «پاسخ سرور طول کشید» نشان داده می‌شود.
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/auth/login.php',
        data: {'action': 'send_otp', 'phone': phone},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      if (response.data['success'] == true) {
        return {
          'success': true,
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'message': response.data['message'] ?? 'خطا در ارسال کد',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _networkErrorMessage(e, 'خطا در ارسال کد'),
      };
    } catch (e) {
      return {'success': false, 'message': 'خطای ناشناخته'};
    }
  }

  // ── تأیید کد یکبارمصرف و ورود ──
  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code,
  ) async {
    try {
      final response = await ApiClient.dio.post(
        '/api/auth/login.php',
        data: {'action': 'verify_otp', 'phone': phone, 'code': code},
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      if (response.data['success'] == true) {
        await ApiClient.saveToken(response.data['token']);
        return {
          'success': true,
          'user': response.data['user'],
          'message': response.data['message'],
        };
      }
      return {
        'success': false,
        'message': response.data['message'] ?? 'کد تأیید اشتباه است',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': _networkErrorMessage(e, 'کد تأیید اشتباه است'),
      };
    } catch (e) {
      return {'success': false, 'message': 'خطای ناشناخته'};
    }
  }
}
