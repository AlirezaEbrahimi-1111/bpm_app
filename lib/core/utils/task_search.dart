/// نرمال‌سازی ارقام فارسی و عربی به ارقام لاتین.
///
/// این‌طوری جستجوی «۱» (فارسی)، «١» (عربی) و «1» (لاتین) دقیقاً همان
/// نتیجه را می‌دهد — بدون این تابع مقایسه‌ی رشته‌ای این سه را متفاوت
/// می‌دید.
String _normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30); // ۰-۹ فارسی
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30); // ٠-٩ عربی
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// جستجوی چندکلمه‌ای روی کارها — دقیقاً همان تکنیکی که در پنل وب
/// استفاده می‌شود (matchesAllWords).
///
/// عبارت جستجو با فاصله به چند «کلمه» شکسته می‌شود. کار فقط وقتی در
/// نتیجه قرار می‌گیرد که همه‌ی این کلمه‌ها (نه فقط یکی) به‌صورت
/// substring، بدون حساسیت به بزرگی/کوچکی حروف، در شناسه، عنوان،
/// توضیحات یا متن تاریخچه‌ی کار (history_text) پیدا شوند.
///
/// مثال: جستجوی «واریز 312 محمدی» یعنی به دنبال کارهایی بگرد که هم
/// «واریز»، هم «312» و هم «محمدی» را همزمان داشته باشند.
bool taskMatchesQuery(Map task, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return true;

  final words = _normalizeDigits(trimmed)
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;

  final id = (task['id'] ?? '').toString();
  final title = (task['title'] ?? '').toString();
  final description = (task['description'] ?? '').toString();
  final historyText = (task['history_text'] ?? '').toString();

  final haystack = _normalizeDigits(
    '$id $title $description $historyText',
  ).toLowerCase();

  return words.every((w) => haystack.contains(w));
}
