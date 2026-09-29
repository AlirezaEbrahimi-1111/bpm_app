import 'package:flutter/material.dart';

/// پالت رنگ/آیکونِ گروه‌های کار — دقیقاً همان مقادیرِ ثابتی که نسخه‌ی
/// دسکتاپ استفاده می‌کند (`pages/group-management.php` → GROUP_COLORS /
/// GROUP_ICONS)، تا گروهی که با موبایل ساخته می‌شود در دسکتاپ هم
/// (و برعکس) درست دیده شود — هر دو رشته‌ی خام (hex رنگ، کلید bi-*
/// آیکون) را مستقیم در دیتابیس ذخیره می‌کنند.
const List<String> taskGroupColors = [
  '#6366f1',
  '#ef4444',
  '#f59e0b',
  '#10b981',
  '#3b82f6',
  '#8b5cf6',
  '#ec4899',
  '#14b8a6',
  '#64748b',
  '#0ea5e9',
];

/// کلیدهای آیکون (همان bi-* بوت‌استرپِ دسکتاپ) — چون فلاتر فونتِ
/// Bootstrap Icons ندارد، هرکدام به نزدیک‌ترین آیکونِ متریال نگاشت
/// می‌شود؛ خودِ رشته (نه آیکونِ متریال) در دیتابیس ذخیره/خوانده می‌شود.
const List<String> taskGroupIconKeys = [
  'bi-tag',
  'bi-briefcase',
  'bi-house',
  'bi-heart',
  'bi-star',
  'bi-flag',
  'bi-bullseye',
  'bi-people',
  'bi-cart',
  'bi-tools',
  'bi-book',
  'bi-lightning',
];

const Map<String, IconData> _taskGroupIconMap = {
  'bi-tag': Icons.sell_outlined,
  'bi-briefcase': Icons.work_outline_rounded,
  'bi-house': Icons.home_outlined,
  'bi-heart': Icons.favorite_outline,
  'bi-star': Icons.star_outline_rounded,
  'bi-flag': Icons.flag_outlined,
  'bi-bullseye': Icons.track_changes_outlined,
  'bi-people': Icons.people_outline_rounded,
  'bi-cart': Icons.shopping_cart_outlined,
  'bi-tools': Icons.build_outlined,
  'bi-book': Icons.menu_book_outlined,
  'bi-lightning': Icons.bolt_outlined,
};

IconData taskGroupIconFor(String? key) =>
    _taskGroupIconMap[key] ?? Icons.folder_outlined;

Color parseTaskGroupColor(
  String? hex, {
  Color fallback = const Color(0xFF6366F1),
}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return fallback;
  }
}
