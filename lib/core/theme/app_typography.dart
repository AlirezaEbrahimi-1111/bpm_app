import 'package:flutter/material.dart';

/// مقیاسِ تایپوگرافیِ M3، ساخته‌شده روی فونتِ فعلیِ اپ («Vazir» — تغییر
/// نکرده، فقط سایزها استاندارد شده‌اند) — تا اندازه‌های پراکنده‌ی فعلی
/// در کد (۱۱، ۱۱.۵، ۱۲، ۱۲.۵، ۱۳...) به‌تدریج با همین چند سطحِ استاندارد
/// جایگزین شوند. رنگ عمداً در این توکن‌ها ست نمی‌شود — رنگ از
/// AppColors (که به روشن/تاریک وابسته است) در محلِ استفاده اضافه شود.
///
/// 🔧 این فایل فقط توکن تعریف می‌کند — چیزی را خودش تغییر نمی‌دهد؛
/// اعمالش روی صفحات، فازِ بعدیِ استانداردسازیِ M3 است.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Vazir';

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
}
