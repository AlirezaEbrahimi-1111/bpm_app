import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

class AuthService {
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
}
