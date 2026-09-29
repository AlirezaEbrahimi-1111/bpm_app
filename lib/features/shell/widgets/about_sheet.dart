import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/persian_number.dart';

/// شیتِ «درباره ما» — از دراور و صفحه‌ی تنظیمات هر دو استفاده می‌شود
/// تا محتوا یک‌جا و هماهنگ بماند.
void showAboutSheet(BuildContext context) {
  final c = AppColors.of(context);
  Get.bottomSheet(
    Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary, const Color(0xFF22D3EE)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'آوای شرق ملک',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'سامانه مدیریت یکپارچه فرآیندها',
            style: TextStyle(fontSize: 13, color: c.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            toPersianDigits('نسخه ۴.۰'),
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
