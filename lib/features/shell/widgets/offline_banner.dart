import 'package:flutter/material.dart';
import '../../../core/utils/persian_number.dart';

/// نواری که نشان می‌دهد داده‌های نمایش داده‌شده تازه از سرور نیستند،
/// بلکه آخرین نسخه‌ی ذخیره‌شده‌اند — برای حالت «آفلاین سبک» (فقط
/// مشاهده؛ هیچ نوشتنی در حالت آفلاین ذخیره نمی‌شود).
class OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;
  const OfflineBanner({super.key, this.cachedAt});

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    return '${diff.inDays} روز پیش';
  }

  @override
  Widget build(BuildContext context) {
    final suffix = cachedAt != null
        ? ' (${toPersianDigits(_timeAgo(cachedAt!))})'
        : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'بدون اینترنت — نمایش آخرین اطلاعات ذخیره‌شده$suffix',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
