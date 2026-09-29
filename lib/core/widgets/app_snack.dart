import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// اعلان‌های استاندارد (موفقیت: سبز، خطا: قرمز، هشدار: نارنجی، اطلاع: سرمه‌ای؛ همه پررنگ)، کادرِ کوچک‌تر و
/// فاصله از لبه‌ی پایینِ گوشی. عبارتِ «(تأیید خودکار)» که سرور به بعضی
/// پیام‌ها اضافه می‌کند برداشته می‌شود.
class AppSnack {
  AppSnack._();

  static const _green = Color(0xFF15803D);
  static const _red = Color(0xFFDC2626);
  static const _orange = Color(0xFFD97706);
  static const _slate = Color(0xFF334155);

  static void success(
    String title,
    String message, {
    TextButton? mainButton,
    Duration? duration,
  }) => _show(title, message, _green, mainButton, duration);

  static void error(
    String title,
    String message, {
    TextButton? mainButton,
    Duration? duration,
  }) => _show(title, message, _red, mainButton, duration);

  static void warning(
    String title,
    String message, {
    TextButton? mainButton,
    Duration? duration,
  }) => _show(title, message, _orange, mainButton, duration);

  static void info(
    String title,
    String message, {
    TextButton? mainButton,
    Duration? duration,
  }) => _show(title, message, _slate, mainButton, duration);

  static void _show(
    String title,
    String message,
    Color color,
    TextButton? mainButton,
    Duration? duration,
  ) {
    final cleaned = message.replaceAll('(تأیید خودکار)', '').trim();
    Get.snackbar(
      '',
      '',
      titleText: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      messageText: cleaned.isEmpty
          ? const SizedBox.shrink()
          : Text(
              cleaned,
              style: const TextStyle(fontSize: 11.5, color: Colors.white),
            ),
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.fromLTRB(48, 0, 48, 32),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: 12,
      mainButton: mainButton,
      duration: duration ?? const Duration(seconds: 3),
    );
  }
}
