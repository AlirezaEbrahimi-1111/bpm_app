import 'package:flutter/material.dart';

/// توکن‌های رنگِ رسمیِ پروژه — همان مقادیری که در custom.css نسخه‌ی
/// وب (itmalek.com) به‌عنوان توکن‌های تمِ روشن/تاریک تعریف شده‌اند، تا
/// موبایل و وب دقیقاً هماهنگ باشند.
///
/// این کلاس فقط برای صفحاتی استفاده می‌شود که به تم تاریک مهاجرت
/// کرده‌اند (فعلاً: پوسته‌ی اصلی + داشبورد). بقیه‌ی صفحات هنوز رنگ‌های
/// قدیمیِ خودشان (فقط روشن) را دارند تا در مرحله‌ی بعد بازطراحی شوند.
class AppColors {
  final Color primary;
  final Color primaryLight;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// پس‌زمینه‌ی کارت‌ها/سطوح
  final Color surface;

  /// پس‌زمینه‌ی کلیِ صفحه
  final Color bgPage;

  final Color textStrong;
  final Color textMuted;
  final Color borderSoft;
  final Color iconAccent;

  /// 🔧 مقیاسِ تونالِ سطوح، طبقِ توکن‌هایِ surface-container در Material 3 —
  /// برایِ لایه‌هایی که باید از bgPage «مرتفع‌تر» باشند ولی هم‌سطحِ کارت‌های
  /// اصلی (surface) هم نیستند: دراور، شیت‌های پایین‌رونده، پس‌زمینه‌ی
  /// مودال‌ها. در تمِ تاریک طبقِ الگویِ M3 با روشن‌شدن (نه تیره‌شدن) ارتفاع
  /// نشان داده می‌شود.
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  /// 🔧 پس‌زمینه‌ی اختصاصیِ نوارِ ناوبریِ پایین — طبق استانداردِ Material 3
  /// (توکن‌های surface-container)، این سطح باید کمی «مرتفع‌تر» از
  /// bgPage باشد: در تمِ روشن با یک تنِ خنثیِ گرم (طوسیِ روشن/فیلی، نه
  /// سفیدِ خالص)، و در تمِ تاریک با یک تنِ کمی روشن‌تر از bgPage (نه
  /// تیره‌تر — الگویِ ارتفاعِ M3 در تمِ تاریک با روشن‌شدن، نه تیره‌شدن،
  /// کار می‌کند) تا از پس‌زمینه متمایز باشد ولی پرکنتراست/چشم‌زننده نشود.
  final Color navBarBg;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.surface,
    required this.bgPage,
    required this.textStrong,
    required this.textMuted,
    required this.borderSoft,
    required this.iconAccent,
    required this.navBarBg,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
  });

  static const light = AppColors(
    primary: Color(0xFF8E57FE),
    primaryLight: Color(0xFFA78BFA),
    success: Color(0xFF1B7B39),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF06B6D4),
    surface: Color(0xFFFFFFFF),
    bgPage: Color(0xFFF8FAFC), // gray-50
    textStrong: Color(0xFF0F172A), // gray-900
    textMuted: Color(0xFF64748B), // gray-500
    borderSoft: Color(0xFFE9E9E9),
    iconAccent: Color(0xFF8E57FE),
    // 🔧 اصلاح: مقدارِ قبلی (EAE6DF) طوسیِ خیلی پررنگی بود؛ طبقِ
    // بازخورد، باید فقط کمی از سفید تیره‌تر باشد، نه یک طوسیِ محسوس
    navBarBg: Color(0xFFF6F4F1),
    surfaceContainerLowest: Color(0xFFF5F6FA),
    surfaceContainerLow: Color(0xFFF1F3F8),
    surfaceContainerHigh: Color(0xFFE7EAF1),
    surfaceContainerHighest: Color(0xFFDEE2ED),
  );

  static const dark = AppColors(
    primary: Color(0xFF8E57FE),
    primaryLight: Color(0xFFA78BFA),
    success: Color(0xFF1B7B39),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF06B6D4),
    surface: Color(0xFF1B2130),
    bgPage: Color(0xFF12151F),
    textStrong: Color(0xFFFFFFFF),
    textMuted: Color(
      0xFFFFFFFF,
    ), // 🔧 طبق درخواست: در تمِ تاریک هیچ متنِ خاکستری/طوسی نباشد
    borderSoft: Color(0xFF2B3242),
    iconAccent: Color(0xFFCDB8FF),
    navBarBg: Color(0xFF1E2436), // کمی روشن‌تر از bgPage
    surfaceContainerLowest: Color(0xFF141826),
    surfaceContainerLow: Color(0xFF171B29),
    surfaceContainerHigh: Color(0xFF232A3F),
    surfaceContainerHighest: Color(0xFF2A3247),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
